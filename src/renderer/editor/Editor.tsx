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
import { atom } from "signia";

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
      <TldrawUi {...UIContextProps}>
        <ContextMenu>
          <Canvas />
        </ContextMenu>

        <CaptureView />
        <CompleteCaptureEffect editor={editor} />
      </TldrawUi>
    </TldrawEditor>
  );
}

function CompleteCaptureEffect(props: { editor: EditorRecord | undefined }) {
  const { editor } = props;

  const app = useApp();

  useEffect(() => {
    if (!editor) return;
    void completeEditorForCapture(editor, app);
  }, [app, editor]);

  return null;
}
