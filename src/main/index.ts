import { app } from "electron";
import { TLShotApi, startServices } from "./TLShotApi";
import { createTray } from "./tray";
import { MainProcessQueries } from "./MainProcessStore";
import { react } from "signia";

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require("electron-squirrel-startup")) {
  app.quit();
}

// Show the dock icon when we have windows.
react("controlDockIcon", () => {
  if (MainProcessQueries.hasEditors.value) {
    app.setActivationPolicy("regular");
    void app.dock.show();
  } else {
    app.setActivationPolicy("accessory");
    app.dock.hide();
  }
});

app.on("window-all-closed", () => {
  // Do nothing. If we don't subscribe, quits when all windows are closed.
});

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on("ready", async () => {
  await startServices();
  createTray();
});

app.on("activate", () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (process.platform === "darwin") {
    if (!MainProcessQueries.hasActivities.value) {
      TLShotApi.getInstance().storeService.createEditorWindow();
      console.log("activate: create editor window");
    }
  }
});
