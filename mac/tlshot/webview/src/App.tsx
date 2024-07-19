import { useEffect, useState } from "react";
import {
  AssetRecordType,
  Editor,
  TLImageAsset,
  TLShapePartial,
  Tldraw,
  createShapeId,
  getHashForString,
  getSvgAsImage,
} from "tldraw";
import { bridge } from "./Bridge";

function App() {
  const [editor, setEditor] = useState<Editor | null>(null);

  useEffect(() => {
    if (!editor) return;
    (globalThis as any).__tldraw__ = editor;
    bridge.register({
      save: async () => {
        const svg = await editor.getSvgString(
          Array.from(editor.getPageShapeIds(editor.getCurrentPageId())),
          {
            scale: 2,
          }
        );
        if (!svg) {
          throw new Error("Failed to get SVG string");
        }
        const image = await getSvgAsImage(editor, svg.svg, {
          quality: 100,
          scale: 1,
          type: "png",
          width: svg.width,
          height: svg.height,
        });
        if (!image) {
          throw new Error("Failed to get image");
        }

        const arrayBuffer = await image.arrayBuffer();
        console.log("image byte length:", arrayBuffer.byteLength);
        return {
          ...svg,
          httpUpload: arrayBuffer,
        };
      },
    });
    editor.user.updateUserPreferences({ colorScheme: bridge.env.theme });

    const { initialAsset } = bridge.env;
    if (initialAsset) {
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
      editor.createShape(shape);
      editor.createAssets([asset]);
      setTimeout(() => {
        editor.zoomToFit();
      }, 0);
    }
  }, [editor]);

  return (
    <div style={{ position: "fixed", inset: 0 }}>
      <Tldraw inferDarkMode onMount={setEditor} />
    </div>
  );
}

export default App;
