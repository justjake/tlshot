import {
  EditorRecord,
  getDefaultFilePath,
} from "@/shared/records/EditorRecord";
import { App, createShapesFromFiles } from "@tldraw/editor";
import { TLShot } from "../TLShotRendererApp";
import { RecordAttachmentMap } from "@/shared/EphemeralMap";
import { DisplayId } from "@/main/WindowDisplayService";
import { DisplayRecord, DisplayRecordId } from "@/shared/records/DisplayRecord";
import { Rectangle, Size } from "electron";
import {
  createScreenshotID,
  createScreenshotRequestURL,
} from "@/shared/screenshotProtocol";

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

export async function cropImageToBlob(
  imageOrVideo: Exclude<CanvasImageSource, SVGImageElement>,
  rect: DOMRect | undefined
): Promise<BlobRect> {
  if (!rect) {
    rect = new DOMRect(0, 0, imageOrVideo.width, imageOrVideo.height);
  }

  const canvas = new OffscreenCanvas(rect.width, rect.height);
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Could not get canvas context");
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

  const blob = await debugPromise(
    "canvas.convertToBlob",
    canvas.convertToBlob({
      type: "image/png",
    })
  );
  return {
    blob,
    rect,
  };
}

interface UserAgentData {
  platform: "macOS" | string;
}

export async function captureDisplay(
  display: DisplayRecord,
  rect: DOMRect | undefined
) {
  const userAgentData = (
    window.navigator as unknown as { userAgentData: UserAgentData }
  ).userAgentData;
  if (userAgentData.platform === "macOS") {
    // Use precise but slower method.
    const scaledRect =
      rect &&
      new DOMRect(
        rect.x * display.scaleFactor,
        rect.y * display.scaleFactor,
        rect.width * display.scaleFactor,
        rect.height * display.scaleFactor
      );
    const { blob, rect: rescaledRect } =
      await captureDisplayViaScreenshotProtocol(display.displayId, scaledRect);
    return {
      blob,
      rect: rect
        ? rect
        : new DOMRect(
            (rescaledRect.x || 0) / display.scaleFactor,
            (rescaledRect.y || 0) / display.scaleFactor,
            rescaledRect.width / display.scaleFactor,
            rescaledRect.height / display.scaleFactor
          ),
    };
  } else {
    // Fall back to Chrome userMedia API
    const displaySource = await TLShot.api.getDisplaySource(display.displayId);
    return captureUserMediaSource(displaySource.id, rect);
  }
}

/**
 * Only implemented for macOS
 */
export async function captureDisplayViaScreenshotProtocol(
  displayId: DisplayId,
  rect: DOMRect | undefined
) {
  const url = createScreenshotRequestURL({
    displayId: displayId,
    rect: rect,
    id: createScreenshotID(),
  });
  const img = await debugPromise(
    "img.onload",
    new Promise<HTMLImageElement>((resolve, reject) => {
      const img = new Image();
      img.src = String(url);
      img.onabort = reject;
      img.onerror = reject;
      img.onload = () => {
        resolve(img);
      };
    })
  );
  return cropImageToBlob(img, rect);
  /*
  const imgPath = await TLShot.api.nativeCaptureDisplayToFile({
    displays: [{
      _name: 'dummy',
      _spdisplays_displayID: "0"
    }],
    _spdisplays_displayID: "0"
  })
  const bufferBlob = await TLShot.api.readImage(imgPath)
  const bufferURL = URL.createObjectURL(bufferBlob);
  const img = await new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.src = bufferURL
    img.onabort = reject;
    img.onerror = reject;
    img.onload = () => {
      resolve(img);
    };
  });
  const result = await cropImageToBlob(img, rect);
  URL.revokeObjectURL(bufferURL)
  return result
  */
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
    "video.onloadedmetadata",
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

export async function debugPromise<T>(
  name: string,
  promise: Promise<T>
): Promise<T> {
  // return promise;
  const ds = Date.now();
  const timeout = new Promise((resolve) => setTimeout(resolve, 5000)).then(
    () => TIMEOUT
  );

  try {
    const result = await Promise.race([promise, timeout]);
    const after = Date.now() - ds;
    if (result === TIMEOUT) {
      throw new Error(`Promise timed out: ${name} after ${after}`);
    }
    console.log(`Promise resolved after ${after}: ${name}`, result);
    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return result as any;
  } catch (e) {
    const after = Date.now() - ds;
    console.log(`Promise error after ${after}: ${name}`, e);
    throw e;
  }
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
    app.zoomToFit();
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
  const displayRecord = TLShot.store.get(
    DisplayRecordId.fromDisplayId(display.id)
  );
  if (!displayRecord) {
    throw new Error(`DisplayRecord not found: ${display.id}`);
  }
  const blob = await captureDisplay(displayRecord, undefined);
  startEditorForCapture(blob, display.id);
}
