import { Editor, PngHelpers, TLDefaultShape } from "tldraw";

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
      scale: 1,
    }
  );
  if (!result) {
    throw new Error(`Failed to get SVG string`);
  }
  result.svg = await replaceAssetUrlsWithDataUrls(editor, result.svg);
  return result;
}

/** @public */
async function getSvgAsCanvas(
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

export async function exportPng(editor: Editor) {
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
    throw new Error("Failed to convert canvas to blob");
  }
  return image;
}
