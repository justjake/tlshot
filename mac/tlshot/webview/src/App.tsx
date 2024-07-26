import { useEffect, useMemo, useRef, useState } from "react";
import {
  AssetRecordType,
  Editor,
  PngHelpers,
  TLComponents,
  TLDefaultShape,
  TLImageAsset,
  TLShapePartial,
  Tldraw,
  TldrawOptions,
  createShapeId,
  getHashForString,
  useEditor,
} from "tldraw";
import { bridge, BridgeIncomingHandlers } from "./Bridge";
import { exportPng } from "./exportHelpers";

function TopPanel() {
  const save = () => {
    bridge.notify({
      type: "prepareSave",
      data: {
        saveId: Date.now().toString(),
      },
    });
  };

  return (
    <div
      style={{
        position: "relative",
        zIndex: 300,
        pointerEvents: "all",
        maxWidth: "50%",
      }}
    >
      <button onClick={save}>Save</button>
    </div>
  );
}

const components: TLComponents = {
  TopPanel,
};

const EDITOR_OPTIONS: Partial<TldrawOptions> = {
  defaultSvgPadding: 0,
};

function App() {
  const [editor, setEditor] = useState<Editor | null>(null);

  const registerApi = useMemo<BridgeIncomingHandlers | undefined>(() => {
    if (!editor) return;

    return {
      save: async () => {
        const image = await exportPng(editor);
        const arrayBuffer = await image.arrayBuffer();
        return {
          httpUpload: arrayBuffer,
        };
      },
    };
  }, [editor]);

  useEffect(() => {
    if (!editor) return;
    if (!registerApi) return;
    (globalThis as any).__tldraw__ = editor;
    bridge.register(registerApi);
    editor.user.updateUserPreferences({
      colorScheme: bridge.env.theme,
      isSnapMode: true,
    });
    createInitialAsset(editor);
  }, [editor]);

  return (
    <div style={{ position: "fixed", inset: 0 }}>
      <Tldraw
        inferDarkMode
        onMount={setEditor}
        components={components}
        options={EDITOR_OPTIONS}
      ></Tldraw>
    </div>
  );
}

export default App;

function createInitialAsset(editor: Editor) {
  const { initialAsset } = bridge.env;
  if (!initialAsset) {
    return;
  }

  const urlHash = getHashForString(initialAsset.src);
  const asset: TLImageAsset = {
    id: AssetRecordType.createId(urlHash),
    meta: {},
    props: initialAsset,
    type: "image",
    typeName: "asset",
  };
  const shape: TLShapePartial = {
    id: createShapeId(asset.id),
    type: "image",
    x: 0,
    y: 0,
    opacity: 1,
    // Draw stuff relative to the image please
    isLocked: true,
    props: {
      assetId: asset.id,
      // Scale for @2x
      h: asset.props.h / 2,
      w: asset.props.w / 2,
    },
    meta: {},
    typeName: "shape",
  };
  editor.createAssets([asset]);
  editor.createShape(shape);
  setTimeout(() => {
    editor.zoomToFit();
  }, 0);
}
