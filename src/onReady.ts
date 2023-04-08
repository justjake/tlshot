import { session, desktopCapturer, ipcMain } from "electron";
import installExtension, {
  REACT_DEVELOPER_TOOLS,
} from "electron-extension-installer";

/**
 * Electron tells us to turn this off, but it instantly breaks Webpack's ability to do anything.
 * Very sad.
 *
 * https://twitter.com/jitl/status/1644513765176516609
 */
const UNSAFE_EVAL = `'unsafe-eval'`;

export function applyContentSecurityPolicy() {
  const CONTENT_SECURITY_POLICY = [
    `default-src 'self' 'unsafe-inline' ${UNSAFE_EVAL} data:`,
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

/**
 * https://github.com/MarshallOfSound/electron-devtools-installer#usage
 */
export function installDevtoolsExtensions() {
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
      const method = instance[methodName as keyof TlshotApi];
      console.log("connected method", methodName, method);
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
