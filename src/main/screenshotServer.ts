import {
  SCREENSHOT_PROTOCOL,
  parseScreenshotRequestURL,
} from "@/shared/screenshotProtocol";
import { protocol } from "electron";
import { captureDisplayToFile } from "./darwinDisplayCapture";
import { TLShotApi } from "./TLShotApi";
import { getTempFileName } from "./contentSecurityPolicy";
import * as fs from "fs-extra";

export function enableScreenshotProtocol() {
  protocol.interceptFileProtocol(SCREENSHOT_PROTOCOL, async (req, callback) => {
    const url = new URL(req.url);
    const request = parseScreenshotRequestURL(url);
    console.log("screenshot:", request);

    const filePath = getTempFileName(`screenshotServer-${request.id}.png`);
    if (!(await fs.pathExists(filePath))) {
      console.log("screenshot: create", filePath);
      // TODO: support rect
      await captureDisplayToFile({
        filePath,
        _spdisplays_displayID: String(request.displayId),
        displays:
          await TLShotApi.getInstance().windowDisplayService.getSPDisplays(),
      });
    } else {
      console.log("screenshot: exists", filePath);
    }

    // TODO: other screenshot formats?
    callback({ path: filePath, mimeType: "image/png" });
  });
}
