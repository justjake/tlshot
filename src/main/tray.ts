import { Menu } from "electron";
import { Tray } from "electron";
import { TLShotApi } from "./TLShotApi";
import TRAY_ICON from "./tray-icon.png";
import path from "path";

export function createTray() {
  const tray = new Tray(path.resolve(__dirname, TRAY_ICON));
  const trayMenu = Menu.buildFromTemplate([
    {
      label: "Capture Area",
      accelerator: "CmdOrCtrl+Alt+5",
      click: () => TLShotApi.captureArea(),
    },
    {
      label: "Capture Fullscreen",
      accelerator: "CmdOrCtrl+Alt+6",
      click: () => TLShotApi.captureFullscreen(),
    },
    {
      label: "Capture Window",
      accelerator: "CmdOrCtrl+Alt+7",
      click: () => TLShotApi.captureWindow(),
    },
    { type: "separator" },
    {
      label: "Quit",
      accelerator: "CmdOrCtrl+Q",
      click: () => TLShotApi.quit(),
    },
  ]);
  tray.setContextMenu(trayMenu);
}
