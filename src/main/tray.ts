import { Menu, Tray, app, dialog, globalShortcut } from "electron";
import { TLShotApi } from "./TLShotApi";
import TRAY_ICON from "./tray-Template@2x.png";
import path from "path";
import { fromEntries, objectEntries } from "@/shared/typeUtils";
import { atom, react } from "signia";
import { Preferences } from "./MainProcessPreferences";
import { MainProcessQueries } from "./MainProcessStore";

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
            globalShortcutRegistered: globalShortcut.register(
              action.accelerator,
              action.click
            ),
          },
        ] as const
    )
  );

  // react("whenCapturingEscapeCancels", () => {
  //   const handleEscapeWhenCapturing = () => {
  //     console.log("handleEscapeWhenCapturing");
  //     TLShotApi.getInstance().cancelCapture();
  //   };

  //   if (MainProcessQueries.hasCaptureActivity) {
  //     globalShortcut.register("Escape", handleEscapeWhenCapturing);
  //   } else {
  //     globalShortcut.unregister("Escape");
  //   }

  //   // TODO: handle copy?
  // });

  app.on("before-quit", () => {
    globalShortcut.unregisterAll();
  });

  // We toggle this atom on check to sync things up with preferences.
  const checkedAtom = atom("checked", 0);
  react("updateTrayMenu", () => {
    checkedAtom.value;

    const trayMenu = Menu.buildFromTemplate([
      ...objectEntries(ACTIONS).map(([key, action]) => ({
        ...action,
        sublabel: actionInfo[key].globalShortcutRegistered
          ? undefined
          : "In use by other app",
      })),
      { type: "separator" },
      {
        label: `Save to ${getFriendlyPath(Preferences.saveLocation)}`,
        enabled: false,
      },
      {
        label: `Choose folder...`,
        click: async () => {
          const shownInDock = app.dock.isVisible();
          if (!shownInDock) {
            await app.dock.show();
          }

          try {
            app.focus({ steal: true });
            const resultPromise = dialog.showOpenDialog({
              title: "Choose save folder",
              message: "Choose save folder",
              buttonLabel: "Set default",
              defaultPath: Preferences.saveLocation,
              properties: [
                "openDirectory",
                "createDirectory", // macOS: allow creating directories
                "promptToCreate", // windows: allow non-existing directories
              ],
            });
            const result = await resultPromise;
            console.log("Choose save folder", result);
            if (result.canceled || result.filePaths.length === 0) {
              return;
            }
            Preferences.saveLocation = result.filePaths[0];
          } finally {
            if (!shownInDock) {
              app.dock.hide();
            }
          }
        },
      },
      {
        label: "Debug",
        type: "checkbox",
        checked: Preferences.showDevToolsOnStartup,
        sublabel: "hello.",
        click: () => {
          if (
            Preferences.showDevToolsOnStartup &&
            TLShotApi.getInstance().rootWindowService.isDevToolsOpen()
          ) {
            void TLShotApi.getInstance().rootWindowService.closeDevTools();
          } else {
            void TLShotApi.getInstance().rootWindowService.openDevTools();
          }
          checkedAtom.set(checkedAtom.value + 1);
        },
      },
      {
        label: "Quit",
        accelerator: "CmdOrCtrl+Q",
        click: () => TLShotApi.getInstance().quit(),
      },
    ]);
    tray.setContextMenu(trayMenu);
  });
}

function getFriendlyPath(filePath: string) {
  if (filePath.startsWith(app.getPath("home"))) {
    return `~${filePath.slice(app.getPath("home").length)}`;
  }

  return filePath;
}
