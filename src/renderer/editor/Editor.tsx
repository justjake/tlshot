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
  EditorAssetUrls,
} from "@tldraw/editor";
import {
  TldrawUi,
  ContextMenu,
  TldrawUiContextProviderProps,
} from "@tldraw/ui";
import { CaptureView } from "./CaptureToolbar";
import { useColorScheme } from "./useColorScheme";
import { useEffect, useMemo, useState } from "react";
import { EditorRecord } from "@/shared/records/EditorRecord";
import { completeEditorForCapture } from "./captureHelpers";
import { RecordAttachmentMap } from "@/shared/EphemeralMap";
import { TLShot } from "../TLShotRendererApp";
import { atom, react } from "signia";
import { isEqual } from "lodash";
import { PREFERENCES_ID } from "@/shared/records/PreferencesRecord";
import { useGetWindow } from "./ChildWindow";

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
      autoFocus={true}
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
  useUpdateWindowEdited();
  return null;
}

function useUpdateWindowEdited() {
  const window = useGetWindow();
  const app = useApp();
  useEffect(() => {
    return react("updateWindowEdited", () => {
      const hasEdits = app.shapeIds.size > 0;
      void TLShot.api.updateChildWindow(window.childWindowNanoid, {
        edited: hasEdits,
      });
    });
  }, [app, window]);
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

type TLTypeFace = {
  url: string;
  display?: any; // FontDisplay
  featureSettings?: string;
  stretch?: string;
  style?: string;
  unicodeRange?: string;
  variant?: string;
  weight?: string;
};

export type TLTypeFaces = {
  draw: TLTypeFace;
  monospace: TLTypeFace;
  serif: TLTypeFace;
  sansSerif: TLTypeFace;
};

enum PreloadStatus {
  SUCCESS,
  FAILED,
  WAITING,
}

const usePreloadFont = (id: string, font: TLTypeFace): PreloadStatus => {
  const [state, setState] = useState<PreloadStatus>(PreloadStatus.WAITING);

  useEffect(() => {
    const {
      url,
      style = "normal",
      weight = "500",
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      display,
      featureSettings,
      stretch,
      unicodeRange,
      variant,
    } = font;

    let cancelled = false;
    setState(PreloadStatus.WAITING);

    const descriptors: FontFaceDescriptors = {
      style,
      weight,
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      display,
      featureSettings,
      stretch,
      unicodeRange,
      variant,
    };

    const fontInstance = new FontFace(id, `url(${url})`, descriptors);

    fontInstance
      .load()
      .then(() => {
        if (cancelled) return;
        document.fonts.add(fontInstance);
        setState(PreloadStatus.SUCCESS);
      })
      .catch((err) => {
        if (cancelled) return;
        console.error(err);
        setState(PreloadStatus.FAILED);
      });

    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    fontInstance.$$_url = url;

    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    fontInstance.$$_fontface = `
@font-face {
	font-family: ${fontInstance.family};
	font-stretch: ${fontInstance.stretch};
	font-weight: ${fontInstance.weight};
	font-style: ${fontInstance.style};
	src: url("${url}") format("woff2")
}`;

    return () => {
      document.fonts.delete(fontInstance);
      cancelled = true;
    };
  }, [id, font]);

  return state;
};

function getTypefaces(assetUrls: EditorAssetUrls) {
  return {
    draw: { url: assetUrls.fonts.draw },
    serif: { url: assetUrls.fonts.serif },
    sansSerif: { url: assetUrls.fonts.sansSerif },
    monospace: { url: assetUrls.fonts.monospace },
  };
}

// todo: Expose this via a public API (prop on <Tldraw>).

function usePreloadAssetsInternal(assetUrls: EditorAssetUrls) {
  const typefaces = useMemo(() => getTypefaces(assetUrls), [assetUrls]);

  const results = [
    usePreloadFont("tldraw_draw", typefaces.draw),
    usePreloadFont("tldraw_serif", typefaces.serif),
    usePreloadFont("tldraw_sans", typefaces.sansSerif),
    usePreloadFont("tldraw_mono", typefaces.monospace),
  ];

  return {
    // If any of the results have errored, then preloading has failed
    error: results.some((result) => result === PreloadStatus.FAILED),
    // If any of the results are waiting, then we're not done yet
    done: !results.some((result) => result === PreloadStatus.WAITING),
  };
}

export function usePreloadAssets() {
  usePreloadAssetsInternal(TLDRAW_ASSETS);
}
