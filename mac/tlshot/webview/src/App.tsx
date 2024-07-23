import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  AssetRecordType,
  Editor,
  PngHelpers,
  TLComponents,
  TLDefaultShape,
  TLImageAsset,
  TLShapeId,
  TLShapePartial,
  Tldraw,
  createShapeId,
  exportToBlob,
  getHashForString,
  getSvgAsImage,
  useEditor,
} from "tldraw";
import { bridge, BridgeIncomingHandlers } from "./Bridge";

async function replaceAssetUrlsWithDataUrls(editor: Editor, svgString: string) {
  const imagesToReplace = editor
    .getCurrentPageShapes()
    .map(async (unknownShape) => {
      const shape = unknownShape as TLDefaultShape;
      if (shape.type !== "image") return;
      console.log("props", shape.props);
      const asset = editor.getAsset(shape.props.assetId!);
      const blob = await fetch(asset?.props.src!).then((res) => res.blob());
      const dataUrl = await new Promise<string>((resolve, reject) => {
        var a = new FileReader();
        a.onload = function (e) {
          const result = e.target?.result;
          if (typeof result !== "string") {
            const error = new Error(
              `Expected FileReader.result to be a string, instead: ${typeof result}`
            );
            return reject(error);
          }
          return resolve(result);
        };
        a.onerror = (e) => {
          reject(e.target?.error ?? new Error("Unknown FileReader error"));
        };
        a.readAsDataURL(blob);
      });

      return [asset?.props.src!, dataUrl];
    });

  const pairs = (await Promise.all(imagesToReplace)).filter(Boolean) as [
    string,
    string,
  ][];

  let result = svgString;
  for (const [url, blobUrl] of pairs) {
    result = result.replace(url, blobUrl);
  }
  return result;
}

async function getCurrentPageSvg(editor: Editor) {
  const result = await editor.getSvgString(
    Array.from(editor.getCurrentPageShapeIds()),
    {
      scale: 2,
    }
  );
  if (!result) {
    throw new Error(`Failed to get SVG string`);
  }
  result.svg = await replaceAssetUrlsWithDataUrls(editor, result.svg);
  return result;
}

function TopPanel() {
  const editor = useEditor();
  const imageContainerRef = useRef<HTMLDivElement>(null);
  const makeSvg = async () => {
    console.log("Making SVG");
    const svg = await getCurrentPageSvg(editor);
    const canvas = await getSvgAsCanvas(editor, svg.svg, {
      height: svg.height,
      width: svg.width,
      quality: 100,
      scale: 1,
      type: "png",
    });
    // if (!element) throw new Error("Failed to get canvas");
    const blob = await canvasToBlob({
      ...canvas,
      quality: 100,
      type: "png",
    });
    if (!blob) {
      throw new Error("sdafsdfa blobber");
    }
    const url = URL.createObjectURL(blob);
    // window.location.href = assetUrl;
    const element = new Image();
    element.crossOrigin = "anonymous";
    element.src = url;
    element.onload = () => {
      URL.revokeObjectURL(url);
    };

    element.style.maxWidth = "100%";
    element.style.backgroundColor = "purple";
    imageContainerRef.current!.appendChild(element);
  };

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
      <button onClick={makeSvg}>Make SVG</button>
      <button onClick={save}>Save</button>
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
        const svg = await getCurrentPageSvg(editor);
        const canvas = await getSvgAsCanvas(editor, svg.svg, {
          height: svg.height,
          width: svg.width,
          quality: 100,
          scale: 1,
          type: "png",
        });
        if (!canvas) {
          throw new Error("Failed to get image");
        }

        const image = await canvasToBlob({
          ...canvas,
          quality: 100,
          type: "png",
        });

        if (!image) {
          throw new Error("dafdsf");
        }

        const arrayBuffer = await image.arrayBuffer();
        console.log("image byte length:", arrayBuffer.byteLength);
        return {
          ...svg,
          svg: "(its not used right)",
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
        options={{
          defaultSvgPadding: 0,
        }}
      ></Tldraw>
    </div>
  );
}

/** @public */
export async function getSvgAsCanvas(
  editor: Editor,
  svgString: string,
  options: {
    type: "png" | "jpeg" | "webp";
    quality: number;
    scale: number;
    width: number;
    height: number;
  }
) {
  const { type, quality, scale, width, height } = options;

  const clampedWidth = Math.floor(scale * width);
  const clampedHeight = Math.floor(scale * height);
  const effectiveScale = clampedWidth / width;

  const svgUrl = URL.createObjectURL(
    new Blob([svgString], { type: "image/svg+xml" })
  );

  const canvas = await new Promise<HTMLCanvasElement | null>((resolve) => {
    const image = new Image();
    image.crossOrigin = "anonymous";

    image.onload = async () => {
      // safari will fire `onLoad` before the fonts in the SVG are
      // actually loaded. just waiting around a while is brittle, but
      // there doesn't seem to be any better solution for now :( see
      // https://bugs.webkit.org/show_bug.cgi?id=219770
      if (editor.environment.isSafari) {
        console.log("isSafari");
        await new Promise((resolve) => editor.timers.setTimeout(resolve, 250));
      }

      const canvas = document.createElement("canvas") as HTMLCanvasElement;
      const ctx = canvas.getContext("2d")!;

      canvas.width = clampedWidth;
      canvas.height = clampedHeight;

      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = "high";
      ctx.drawImage(image, 0, 0, clampedWidth, clampedHeight);

      URL.revokeObjectURL(svgUrl);

      resolve(canvas);
    };

    image.onerror = () => {
      resolve(null);
    };

    image.src = svgUrl;
  });
  return { canvas, effectiveScale };
}

async function canvasToBlob(args: {
  canvas: HTMLCanvasElement | null;
  effectiveScale: number;
  type: "png" | "jpeg" | "webp";
  quality: number;
}) {
  const { canvas, effectiveScale, type, quality } = args;
  if (!canvas) return null;
  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          resolve(null);
        }
        resolve(blob);
      },
      "image/" + type,
      quality
    )
  );

  if (!blob) return null;

  if (type === "png") {
    const view = new DataView(await blob.arrayBuffer());
    return PngHelpers.setPhysChunk(view, effectiveScale, {
      type: "image/" + type,
    });
  } else {
    return blob;
  }
}

export default App;
