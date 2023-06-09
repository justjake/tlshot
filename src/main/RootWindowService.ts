/**
 * Supports the Editor window.
 */

import { nativeTheme, BrowserWindow, app } from "electron";
import { TLShotApi } from "./TLShotApi";
import { Preferences } from "./MainProcessPreferences";
import { MainProcessQueries, MainProcessStore } from "./MainProcessStore";
import { atom, react } from "signia";
import { waitUntil } from "@/shared/signiaHelpers";

// This allows TypeScript to pick up the magic constants that's auto-generated by Forge's Webpack
// plugin that tells the Electron app where to look for the Webpack-bundled app code (depending on
// whether you're running in development or production).
declare const EDITOR_WEBPACK_ENTRY: string;
declare const EDITOR_PRELOAD_WEBPACK_ENTRY: string;

export class RootWindowService {
  private quitting = false;

  private rootWindow = atom(
    "rootWindow",
    undefined as BrowserWindow | "pending" | undefined
  );

  constructor() {
    app.on("before-quit", () => {
      this.quitting = true;
    });
    react("createRootWindowWhenNeeded", () => {
      if (this.needsRootWindow() && this.rootWindow.value === undefined) {
        void Promise.resolve().then(() => this.upsertRootWindow());
      }
    });

    react("rootWindowLogger", () => {
      console.log("Service/RootWindow", "changed:", this.rootWindow.value);
    });
  }

  needsRootWindow() {
    if (this.quitting) {
      return false;
    }
    return (
      Preferences.createRootWindowAtStartup ||
      MainProcessQueries.hasActivities.value
    );
  }

  handleRootWindowClose() {
    MainProcessStore.remove(
      MainProcessQueries.allActivities.value.map((a) => a.id)
    );
    this.rootWindow.set(undefined);
  }

  async upsertRootWindow() {
    if (this.rootWindow.value) {
      return waitUntil("rootWindowAvailable", () =>
        this.rootWindow.value !== "pending" ? this.rootWindow.value : undefined
      );
    }

    this.rootWindow.set("pending");
    try {
      const rootWindow = await this.createRootWindow();
      this.rootWindow.set(rootWindow);
      return rootWindow;
    } catch (error) {
      this.rootWindow.set(undefined);
      throw error;
    }
  }

  async getRootWindow() {
    if (this.rootWindow.value === "pending") {
      return waitUntil("rootWindowAvailable", () =>
        this.rootWindow.value !== "pending" ? this.rootWindow.value : undefined
      );
    }

    return this.rootWindow.value;
  }

  isDevToolsOpen(): boolean {
    const rootWindow = this.rootWindow.value;
    if (!rootWindow || rootWindow === "pending") {
      return false;
    }
    return rootWindow.webContents.isDevToolsOpened();
  }

  async openDevTools(options = { once: false }) {
    const rootWindow = await this.upsertRootWindow();
    rootWindow.webContents.openDevTools();
    rootWindow.show();
    if (!options.once) {
      Preferences.showDevToolsOnStartup = true;
    }
  }

  async closeDevTools() {
    const rootWindow = await this.getRootWindow();

    if (rootWindow) {
      rootWindow.webContents.closeDevTools();
      rootWindow.hide();
    }

    Preferences.showDevToolsOnStartup = false;
  }

  private async createRootWindow() {
    if (!app.isReady()) {
      await app.whenReady();
    }

    console.log("RootWindowService: create new root window");
    const isDarkMode =
      nativeTheme.shouldUseDarkColors ||
      nativeTheme.shouldUseInvertedColorScheme;
    const backgroundColor = isDarkMode ? "#212529" : "#f8f9fa";

    // Create the browser window.
    const rootWindow = new BrowserWindow({
      webPreferences: {
        preload: EDITOR_PRELOAD_WEBPACK_ENTRY,
      },
      show: false,
      backgroundColor,
      title: "TLShot Debugger",
    });

    const prevBounds = Preferences.editorWindowBounds;

    if (prevBounds.x >= 0 && prevBounds.y >= 0) {
      rootWindow.setBounds(prevBounds);
    } else {
      rootWindow.setSize(prevBounds.width, prevBounds.height);
      rootWindow.center();
    }

    rootWindow.on("closed", () => {
      console.log('RootWindowService: "closed" event');
      this.handleRootWindowClose();
    });

    // and load the index.html of the app.
    await rootWindow.loadURL(EDITOR_WEBPACK_ENTRY);

    TLShotApi.getInstance().windowDisplayService.handleWindowCreated(
      rootWindow,
      undefined
    );

    // Open the DevTools.
    if (Preferences.showDevToolsOnStartup) {
      rootWindow.webContents.openDevTools();
      rootWindow.show();
    }

    rootWindow.webContents.on("devtools-closed", () => {
      void this.closeDevTools();
    });

    return rootWindow;
  }
}
