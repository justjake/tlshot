import { session } from "electron";
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
