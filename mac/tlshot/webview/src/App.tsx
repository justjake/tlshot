import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  AssetRecordType,
  Editor,
  TLComponents,
  TLDefaultShape,
  TLImageAsset,
  TLShapePartial,
  Tldraw,
  createShapeId,
  exportToBlob,
  getHashForString,
  getSvgAsImage,
  useEditor,
} from "tldraw";
import { bridge, BridgeIncomingHandlers } from "./Bridge";

async function makeSvgUrl(editor: Editor) {
  const svg = await editor.getSvgString(
    Array.from(editor.getPageShapeIds(editor.getCurrentPageId())),
    {
      scale: 2,
    }
  );
  if (!svg) throw new Error("Failed to get SVG string");

  const imagesToReplace = editor
    .getCurrentPageShapes()
    .map(async (unknownShape) => {
      const shape = unknownShape as TLDefaultShape;
      if (shape.type !== "image") return;
      console.log("props", shape.props);
      const asset = editor.getAsset(shape.props.assetId!);
      const blob = await fetch(asset?.props.src!).then((res) => res.blob());
      const dataUrl = await new Promise<string>((callback) => {
        var a = new FileReader();
        a.onload = function (e) {
          callback(e.target.result as string);
        };
        a.readAsDataURL(blob);
      });

      // TODO: release blob url
      return [asset?.props.src!, dataUrl];
    });

  const pairs = (await Promise.all(imagesToReplace)).filter(Boolean) as [
    string,
    string,
  ][];

  console.log("pairs", pairs);

  let svgText = svg.svg;
  for (const [url, blobUrl] of pairs) {
    svgText = svgText.replace(url, blobUrl);
  }

  console.log("svgText", svgText);
  const blobber = new Blob([svgText], { type: "image/svg+xml" });

  return { info: svg, assetUrl: URL.createObjectURL(blobber) };
}

function TopPanel() {
  const editor = useEditor();
  const imageContainerRef = useRef<HTMLDivElement>(null);
  const makeSvg = async () => {
    console.log("Making SVG");
    const { assetUrl } = await makeSvgUrl(editor);
    // window.location.href = assetUrl;
    const image = new Image();
    image.crossOrigin = "anonymous";
    image.style.maxWidth = "100%";
    image.style.backgroundColor = "purple";
    image.src = assetUrl;
    imageContainerRef.current!.appendChild(image);
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
      <button onClick={makeSvg}>Make SVG</button>
      <div
        ref={imageContainerRef}
        style={{ background: "red", border: "1px solid red" }}
      />
      ;
    </div>
  );
}

const components: TLComponents = {
  TopPanel,
};

function App() {
  const [editor, setEditor] = useState<Editor | null>(null);

  const registerApi = useMemo<BridgeIncomingHandlers | undefined>(() => {
    if (!editor) return;

    return {
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
    };
  }, [editor]);

  useEffect(() => {
    if (!editor) return;
    if (!registerApi) return;
    (globalThis as any).__tldraw__ = editor;
    bridge.register(registerApi);
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
      <Tldraw
        inferDarkMode
        onMount={setEditor}
        components={components}
      ></Tldraw>
    </div>
  );
}

export default App;
