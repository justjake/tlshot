import { app } from "electron";
import { execa } from "execa";
import { nanoid } from "nanoid";
import path from "path";
import fs from "fs-extra";
import { getTempFileName } from "./contentSecurityPolicy";

/**
 * We read displays using `system_profiler SPDisplaysDataType -json` which outputs the following format.
 * Then, we pass the *index* of the display to `screencapture -D <index>` to capture that display.
 */
interface SystemProfilerOutput {
  SPDisplaysDataType: SPDisplayGPU[];
}

interface SPDisplayGPU {
  _name: string;
  spdisplays_ndrvs: SPDisplay[];
}

export interface SPDisplay {
  _name: string;
  /** Appears to correspond with Electron's Display.id */
  _spdisplays_displayID: string;
}

export async function getSPDisplays(): Promise<SPDisplay[]> {
  const { stdout } = await execa("system_profiler", [
    "SPDisplaysDataType",
    "-json",
  ]);
  // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
  const output: SystemProfilerOutput = JSON.parse(stdout);
  const displays: SPDisplay[] = [];
  for (const gpu of output.SPDisplaysDataType) {
    for (const display of gpu.spdisplays_ndrvs) {
      displays.push(display);
    }
  }
  return displays;
}

export async function captureDisplayToFile(args: {
  displays: SPDisplay[];
  _spdisplays_displayID: string;
}): Promise<string> {
  const index = args.displays.findIndex(
    (display) => display._spdisplays_displayID === args._spdisplays_displayID
  );
  if (index === -1) {
    throw new Error(
      `No display with _spdisplays_displayID ${args._spdisplays_displayID} found`
    );
  }
  const tempFileName = getTempFileName(
    `${new Date().toISOString()}-${nanoid()}.png`
  );
  await execa("screencapture", [
    "-D",
    String(index + 1),
    "-x",
    "-t",
    "png",
    tempFileName,
  ]);

  app.on("before-quit", () => {
    if (fs.existsSync(tempFileName)) {
      fs.removeSync(tempFileName);
    }
  });

  return tempFileName;
}

/*
const example = {
  SPDisplaysDataType: [
    {
      _name: "Apple M1 Max",
      spdisplays_mtlgpufamilysupport: "spdisplays_metal3",
      spdisplays_ndrvs: [
        {
          _name: "LG UltraFine",
          "_spdisplays_display-product-id": "5b11",
          "_spdisplays_display-serial-number": "71e1c",
          "_spdisplays_display-vendor-id": "9e6d",
          "_spdisplays_display-week": "12",
          "_spdisplays_display-year": "2017",
          _spdisplays_displayID: "4",
          _spdisplays_pixels: "5120 x 2880",
          _spdisplays_resolution: "2560 x 1440 @ 60.00Hz",
          spdisplays_ambient_brightness: "spdisplays_no",
          spdisplays_main: "spdisplays_yes",
          spdisplays_mirror: "spdisplays_off",
          spdisplays_online: "spdisplays_yes",
          spdisplays_pixelresolution: "spdisplays_5k-uhgplus",
          spdisplays_resolution: "2560 x 1440 @ 60.00Hz",
          spdisplays_rotation: "spdisplays_supported",
        },
        {
          _name: "Color LCD",
          "_spdisplays_display-product-id": "a050",
          "_spdisplays_display-serial-number": "fd626d62",
          "_spdisplays_display-vendor-id": "610",
          "_spdisplays_display-week": "0",
          "_spdisplays_display-year": "0",
          _spdisplays_displayID: "1",
          _spdisplays_pixels: "3456 x 2234",
          _spdisplays_resolution: "1728 x 1117 @ 120.00Hz",
          spdisplays_ambient_brightness: "spdisplays_yes",
          spdisplays_connection_type: "spdisplays_internal",
          spdisplays_display_type: "spdisplays_built-in-liquid-retina-xdr",
          spdisplays_mirror: "spdisplays_off",
          spdisplays_online: "spdisplays_yes",
          spdisplays_pixelresolution: "spdisplays_3456x2234Retina",
        },
      ],
      spdisplays_vendor: "sppci_vendor_Apple",
      sppci_bus: "spdisplays_builtin",
      sppci_cores: "32",
      sppci_device_type: "spdisplays_gpu",
      sppci_model: "Apple M1 Max",
    },
  ],
};
*/
