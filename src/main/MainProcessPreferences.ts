import PreferenceStore from "electron-store";

export interface Preferences {
  editorWindowBounds?: Electron.Rectangle;
  editorWindowDevtools?: boolean;
}

export const MainProcessPreferences = new PreferenceStore<Preferences>();
