import { Menu, Tray } from "electron";
import { TLShotApi } from "./TLShotApi";
import TRAY_ICON from "./tray-Template@2x.png";
import path from "path";

export function createTray() {
  // https://bjango.com/articles/designingmenubarextras/#menu-bar-extra-size
  const tray = new Tray(path.resolve(__dirname, TRAY_ICON));
  const trayMenu = Menu.buildFromTemplate([
    {
      label: "Capture Area",
      accelerator: "CmdOrCtrl+Alt+5",
      click: () => TLShotApi.getInstance().captureArea(),
    },
    {
      label: "Capture Fullscreen",
      accelerator: "CmdOrCtrl+Alt+6",
      click: () => TLShotApi.getInstance().captureFullscreen(),
    },
    {
      label: "Capture Window",
      accelerator: "CmdOrCtrl+Alt+7",
      click: () => TLShotApi.getInstance().captureWindow(),
    },
    { type: "separator" },
    {
      label: "Open DevTools",
      click: () =>
        void TLShotApi.getInstance().rootWindowService.openDevTools(),
    },
    {
      label: "Quit",
      accelerator: "CmdOrCtrl+Q",
      click: () => TLShotApi.getInstance().quit(),
    },
  ]);
  tray.setContextMenu(trayMenu);
}
