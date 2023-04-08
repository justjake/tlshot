import { session, desktopCapturer, ipcMain } from "electron";
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
}

export async function startServices() {
  applyContentSecurityPolicy();
  await installDevtoolsExtensions();
  TlshotApi.connect(new TlshotApi());
}
