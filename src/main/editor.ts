/**
 * Supports the Editor window.
 */

import { nativeTheme, BrowserWindow } from "electron";
import { TLShotApi } from "./TLShotApi";
import { MainProcessPreferences } from "./MainProcessPreferences";

// This allows TypeScript to pick up the magic constants that's auto-generated by Forge's Webpack
// plugin that tells the Electron app where to look for the Webpack-bundled app code (depending on
// whether you're running in development or production).
declare const EDITOR_WEBPACK_ENTRY: string;
declare const EDITOR_PRELOAD_WEBPACK_ENTRY: string;

export async function createEditorWindow() {
  const isDarkMode =
    nativeTheme.shouldUseDarkColors || nativeTheme.shouldUseInvertedColorScheme;
  const backgroundColor = isDarkMode ? "#212529" : "#f8f9fa";

  console.log({
    EDITOR_WEBPACK_ENTRY: EDITOR_WEBPACK_ENTRY,
    EDITOR_PRELOAD_WEBPACK_ENTRY: EDITOR_PRELOAD_WEBPACK_ENTRY,
  });

  // Create the browser window.
  const editorWindow = new BrowserWindow({
    webPreferences: {
      preload: EDITOR_PRELOAD_WEBPACK_ENTRY,
    },
    show: false,
    backgroundColor,
  });

  const prevBounds = MainProcessPreferences.get("editorWindowBounds", {
    width: 1024,
    height: 768,
    x: -1,
    y: -1,
  });

  if (prevBounds.x >= 0 && prevBounds.y >= 0) {
    editorWindow.setBounds(prevBounds);
  } else {
    editorWindow.setSize(prevBounds.width, prevBounds.height);
    editorWindow.center();
  }

  editorWindow.on("close", () => {
    MainProcessPreferences.set(
      "editorWindowDevtools",
      editorWindow.webContents.isDevToolsOpened()
    );
    MainProcessPreferences.set("editorWindowBounds", editorWindow.getBounds());
  });

  // and load the index.html of the app.
  await editorWindow.loadURL(EDITOR_WEBPACK_ENTRY);

  // Open the DevTools.
  if (MainProcessPreferences.get("editorWindowDevtools", false)) {
    editorWindow.webContents.openDevTools();
  }

  TLShotApi.getInstance().windowDisplayService.handleWindowCreated(
    editorWindow,
    undefined
  );

  editorWindow.show();
}
