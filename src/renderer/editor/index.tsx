/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/**
 * This file will automatically be loaded by webpack and run in the "renderer" context.
 * To learn more about the differences between the "main" and the "renderer" context in
 * Electron, visit:
 *
 * https://electronjs.org/docs/latest/tutorial/process-model
 *
 * By default, Node.js integration in this file is disabled. When enabling Node.js integration
 * in a renderer process, please be aware of potential security implications. You can read
 * more about security risks here:
 *
 * https://electronjs.org/docs/tutorial/security
 *
 * To enable Node.js integration in this file, open up `main.js` and enable the `nodeIntegration`
 * flag:
 *
 * ```
 *  // Create the browser window.
 *  mainWindow = new BrowserWindow({
 *    width: 800,
 *    height: 600,
 *    webPreferences: {
 *      nodeIntegration: true
 *    }
 *  });
 * ```
 */

import "./index.css";
import { createRoot } from "react-dom/client";
import { Root } from "./Root";
import { TLShot } from "../TLShotRendererApp";

async function main() {
  const handleError = (errorEvent: ErrorEvent | PromiseRejectionEvent) => {
    const both = errorEvent as ErrorEvent & PromiseRejectionEvent;
    const error = both.error || both.reason;
    const serialized = {
      name: error?.name,
      message: both?.message ?? error?.message,
      stack: error?.stack,
      filename: both?.filename,
      lineno: both?.lineno,
    };
    console.error("Opening DevTools due to unhandled error");
    void TLShot.api.log("Unhandled error:", serialized);
    void TLShot.api.openDevTools({ once: true });
  };

  window.addEventListener("unhandledrejection", handleError);
  window.addEventListener("error", handleError);

  let launched = false;
  const launchTimeout = async () => {
    const timeout = 1000;
    await new Promise((resolve) => setTimeout(resolve, timeout));
    if (launched) return;
    throw new Error(
      `TLShot failed to receive state from main process within ${timeout}ms`
    );
  };

  await Promise.race([
    TLShot.ready.then(() => {
      launched = true;
    }),
    launchTimeout(),
  ]);

  const root = createRoot(document.getElementById("root")!);
  root.render(<Root />);
}

void main();
