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
  [K in keyof TlshotApi]: TlshotApi[K] extends (
    ...args: any
  ) => Promise<infer R>
    ? R
    : never;
};
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

  async getCurrentDisplay(event: Electron.IpcMainInvokeEvent) {
    const browserWindow = BrowserWindow.fromWebContents(event.sender);
    if (!browserWindow) {
      return;
    }
    return screen.getDisplayMatching(browserWindow.getBounds());
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
}

export async function startServices() {
  applyContentSecurityPolicy();
  await installDevtoolsExtensions();
  TlshotApi.connect(new TlshotApi());
}
