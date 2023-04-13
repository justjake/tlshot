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

const TLDRAW_ASSETS = getBundlerAssetUrls({
  format: (url: string) => url,
});

const UIContextProps: TldrawUiContextProviderProps = {
  assetUrls: TLDRAW_ASSETS,
};

export function Editor(props: { editor: EditorRecord | undefined }) {
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
      onMount={(app) =>
        app.updateInstanceState({
          isDebugMode: false,
        })
      }
      isDarkMode={scheme === "dark"}
      {...UIContextProps}
    >
      <TldrawUi {...UIContextProps}>
        <ContextMenu>
          <Canvas />
        </ContextMenu>

        <CaptureView />
        <CompleteCaptureEffect editor={props.editor} />
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
