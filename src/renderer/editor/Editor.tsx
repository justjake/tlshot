/**
 * https://docs.tldraw.dev/docs/ucg/usage
 */
import "@tldraw/tldraw/editor.css";
import "@tldraw/tldraw/ui.css";

import { getBundlerAssetUrls } from "@tldraw/assets";
import {
  TldrawEditor,
  Canvas,
  useApp,
  TLInstance,
  TldrawEditorConfig,
  TLUser,
  App,
} from "@tldraw/editor";
import {
  TldrawUi,
  ContextMenu,
  TldrawUiContextProviderProps,
} from "@tldraw/ui";
import { CaptureView } from "./CaptureToolbar";
import { useColorScheme } from "./useColorScheme";
import { useEffect, useState } from "react";
import { EditorRecord } from "@/shared/records/EditorRecord";
import { completeEditorForCapture } from "./captureHelpers";
import { RecordAttachmentMap } from "@/shared/EphemeralMap";
import { TLShot } from "../TLShotRendererApp";
import { atom, react } from "signia";
import { isEqual } from "lodash";
import { PREFERENCES_ID } from "@/shared/records/PreferencesRecord";

const TLDRAW_ASSETS = getBundlerAssetUrls({
  format: (url: string) => url,
});

const UIContextProps: TldrawUiContextProviderProps = {
  assetUrls: TLDRAW_ASSETS,
};

const EDITOR_TO_APP = new RecordAttachmentMap<EditorRecord, App>(TLShot.store);
const EDITOR_MAP_DID_CHANGE = atom("EditorToAppDidChange", 0);

export function getEditorApp(editor: EditorRecord): App | undefined {
  EDITOR_MAP_DID_CHANGE.value;
  return EDITOR_TO_APP.map.get(editor.id);
}

export function Editor(props: { editor: EditorRecord }) {
  const { editor } = props;
  const scheme = useColorScheme();
  const [editorStore] = useState(() =>
    TldrawEditorConfig.default.createStore({
      instanceId: TLInstance.createId(),
      userId: TLUser.createId(),
    })
  );

  return (
    <TldrawEditor
      instanceId={editorStore.props.instanceId}
      store={editorStore}
      onMount={(app) => {
        app.updateInstanceState({
          isDebugMode: false,
        });
        EDITOR_TO_APP.map.set(editor.id, app);
        EDITOR_MAP_DID_CHANGE.update((n) => n + 1);
      }}
      isDarkMode={scheme === "dark"}
      {...UIContextProps}
    >
      <EditorEffects editor={editor} />

      <TldrawUi {...UIContextProps}>
        <ContextMenu>
          <Canvas />
        </ContextMenu>

        <CaptureView />
        <EditorEffects editor={editor} />
      </TldrawUi>
    </TldrawEditor>
  );
}

function EditorEffects(props: { editor: EditorRecord }) {
  const { editor } = props;
  useComputeEditorForCapture(editor);
  useSaveShapeStyle();
  return null;
}

function useComputeEditorForCapture(editor: EditorRecord) {
  const app = useApp();

  useEffect(() => {
    if (!editor) return;
    void completeEditorForCapture(editor, app);
  }, [app, editor]);
}

function useSaveShapeStyle() {
  const app = useApp();

  // When the app boots, restore the user's previous shape style.
  useEffect(() => {
    const propsForNextShape =
      TLShot.queries.preferences.value?.propsForNextShape;
    if (propsForNextShape) {
      console.log("restore propsForNextShape", propsForNextShape);
      app.updateInstanceState({ propsForNextShape });
    }
  }, [app]);

  // When shape style changes, save it to the user's preferences.
  useEffect(() => {
    let first = true;
    return react("saveShapeStyle", () => {
      const nextShapeStyle = app.instanceState.propsForNextShape;
      const currentShapeStyle =
        TLShot.queries.preferences.value?.propsForNextShape;
      if (!isEqual(nextShapeStyle, currentShapeStyle)) {
        if (first) {
          first = false;
          return;
        }
        void Promise.resolve().then(() => {
          TLShot.store.update(PREFERENCES_ID, (prefs) => ({
            ...prefs,
            propsForNextShape: nextShapeStyle,
          }));
        });
      }
    });
  }, [app]);
}
