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
        await addAsset(editor, props);
        return {};
      },
      zoomToFit: async ({ inset, animate }) => {
        await loggedPromise<void>("zoomToFit", async (resolve) => {
          const bounds = getPageBounds(editor);
          if (!bounds) {
            return resolve();
          }

          const duration = 100;
          editor.zoomToBounds(bounds, {
            inset: inset ? bridge.getGutterSize() : 0,
            animation: animate ? { duration } : undefined,
          });

          if (animate) {
            const animationCancelled = new Promise<void>((resolve) =>
              editor.once("stop-camera-animation", resolve)
            );
            const timeout = new Promise<void>((resolve) =>
              setTimeout(resolve, duration)
            );
            await Promise.race([animationCancelled, timeout]);
          }
          resolve();
        });
        return {};
      },
      waitForResize: async ({ timeoutMs }) => {
        const timeout = waitMs(timeoutMs).then(() => "timeout");
        const didResize = new Promise((resolve) =>
          window.addEventListener("resize", () => resolve("resize"), {
            once: true,
          })
        );
        console.log("waitForResize:", await Promise.race([timeout, didResize]));
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

function addAsset(
  editor: Editor,
  initialAsset: BridgeImageAssetProps
): Promise<void> {
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

  editor.eventNames;

  return loggedPromise<void>("addAssetImageLoad", async (resolve) => {
    await wait(editor);
    const images = Array.from(document.querySelectorAll("img.tl-image"));
    const notLoadedImages = images.filter(
      (img) => img instanceof HTMLImageElement && !img.complete
    ) as HTMLImageElement[];
    const promises = notLoadedImages.map(
      (img) =>
        new Promise<void>((resolve) => {
          const resolveWrapper = () => {
            console.log("img loaded", img);
            resolve();
          };
          img.addEventListener("load", resolveWrapper, {
            once: true,
            passive: true,
          });
          img.addEventListener("error", resolveWrapper, {
            once: true,
            passive: true,
          });
        })
    );
    if (promises.length === 0) {
      console.log("no images to wait for");
      resolve();
    } else {
      console.log(`waiting for ${promises.length} images to load`);
    }
    Promise.all(promises).finally(resolve);
  });
}

function getPageBounds(editor: Editor) {
  const ids = [...editor.getCurrentPageShapeIds()];
  if (ids.length <= 0) return;
  return Box.Common(compact(ids.map((id) => editor.getShapePageBounds(id))));
}

function compact<T>(array: (T | null | undefined)[]): T[] {
  return array.filter((x) => x !== null && x !== undefined) as T[];
}

function loggedPromise<T>(
  name: string,
  resolver: (resolve: (arg: T) => void, reject: (error: Error) => void) => void
) {
  const log = (...msg: unknown[]) => {
    console.log(`promise ${name}:`, ...msg);
  };
  console.time(name);
  log("started");
  return new Promise<T>((resolve, reject) => {
    const startAt = Date.now();

    const interval = setInterval(() => {
      log(`  still running after ${Date.now() - startAt}ms`);
    }, 10_000);

    const wrappedResolve = (arg: T) => {
      clearInterval(interval);
      console.timeEnd(name);
      log("  resolved", arg);
      resolve(arg);
    };

    const wrappedReject = (error: Error) => {
      clearInterval(interval);
      console.timeEnd(name);
      log("  rejected", error);
      reject(error);
    };

    resolver(wrappedResolve, wrappedReject);
  });
}

function wait(editor: Editor) {
  return new Promise<void>((resolve) => setTimeout(resolve, 0));
}

function waitMs(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}
