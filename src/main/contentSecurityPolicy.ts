import { app, protocol, session } from "electron";
import path from "path";

export function getTempFileName(suffix: string) {
  return path.join(app.getPath("temp"), `tlshot-${suffix}`);
}

export function applyContentSecurityPolicy() {
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
    `img-src 'self' data: blob: temp:`,
  ].join("; ");
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        "Content-Security-Policy": [CONTENT_SECURITY_POLICY],
      },
    });
  });

  protocol.interceptFileProtocol("temp", (req, callback) => {
    const filePath = path.normalize(new URL(req.url).pathname);
    if (filePath.startsWith(getTempFileName(""))) {
      callback({ path: filePath });
    } else {
      callback({ error: 403 });
    }
  });
}
