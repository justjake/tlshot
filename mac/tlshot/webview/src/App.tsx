import { useEffect, useMemo, useState } from "react";
import {
  AssetRecordType,
  Box,
  DefaultColorStyle,
  DefaultSizeStyle,
  Editor,
  TLComponents,
  TLImageAsset,
  TLImageShape,
  TLShapePartial,
  Tldraw,
  TldrawOptions,
  createShapeId,
  getHashForString,
} from "tldraw";
import { bridge, BridgeIncomingHandlers } from "./Bridge";
import { exportPng } from "./exportHelpers";
import { BridgeImageAssetProps } from "./BridgeTypes";

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
      addAsset: async (props) => {
        addAsset(editor, props);
        return {};
      },
      zoomToFit: async () => {
        setTimeout(() => {
          const bounds = getPageBounds(editor);
          if (bounds) {
            editor.zoomToBounds(bounds, {
              inset: bridge.getGutterSize(),
              animation: { duration: 100 },
            });
          }
        });
        return {};
      },
    };
  }, [editor]);

  useEffect(() => {
    if (!editor) return;
    if (!registerApi) return;
    (globalThis as any).__tldraw__ = editor;
    bridge.register(registerApi);
    editor.run(() => {
      editor.user.updateUserPreferences({
        // Brush size, etc relative to zoom.
        // Zoom in to draw finer details
        // https://tldraw.substack.com/i/145825699/whats-new
        isDynamicSizeMode: true,
        colorScheme: bridge.env.theme,
        isSnapMode: true,
      });
      editor.setStyleForNextShapes(DefaultColorStyle, "blue");
      editor.setStyleForNextShapes(DefaultSizeStyle, "xl");
      createInitialAsset(editor);
    });
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

let initialImageId: TLImageShape["id"] | undefined;
let initialImageUnlocked = false;

function createInitialAsset(editor: Editor) {
  const { initialAsset } = bridge.env;
  if (!initialAsset) {
    bridge.rendered();
    return;
  }
  addAsset(editor, initialAsset);
  setTimeout(() => {
    const bounds = getPageBounds(editor);
    if (bounds) {
      editor.zoomToBounds(bounds, {
        inset: 0,
      });
      bridge.rendered();
    }
  });
}

function addAsset(editor: Editor, initialAsset: BridgeImageAssetProps) {
  const urlHash = getHashForString(initialAsset.src);
  const asset: TLImageAsset = {
    id: AssetRecordType.createId(urlHash),
    meta: {},
    props: initialAsset,
    type: "image",
    typeName: "asset",
  };

  const existingImages = editor
    .getCurrentPageShapesSorted()
    .filter((shape) => shape.type === "image") as TLImageShape[];
  let maxTrailingBound = -Infinity;
  for (const image of existingImages) {
    maxTrailingBound = Math.max(
      maxTrailingBound,
      editor.getShapePageBounds(image)?.maxX ?? -Infinity
    );
  }

  const shape: TLShapePartial = {
    id: createShapeId(asset.id),
    type: "image",
    x:
      maxTrailingBound === -Infinity
        ? 0
        : maxTrailingBound + bridge.getGutterSize(),
    y: 0,
    opacity: 1,
    // Draw stuff relative to the image please
    isLocked: existingImages.length === 0,
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

  if (existingImages.length === 0) {
    initialImageId = shape.id;
  } else if (initialImageId && !initialImageUnlocked) {
    editor.updateShape({ id: initialImageId, type: "image", isLocked: false });
    initialImageUnlocked = true;
  }
}

function getPageBounds(editor: Editor) {
  const ids = [...editor.getCurrentPageShapeIds()];
  if (ids.length <= 0) return;
  return Box.Common(compact(ids.map((id) => editor.getShapePageBounds(id))));
}

function compact<T>(array: (T | null | undefined)[]): T[] {
  return array.filter((x) => x !== null && x !== undefined) as T[];
}
