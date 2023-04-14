import {
  EditorRecord,
  getDefaultFilePath,
} from "@/shared/records/EditorRecord";
import { App, createShapesFromFiles } from "@tldraw/editor";
import { TLShot } from "../TLShotRendererApp";
import { RecordAttachmentMap } from "@/shared/EphemeralMap";
import { DisplayId } from "@/main/WindowDisplayService";
import { DisplayRecordId } from "@/shared/records/DisplayRecord";
import { Rectangle, Size } from "electron";

// function loadImageFromDataURL(dataUrl: string): Promise<Image> {
//   return new Promise((resolve, reject) => {
//     const image = new Image();
//     image.onload = () => resolve(image);
//     image.onerror = reject;
//     image.src = dataUrl;
//   });
// }

interface BlobRect {
  blob: Blob;
  rect: Size & Partial<Rectangle>;
}

function cropImageToBlob(
  imageOrVideo: Exclude<CanvasImageSource, SVGImageElement>,
  rect: DOMRect | undefined
): Promise<BlobRect> {
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Could not get canvas context");
  }

  if (!rect) {
    rect = new DOMRect(0, 0, imageOrVideo.width, imageOrVideo.height);
  }

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

  const finalRect = rect;
  return debugPromise(
    new Promise<BlobRect>((resolve, reject) =>
      canvas.toBlob((blob) => {
        if (!blob) {
          reject(new Error("Could not get blob from canvas"));
        } else {
          resolve({
            blob,
            rect: finalRect,
          });
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

const NEW_EDITOR_CAPTURES = new RecordAttachmentMap<EditorRecord, Blob>(
  TLShot.store
);

export function startEditorForCapture(
  capture: BlobRect,
  displayId: DisplayId | DisplayRecordId
) {
  const preferences = TLShot.queries.preferences.value;
  const now = Date.now();
  const editor = EditorRecord.create({
    hidden: true,
    createdAt: now,
    filePath: preferences && getDefaultFilePath(preferences, now),
    targetBounds: {
      x: capture.rect.x,
      y: capture.rect.y,
      width: capture.rect.width,
      height: capture.rect.height,
    },
    targetDisplay: DisplayRecordId.fromDisplayId(displayId),
  });
  NEW_EDITOR_CAPTURES.map.set(editor.id, capture.blob);
  TLShot.store.put([editor]);
}

export async function completeEditorForCapture(editor: EditorRecord, app: App) {
  const capture = NEW_EDITOR_CAPTURES.map.get(editor.id);
  if (capture) {
    NEW_EDITOR_CAPTURES.map.delete(editor.id);
    await createShapeFromBlob(app, capture);
    const updatedRecord = {
      ...editor,
      hidden: false,
    };
    TLShot.store.put([updatedRecord]);
  }
}

// TODO: actually do all displays, currently only does the main display.
export async function captureFullScreen() {
  const display = await TLShot.api.getCurrentDisplay();
  const source = await TLShot.api.getDisplaySource(display.id);
  const blob = await captureUserMediaSource(source.id, undefined);
  startEditorForCapture(blob, display.id);
}
