import { useEffect, useMemo, useState } from "react";
import {
  AssetRecordType,
  Box,
  Editor,
  TLComponents,
  TLImageAsset,
  TLShapePartial,
  Tldraw,
  TldrawOptions,
  createShapeId,
  getHashForString,
} from "tldraw";
import { bridge, BridgeIncomingHandlers } from "./Bridge";
import { exportPng } from "./exportHelpers";

const components: TLComponents = {};

const EDITOR_OPTIONS: Partial<TldrawOptions> = {
  defaultSvgPadding: 0,
  maxPages: 1,
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
      // Brush size, etc relative to zoom.
      // Zoom in to draw finer details
      // https://tldraw.substack.com/i/145825699/whats-new
      isDynamicSizeMode: true,
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
      h: asset.props.h,
      w: asset.props.w,
    },
    meta: {},
    typeName: "shape",
  };
  editor.run(() => {
    editor.createAssets([asset]);
    editor.createShape(shape);
  });
  setTimeout(() => {
    zoomToFitWithInset(editor, 0);
  });
}

function zoomToFitWithInset(editor: Editor, inset: number) {
  const ids = [...editor.getCurrentPageShapeIds()];
  if (ids.length <= 0) return;
  const pageBounds = Box.Common(
    compact(ids.map((id) => editor.getShapePageBounds(id)))
  );
  editor.zoomToBounds(pageBounds, {
    inset,
  });
}

function compact<T>(array: (T | null | undefined)[]): T[] {
  return array.filter((x) => x !== null && x !== undefined) as T[];
}
