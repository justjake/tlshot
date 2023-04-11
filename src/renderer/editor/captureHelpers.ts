import { App, createShapesFromFiles } from "@tldraw/editor";

// function loadImageFromDataURL(dataUrl: string): Promise<Image> {
//   return new Promise((resolve, reject) => {
//     const image = new Image();
//     image.onload = () => resolve(image);
//     image.onerror = reject;
//     image.src = dataUrl;
//   });
// }

function cropImageToBlob(
  imageOrVideo: Exclude<CanvasImageSource, SVGImageElement>,
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
      imageOrVideo,
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
    canvas.width = imageOrVideo.width;
    canvas.height = imageOrVideo.height;
    ctx.drawImage(imageOrVideo, 0, 0, imageOrVideo.width, imageOrVideo.height);
  }

  return debugPromise(
    new Promise<Blob>((resolve, reject) =>
      canvas.toBlob((blob) => {
        if (!blob) {
          reject(new Error("Could not get blob from canvas"));
        } else {
          resolve(blob);
        }
        canvas.remove();
      }, "image/png")
    )
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
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    video: electronParameters as any,
  });

  const video = document.createElement("video");
  video.style.cssText = "position:absolute;top:-10000px;left:-10000px;";
  document.body.appendChild(video);
  await debugPromise(
    new Promise((resolve, reject) => {
      video.onloadedmetadata = resolve;
      video.onerror = reject;
      video.srcObject = stream;
    })
  );

  video.width = video.videoWidth;
  video.height = video.videoHeight;
  void video.play();

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
  return createShapesFromFiles(
    app,
    [Object.assign(blob as any, { name: "capture.png" }) as File],
    app.viewportPageBounds.center,
    false
  );
}

const TIMEOUT = Symbol("Timeout reached");

async function debugPromise<T>(promise: Promise<T>): Promise<T> {
  return promise;
  // const timeout = new Promise((resolve) => setTimeout(resolve, 500)).then(
  //   () => TIMEOUT
  // );

  // try {
  //   const result = await Promise.race([promise, timeout]);
  //   if (result === TIMEOUT) {
  //     throw new Error("Promise timed out");
  //   }
  //   console.log("Promise resolved", result);
  //   return result as any;
  // } catch (e) {
  //   console.log("Promise error", e);
  //   throw e;
  // }
}
