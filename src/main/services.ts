import {
  session,
  desktopCapturer,
  ipcMain,
  screen,
  BrowserWindow,
} from "electron";
import installExtension, {
  REACT_DEVELOPER_TOOLS,
} from "electron-extension-installer";

import PreferenceStore from "electron-store";
import {
  ChildWindowNanoid,
  WindowDisplayService,
} from "./WindowDisplayService";
import { StoreService } from "./StoreService";
import { AnyServiceEvent, Service } from "./Service";
interface StoreData {
  editorWindowBounds?: Electron.Rectangle;
  editorWindowDevtools?: boolean;
}
export const PREFERENCE_STORE = new PreferenceStore<StoreData>();

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
  [K in keyof TlshotApi]: TlshotApi[K] extends (...args: any) => any
    ? (...args: TlshotApiRequest[K]) => Promise<TlshotApiResponse[K]>
    : never;
};

export type CaptureSource = TlshotApiResponse["getSources"][number];

export class TlshotApi {
  private static instance: TlshotApi | undefined;
  static getInstance() {
    if (!this.instance) {
      this.instance = new TlshotApi();
      this.connect(this.instance);
    }
    return this.instance;
  }

  // https://www.electronjs.org/docs/latest/api/ipc-renderer#ipcrendererinvokechannel-args
  private static connect(instance: TlshotApi) {
    const methodNames = Object.getOwnPropertyNames(
      TlshotApi.prototype
    ) as Array<keyof TlshotApi>;

    console.log("methodNames", methodNames);

    for (const methodName of methodNames) {
      if (methodName === ("constructor" as any)) continue;

      const method = instance[methodName];
      if (typeof method !== "function") continue;

      console.log("TlshotApi: connecting method:", methodName, method);
      ipcMain.handle(methodName, method.bind(instance));
    }
  }

  public storeService = new StoreService();
  public windowDisplayService = new WindowDisplayService();

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

  setAlwaysOnTop(_event: Electron.IpcMainInvokeEvent, browserWindowId: number) {
    const browserWindow = BrowserWindow.fromId(browserWindowId);
    if (!browserWindow) {
      console.log("id not found", browserWindowId);
      return;
    }
    browserWindow.setAlwaysOnTop(true, "screen-saver");
  }

  subscribeToStore(
    event: Electron.IpcMainInvokeEvent,
    childWindowId: ChildWindowNanoid
  ) {
    this.storeService.addSubscriber(event.sender);
    this.windowDisplayService.addSubscriberAndUpdateWindow(
      event.sender,
      childWindowId
    );
  }
}

export async function startServices() {
  applyContentSecurityPolicy();
  await installDevtoolsExtensions();
  TlshotApi.getInstance();
}

export type AllServices = {
  [K in WindowDisplayService["channelName"]]: WindowDisplayService;
} & {
  [K in StoreService["channelName"]]: StoreService;
};

export type AllServiceEvents = {
  [K in keyof AllServices]: AllServices[K] extends Service<any, infer E>
    ? AnyServiceEvent<E>
    : never;
};
