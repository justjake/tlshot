import {
  session,
  desktopCapturer,
  ipcMain,
  screen,
  BrowserWindow,
  WebContents,
} from "electron";
import installExtension, {
  REACT_DEVELOPER_TOOLS,
} from "electron-extension-installer";

import Store from "electron-store";
import { DisplaysState } from "../renderer/editor/Displays";
interface StoreData {
  editorWindowBounds?: Electron.Rectangle;
  editorWindowDevtools?: boolean;
}
export const STORE = new Store<StoreData>();

// https://github.com/wulkano/Kap/blob/main/main/windows/cropper.ts

function applyContentSecurityPolicy() {
  /**
   * Electron tells us to turn this off, but it instantly breaks Webpack's ability to do anything.
   * Very sad.
   *
   * https://twitter.com/jitl/status/1644513765176516609
   */
  const UNSAFE_EVAL = `'unsafe-eval'`;
  const CONTENT_SECURITY_POLICY = [
    `default-src 'self' 'unsafe-inline' ${UNSAFE_EVAL} data:`,
    // We need to explicitly allow blob: for Tldraw assets to work.
    `img-src 'self' data: blob:`,
  ].join("; ");
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        "Content-Security-Policy": [CONTENT_SECURITY_POLICY],
      },
    });
  });
}

function installDevtoolsExtensions() {
  return installExtension(REACT_DEVELOPER_TOOLS, {
    loadExtensionOptions: {
      allowFileAccess: true,
    },
  });
}

export class WindowHistoryLog {
  static recentWindows = new WeakMap<
    WebContents,
    Array<WeakRef<BrowserWindow>>
  >();

  static track(browserWindow: BrowserWindow) {
    browserWindow.webContents.on("did-create-window", (newWindow, details) => {
      console.log(
        "New window opened",
        { from: browserWindow.id, to: newWindow.id },
        details
      );
      this.didOpen(browserWindow.webContents, newWindow);
      this.track(newWindow);
    });
  }

  static didOpen(webContents: WebContents, newWindow: BrowserWindow) {
    const ref = new WeakRef(newWindow);
    const log = this.recentWindows.get(webContents) || [];
    log.push(ref);
    this.recentWindows.set(webContents, log);
  }
}

export type TlshotApiResponse = {
  [K in keyof TlshotApi]: TlshotApi[K] extends (...args: any) => infer R
    ? Awaited<R>
    : never;
};

export type TlshotApiRequest = {
  [K in keyof TlshotApi]: TlshotApi[K] extends (
    first: any,
    ...rest: infer R
  ) => any
    ? R
    : never;
};

export type TlshotApiClient = {
  [K in keyof TlshotApi]: (
    ...args: TlshotApiRequest[K]
  ) => Promise<TlshotApiResponse[K]>;
};

export type CaptureSource = TlshotApiResponse["getSources"][number];

export class TlshotApi {
  // https://www.electronjs.org/docs/latest/api/ipc-renderer#ipcrendererinvokechannel-args
  static connect(instance: TlshotApi) {
    const methodNames = Object.getOwnPropertyNames(
      TlshotApi.prototype
    ) as Array<keyof TlshotApi>;

    console.log("methodNames", methodNames);

    for (const methodName of methodNames) {
      if (methodName === ("constructor" as any)) continue;

      const method = instance[methodName as keyof TlshotApi];
      if (typeof method !== "function") continue;

      console.log("TlshotApi: connecting method:", methodName, method);
      ipcMain.handle(methodName, method.bind(instance));
    }
  }

  focusTopWindowNearMouse() {
    const mouse = screen.getCursorScreenPoint();
    const topBrowserWindow = BrowserWindow.getAllWindows().find((bw) => {
      const bounds = bw.getBounds();
      return (
        mouse.x >= bounds.x &&
        mouse.x <= bounds.x + bounds.width &&
        mouse.y >= bounds.y &&
        mouse.y <= bounds.y + bounds.height &&
        bw.isAlwaysOnTop()
      );
    });
    if (!topBrowserWindow) {
      console.log("No window found under mouse", mouse);
    }
    topBrowserWindow?.focus();
    topBrowserWindow?.focusOnWebView();
  }

  // https://www.electronjs.org/docs/latest/api/desktop-capturer
  async getSources() {
    const sources = await desktopCapturer.getSources({
      types: ["window", "screen"],
      fetchWindowIcons: true,
      thumbnailSize: {
        width: 500,
        height: 500,
      },
    });
    return sources.map((source) => ({
      ...source,
      appIcon: source.appIcon?.toDataURL() || undefined,
      thumbnail: source.thumbnail?.toDataURL(),
    }));
  }

  async getDisplaySource(
    _event: Electron.IpcMainInvokeEvent,
    displayId: number
  ) {
    const sources = await desktopCapturer.getSources({
      types: ["screen"],
      fetchWindowIcons: false,
      thumbnailSize: {
        width: 0,
        height: 0,
      },
    });

    const source = sources.find(
      (source) => source.display_id === String(displayId)
    );
    if (!source) {
      throw new Error(`No source found for display ${displayId}`);
    }

    return {
      ...source,
      appIcon: undefined,
      thumbnail: undefined,
    };
  }

  // TODO: this is still quite low rez :(
  // We'll need to shell out to `screencapture` on macOS and similar elsewhere
  // if we want good results.
  async captureAllDisplays() {
    let maxWidth = 0;
    let maxHeight = 0;
    for (const display of screen.getAllDisplays()) {
      maxHeight = Math.max(maxHeight, display.bounds.height);
      maxWidth = Math.max(maxWidth, display.bounds.width);
    }

    const sources = await desktopCapturer.getSources({
      types: ["screen"],
      fetchWindowIcons: false,
      thumbnailSize: {
        width: maxWidth,
        height: maxHeight,
      },
    });

    return sources.map((source) => ({
      ...source,
      appIcon: undefined,
      thumbnail: source.thumbnail.toDataURL(),
    }));
  }

  getCurrentDisplay() {
    return screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
  }

  async getRecentWindowId(event: Electron.IpcMainInvokeEvent) {
    const lastWindowCreated =
      WindowHistoryLog.recentWindows.get(event.sender)?.at(-1)?.deref() ||
      BrowserWindow.fromWebContents(event.sender);
    if (lastWindowCreated) {
      return {
        caller: {
          webContentsId: event.sender.id,
        },
        latestWindow: {
          webContentsId: lastWindowCreated.webContents.id,
          browserWindowId: lastWindowCreated.id,
        },
      };
    }
  }

  async setAlwaysOnTop(
    _event: Electron.IpcMainInvokeEvent,
    browserWindowId: number
  ) {
    const browserWindow = BrowserWindow.fromId(browserWindowId);
    if (!browserWindow) {
      console.log("id not found", browserWindowId);
      return;
    }
    browserWindow.setAlwaysOnTop(true, "screen-saver");
  }

  subscribeToDisplays(event: Electron.IpcMainInvokeEvent) {
    const getDisplaysState = (): DisplaysState => {
      const map = new Map<number, Electron.Display>();
      for (const display of screen.getAllDisplays()) {
        map.set(display.id, display);
      }
      return {
        currentDisplay: this.getCurrentDisplay().id,
        displays: map,
      };
    };

    const sendDisplayState = () => {
      event.sender.send("displaysChanged", getDisplaysState());
    };

    // TODO: better way than polling?
    let currentDisplay = this.getCurrentDisplay();
    const interval = setInterval(() => {
      const newDisplay = this.getCurrentDisplay();
      if (newDisplay.id !== currentDisplay.id) {
        currentDisplay = newDisplay;
        sendDisplayState();
      }
    }, 500);

    screen.on("display-added", sendDisplayState);
    screen.on("display-metrics-changed", sendDisplayState);
    screen.on("display-removed", sendDisplayState);

    const cleanUp = () => {
      clearInterval(interval);
      screen.off("display-added", sendDisplayState);
      screen.off("display-metrics-changed", sendDisplayState);
      screen.off("display-removed", sendDisplayState);
    };

    event.sender.once("destroyed", cleanUp);

    return getDisplaysState();
  }
}

export async function startServices() {
  applyContentSecurityPolicy();
  await installDevtoolsExtensions();
  TlshotApi.connect(new TlshotApi());
}
