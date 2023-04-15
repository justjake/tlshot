import PreferenceStore from "electron-store";
import { Atom, atom, react, transact } from "signia";
import path from "path";
import { app } from "electron";
import {
  PREFERENCES_ID,
  PreferencesRecord,
} from "@/shared/records/PreferencesRecord";
import { MainProcessStore } from "./MainProcessStore";
import { TLInstancePropsForNextShape } from "@tldraw/editor";
import { iterateChanges } from "@/shared/store";
import { objectEntries } from "@/shared/typeUtils";

export interface Preferences {
  editorWindowBounds: Electron.Rectangle;
  showDevToolsOnStartup: boolean;
  saveLocation: string;
  propsForNextShape: TLInstancePropsForNextShape | undefined;
  createRootWindowAtStartup: boolean;
}

export class ReactivePreferences implements Required<Preferences> {
  private persisted = new PreferenceStore<Preferences>();
  private atoms = new Map<keyof Preferences, Atom<any>>();

  private get<K extends keyof Preferences>(
    name: K,
    defaultValue: Required<Preferences>[K]
  ) {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    const preferenceAtom: Atom<Required<Preferences>[K]> =
      this.atoms.get(name) ??
      atom<Required<Preferences>[K]>(
        `preferences.${name}`,
        this.persisted.get(name, defaultValue)
      );
    this.atoms.set(name, preferenceAtom);
    return preferenceAtom.value;
  }

  private set<K extends keyof Preferences>(
    name: K,
    value: Required<Preferences>[K]
  ) {
    this.persisted.set(name, value);
    this.atoms.get(name)?.set(value);
  }

  public get saveLocation() {
    const defaultSaveLocation = path.join(
      app.getPath("pictures"),
      "Screenshots"
    );
    return this.get("saveLocation", defaultSaveLocation);
  }

  public set saveLocation(value: string) {
    this.set("saveLocation", value);
  }

  public get editorWindowBounds() {
    return this.get("editorWindowBounds", {
      width: 1024,
      height: 768,
      x: -1,
      y: -1,
    });
  }

  public set editorWindowBounds(value: Electron.Rectangle) {
    this.set("editorWindowBounds", value);
  }

  public get showDevToolsOnStartup() {
    return this.get("showDevToolsOnStartup", false);
  }

  public set showDevToolsOnStartup(value: boolean) {
    this.set("showDevToolsOnStartup", value);
  }

  public get propsForNextShape() {
    return this.get("propsForNextShape", undefined);
  }

  public set propsForNextShape(value: TLInstancePropsForNextShape | undefined) {
    this.set("propsForNextShape", value);
  }

  public get createRootWindowAtStartup() {
    return this.get("createRootWindowAtStartup", true);
  }

  public set createRootWindowAtStartup(value: boolean) {
    this.set("createRootWindowAtStartup", value);
  }
}

export const Preferences = new ReactivePreferences();

react("updatePreferencesRecord", () => {
  const preferencesRecord = PreferencesRecord.create({
    id: PREFERENCES_ID,
    editorWindowBounds: Preferences.editorWindowBounds,
    showDevToolsOnStartup: Preferences.showDevToolsOnStartup,
    saveLocation: Preferences.saveLocation,
    propsForNextShape: Preferences.propsForNextShape,
    createRootWindowAtStartup: Preferences.createRootWindowAtStartup,
  });

  void Promise.resolve().then(() => MainProcessStore.put([preferencesRecord]));
});

MainProcessStore.listen((history) => {
  if (history.source === "user") {
    return;
  }

  for (const [id, _before, after] of iterateChanges(history.changes)) {
    if (PreferencesRecord.isInstance(after)) {
      transact(() => {
        for (const [key, value] of objectEntries(after)) {
          if (!(key in Preferences)) {
            continue;
          }

          const prefKey = key as keyof ReactivePreferences;
          const differs =
            JSON.stringify(Preferences[prefKey]) !== JSON.stringify(value);
          if (differs) {
            console.log(
              "MainProcessPreferences: updated",
              prefKey,
              Preferences[prefKey],
              "->",
              value
            );
            // eslint-disable-next-line @typescript-eslint/ban-ts-comment
            // @ts-expect-error
            // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
            Preferences[prefKey] = value as any;
          }
        }
      });
    }
  }
});
