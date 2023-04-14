import { Menu, Tray, app, globalShortcut } from "electron";
import { TLShotApi } from "./TLShotApi";
import TRAY_ICON from "./tray-Template@2x.png";
import path from "path";
import { fromEntries, objectEntries } from "@/shared/typeUtils";

const ACTIONS = {
  captureArea: {
    label: "Capture Area",
    accelerator: "CmdOrCtrl+Alt+5",
    click: () => TLShotApi.getInstance().captureArea(),
  },
  captureFullscreen: {
    label: "Capture Fullscreen",
    accelerator: "CmdOrCtrl+Alt+6",
    click: () => TLShotApi.getInstance().captureFullscreen(),
  },
  captureWindow: {
    label: "Capture Window",
    accelerator: "CmdOrCtrl+Alt+7",
    click: () => TLShotApi.getInstance().captureWindow(),
  },
} as const;

export function createTray() {
  // https://bjango.com/articles/designingmenubarextras/#menu-bar-extra-size
  const tray = new Tray(path.resolve(__dirname, TRAY_ICON));

  const actionInfo = fromEntries(
    objectEntries(ACTIONS).map(
      ([key, action]) =>
        [
          key,
          {
            isCapturing: globalShortcut.register(
              action.accelerator,
              action.click
            ),
          },
        ] as const
    )
  );
  app.on("before-quit", () => {
    globalShortcut.unregisterAll();
  });

  const trayMenu = Menu.buildFromTemplate([
    ...objectEntries(ACTIONS).map(([key, action]) => ({
      ...action,
      sublabel: actionInfo[key].isCapturing ? undefined : "In use by other app",
    })),
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
