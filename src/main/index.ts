import { app } from "electron";
import { startServices, TLShotApi } from "./TLShotApi";
import { createTray } from "./tray";
import { MainProcessQueries } from "./MainProcessStore";
import { react } from "signia";

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require("electron-squirrel-startup")) {
  app.quit();
}

// Show the dock icon when we have Editor activities, otherwise hide it.
react("controlDockIcon", () => {
  if (MainProcessQueries.hasEditors.value) {
    void app.dock.show();
  } else {
    app.dock.hide();
  }
});

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
// eslint-disable-next-line @typescript-eslint/no-misused-promises
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
