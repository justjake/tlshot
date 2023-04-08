import { App, createShapesFromFiles } from "@tldraw/editor";

function loadImageFromDataURL(dataUrl: string): Promise<Image> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = dataUrl;
  });
}

function cropImageToBlob(
  imageSource: Exclude<CanvasImageSource, SVGImageElement>,
  rect: DOMRect | undefined
): Promise<Blob> {
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Could not get canvas context");
  }

  if (rect) {
    canvas.width = rect.width;
    canvas.height = rect.height;
    ctx.drawImage(
      imageSource,
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      0,
      0,
      rect.width,
      rect.height
    );
  } else {
    canvas.width = imageSource.width;
    canvas.height = imageSource.height;
    ctx.drawImage(imageSource, 0, 0);
  }

  return new Promise<Blob>((resolve) =>
    canvas.toBlob((blob) => {
      if (!blob) {
        throw new Error("Could not get blob from canvas");
      }
      resolve(blob);
      canvas.remove();
    }, "image/png")
  );
}

export async function captureUserMediaSource(
  sourceId: string,
  rect: DOMRect | undefined
) {
  const electronParameters = {
    mandatory: {
      chromeMediaSource: "desktop",
      chromeMediaSourceId: sourceId,
      minWidth: 1280,
      maxWidth: 4000,
      minHeight: 720,
      maxHeight: 4000,
    },
  };

  const stream = await navigator.mediaDevices.getUserMedia({
    audio: false,
    video: electronParameters as any,
  });

  const video = document.createElement("video");
  video.style.cssText = "position:absolute;top:-10000px;left:-10000px;";
  document.appendChild(video);
  await new Promise((resolve, reject) => {
    video.onloadedmetadata = resolve;
    video.onerror = reject;
  });

  video.style.width = video.videoWidth + "px";
  video.style.height = video.videoHeight + "px";
  video.play();

  const blob = await cropImageToBlob(video, rect);

  // Clean up.
  video.srcObject = null;
  video.remove();
  try {
    // Destroy stream
    stream.getTracks()[0].stop();
  } catch (e) {
    console.warn("Error removing stream track: ", e);
  }

  return blob;
}

export function createShapeFromBlob(app: App, blob: Blob) {
  createShapesFromFiles(
    app,
    [Object.assign(blob as any, { name: "capture.png" })],
    app.viewportPageBounds.center,
    false
  );
}
