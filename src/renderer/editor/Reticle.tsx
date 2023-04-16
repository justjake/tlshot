import React, {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { useStyles } from "./useStyles";
import { Windows, useGetWindow } from "./ChildWindow";
import { TLShot } from "../TLShotRendererApp";
import { Computed, Signal, atom, computed, react } from "signia";
import { useComputed, useValue } from "signia-react";
import { Box2d, Vec2d } from "@tldraw/primitives";
import { Vec2dModel } from "@tldraw/editor";
import { DisplayRecord } from "@/shared/records/DisplayRecord";
import {
  createScreenshotID,
  createScreenshotRequestURL,
} from "@/shared/screenshotProtocol";
import { ChildWindowNanoid } from "@/main/WindowDisplayService";
import { waitUntil } from "@/shared/signiaHelpers";
import { debugPromise } from "./captureHelpers";

export class ReticleState {
  readonly windowId = atom("reticle.windowId", Windows.ROOT_WINDOW);

  readonly origin = atom<{ x: number; y: number } | undefined>(
    "reticle.origin",
    undefined
  );

  readonly mouse = atom<{ x: number; y: number }>("reticle.mouse", {
    x: -1,
    y: -1,
  });

  readonly rect = computed("reticle.rect", () => {
    const origin = this.origin.value;
    if (!origin) {
      return undefined;
    }
    const mouse = this.mouse.value;
    return Box2d.FromPoints([origin, mouse]);
  });

  readonly isDragging = computed("reticle.isDragging", () => {
    return this.origin.value !== undefined;
  });

  readonly legendText = computed("reticle.legendText", () => {
    const rect = this.rect.value;
    const mouse = this.mouse.value;
    const { x, y } = rect ? { x: rect.width, y: rect.height } : mouse;
    return `${String(x).padStart(4)} x ${String(y).padEnd(4)}`;
  });

  isInWindow(windowId: ChildWindowNanoid) {
    return this.windowId.value === windowId && this.mouse.value.x !== -1;
  }
}

export function Reticle(props: {
  state: ReticleState;
  onSelect: (rect: DOMRect) => void;
  onClose: () => void;
  display: DisplayRecord;
}) {
  const { onSelect, onClose, display, state } = props;
  const getWindow = useGetWindow();
  const rootRef = useRef<HTMLDivElement>(null);

  const styles = useStyles(
    () => ({
      root: {
        width: "100%",
        height: "100%",
        position: "relative",
      },
    }),
    []
  );

  // On first mount, try to get mouse position before mouse moves.
  useEffect(() => {
    void (async () => {
      const pos = await TLShot.api.getMousePosition();
      const ownWindow = await waitUntil("hasOwnWindow", () =>
        TLShot.store.query
          .exec("window", {
            childWindowId: {
              eq: getWindow.childWindowNanoid,
            },
          })
          .at(0)
      );

      if (
        !pos.windowPoint ||
        !ownWindow?.childWindowId ||
        pos.closestWindowId !== ownWindow.browserWindowId
      ) {
        console.log("Mouse not over own window", ownWindow, pos);
        return;
      }

      if (state.isInWindow(ownWindow.childWindowId)) {
        console.log("already has position", state.mouse.value);
      }

      console.log("set position from main process", ownWindow, pos);
      state.mouse.set(pos.windowPoint);
      state.windowId.set(ownWindow.childWindowId);
    })();
  }, [state, getWindow]);

  // Grab focus when the mouse enters the window
  const isInWindow = useValue(
    useComputed(
      "isInWindow",
      () => state.isInWindow(getWindow.childWindowNanoid),
      [getWindow]
    )
  );
  useLayoutEffect(() => {
    if (isInWindow) {
      // void TLShot.api.focusTopWindowNearMouse();
    }
  }, [isInWindow]);

  useEffect(() => {
    function handleMouseDown(e: MouseEvent) {
      state.origin.set({
        x: e.clientX,
        y: e.clientY,
      });
    }

    function handleMouseMove(e: MouseEvent) {
      state.windowId.set(getWindow.childWindowNanoid);
      state.mouse.set({
        x: e.clientX,
        y: e.clientY,
      });
    }

    function handleMouseUp() {
      const rect = state.rect.value;

      // TODO: should we unset origin?
      // We don't really need to - because we're going to close anyways

      if (!rect) {
        return;
      }

      // Close the window immediately so we aren't included in the capture
      if (rootRef.current) {
        rootRef.current.style.display = "none";
      }

      onClose();
      requestAnimationFrame(() => {
        if (rect.w === 0 || rect.h === 0) return;
        onSelect(new DOMRect(rect.x, rect.y, rect.width, rect.height));
      });
    }

    getWindow().addEventListener("mousedown", handleMouseDown);
    getWindow().addEventListener("mousemove", handleMouseMove);
    getWindow().addEventListener("mouseup", handleMouseUp);
    return () => {
      getWindow().removeEventListener("mousedown", handleMouseDown);
      getWindow().removeEventListener("mousemove", handleMouseMove);
      getWindow().removeEventListener("mouseup", handleMouseUp);
    };
  }, [getWindow, state, onClose, onSelect]);

  return (
    <div ref={rootRef} style={styles.root}>
      <ReticleMouse
        state={state}
        loupeSize={200}
        loupePixelSize={15}
        loupeOffset={16}
        display={display}
      />
    </div>
  );
}

const TOTAL_HAIR_WIDTH = 3;
const HAIR_LIGHT = "rgba(220, 220, 220, 0.4)";
const HAIR_LIGHT_STROKE_SHADOW = `0px 0px 0px 1px ${HAIR_LIGHT}`;
const HAIR_DARK = "rgba(0, 0, 0, 0.4)";

/**
 * Draws the mouse followers for the reticle:
 * - The crosshairs.
 * - The loupe, offset from the mouse and contained inside the window
 */
function ReticleMouse(props: {
  state: ReticleState;
  loupePixelSize: number;
  loupeSize: number;
  loupeOffset: number;
  display: DisplayRecord;
}) {
  const { state, loupeSize, loupePixelSize, loupeOffset } = props;

  const getWindow = useGetWindow();
  const bgRef = useRef<HTMLDivElement>(null);
  const hRef = useRef<HTMLDivElement>(null);
  const vRef = useRef<HTMLDivElement>(null);
  const loupeRef = useRef<HTMLDivElement>(null);

  const isDragging = useValue(state.isDragging);
  const styles = useStyles(
    () => ({
      v: {
        boxShadow: HAIR_LIGHT_STROKE_SHADOW,
        background: HAIR_DARK,
        position: "absolute",
        width: 1,
        height: "100%",
        top: 0,
        left: TOTAL_HAIR_WIDTH / -2,
      },
      h: {
        boxShadow: HAIR_LIGHT_STROKE_SHADOW,
        background: HAIR_DARK,
        position: "absolute",
        width: "100%",
        height: 1,
        top: TOTAL_HAIR_WIDTH / -2,
        left: 0,
      },
      loupe: {
        position: "absolute",
        width: loupeSize,
        height: loupeSize,
        top: 0,
        left: 0,
        boxShadow: `0px 0px 0px 1px ${HAIR_LIGHT}, 0px 0px 0px 2px ${HAIR_DARK}`,
        overflow: "clip",
        borderRadius: 3,
      },
      bg: {
        background: isDragging
          ? "rgba(0, 0, 0, 0.3)"
          : "rgba(100, 100, 100, 0.2)",
        position: "absolute",
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
      },
    }),
    [isDragging, loupeSize]
  );

  useLayoutEffect(
    () =>
      react("updateMouse", () => {
        const { x, y } = state.mouse.value;
        const v = vRef.current;
        const h = hRef.current;
        const loupe = loupeRef.current;
        const bg = bgRef.current;
        if (!v || !h || !bg) {
          return;
        }

        const isInWindow = state.isInWindow(getWindow.childWindowNanoid);

        // Update the clipping mask of the background
        const selection = state.rect.value;
        if (selection && isInWindow) {
          const container = {
            top_left: "0% 0%",
            bottom_left: "0% 100%",
            top_right: "100% 0%",
            bottom_right: "100% 100%",
          };
          const px = (point: Vec2dModel) => `${point.x}px ${point.y}px`;
          const polygon = [
            container.top_left,
            container.bottom_left,
            `${selection.x}px 100%`,
            px(selection.getHandlePoint("top_left")),
            px(selection.getHandlePoint("top_right")),
            px(selection.getHandlePoint("bottom_right")),
            px(selection.getHandlePoint("bottom_left")),
            `${selection.x}px 100%`,
            container.bottom_right,
            container.top_right,
          ];
          bg.style.clipPath = `polygon(${polygon.join(", ")})`;
        } else {
          bg.style.clipPath = "none";
        }

        // Hide other features if the mouse is missing
        const visibleWhenInWindow = [v, h, loupe];
        for (const el of visibleWhenInWindow) {
          if (el) {
            el.style.visibility = isInWindow ? "visible" : "hidden";
          }
        }

        // Updating the crosshair is easy.
        v.style.transform = `translateX(${x}px)`;
        h.style.transform = `translateY(${y}px)`;

        // We try to place the loupe without it going off the screen or
        // intersecting the current box selection
        const loupeBoundingBox = Box2d.From({
          x,
          y,
          w: loupeSize + 2 * loupeOffset,
          h: loupeSize + 2 * loupeOffset,
        });

        const candidates = [
          loupeBoundingBox,
          loupeBoundingBox.clone().translate({ x: -loupeBoundingBox.w, y: 0 }),
          loupeBoundingBox
            .clone()
            .translate({ x: -loupeBoundingBox.w, y: -loupeBoundingBox.h }),
          loupeBoundingBox.clone().translate({ x: 0, y: -loupeBoundingBox.h }),
        ];

        const windowBox = Box2d.From({
          x: 0,
          y: 0,
          w: getWindow().innerWidth,
          h: getWindow().innerHeight,
        });
        const insideWindow = candidates.filter((c) => windowBox.contains(c));
        const notIntersectingSelection = (
          insideWindow.length > 0 ? insideWindow : candidates
        ).filter((c) => (selection ? !selection.includes(c) : true));

        const placement =
          notIntersectingSelection[0] ?? insideWindow[0] ?? loupeBoundingBox;
        const loupePos = Vec2d.Add(placement, {
          x: loupeOffset,
          y: loupeOffset,
        });
        if (loupe) {
          loupe.style.transform = `translate(${loupePos.x}px, ${loupePos.y}px)`;
        }
      }),
    [loupeSize, loupeOffset, state, getWindow]
  );

  const loupeSrc = useDisplayImageBitmap(props.display);

  return (
    <>
      <div style={styles.bg} ref={bgRef} />
      <div style={styles.h} ref={hRef} />
      <div style={styles.v} ref={vRef} />
      {loupeSrc && (
        <div style={styles.loupe} ref={loupeRef}>
          <Loupe
            state={state}
            src={loupeSrc}
            loupeWidth={loupePixelSize}
            loupeHeight={loupePixelSize}
            viewportWidth={loupeSize}
            viewportHeight={loupeSize}
            legendText={state.legendText}
          />
        </div>
      )}
    </>
  );
}

function Loupe(props: {
  state: ReticleState;
  src: ImageBitmap;

  // Pixels of the source image
  loupeWidth: number;
  loupeHeight: number;

  // Size of the loupe on screen
  viewportWidth: number;
  viewportHeight: number;

  legendText: Signal<string>;
}) {
  const { state, src, loupeWidth, loupeHeight, viewportWidth, viewportHeight } =
    props;

  const loupeCenter = state.mouse;

  const getWindow = useGetWindow();

  const [canvas, setCanvas] = useState<HTMLCanvasElement | null>(null);

  const textureCamera = useComputed(
    "loupeCamera",
    () => {
      // prescaleFactor:
      // the incoming coordinate is in Web points, but our texture is in raw display pixels.
      // prescale factor is the scaling factor between the two.
      //
      // We could just use window.devicePixelRatio, but computing the scaling
      // allows our source image to be downsampled in the future without breaking.
      const prescaleX = src.width / getWindow().innerWidth;
      const precaleY = src.height / getWindow().innerHeight;
      const prescaleFactor = Math.max(prescaleX, precaleY);

      const dw = viewportWidth / (loupeWidth * prescaleFactor); // TODO: why multiply by prescale factor?
      const dh = viewportHeight / (loupeHeight * prescaleFactor);
      const screenPixelZoomFactor = Math.max(dw, dh);
      const loupeZoomFactor = screenPixelZoomFactor / prescaleFactor;

      const cameraCenter = Vec2d.From(loupeCenter.value)
        .addScalar(0.5)
        .mul(prescaleFactor);

      const cameraCornerOffset = Vec2d.From({
        x: loupeWidth * loupeZoomFactor,
        y: loupeHeight * loupeZoomFactor,
      }).div(2);

      const camera = Box2d.FromPoints([
        cameraCenter.clone().sub(cameraCornerOffset),
        cameraCenter.clone().add(cameraCornerOffset),
      ]);

      return {
        camera,
        // TODO: wtf?
        zoomFactor: screenPixelZoomFactor,
      };
    },
    [
      src,
      loupeCenter,
      getWindow,
      loupeWidth,
      loupeHeight,
      viewportWidth,
      viewportHeight,
    ]
  );

  useLayoutEffect(
    () =>
      react("canvasLoupe", () => {
        if (!state.isInWindow(getWindow.childWindowNanoid)) {
          return;
        }
        const camera = textureCamera.value.camera;

        const context = canvas?.getContext("2d", {
          // Google claims this improves performance or something.
          // https://developer.chrome.com/blog/desynchronized/
          desynchronized: true,
        });

        if (!context) {
          console.warn("No context for loupe", canvas);
          return;
        }

        context.imageSmoothingEnabled = false;
        context.clearRect(0, 0, viewportWidth, viewportHeight);
        context.drawImage(
          src,
          camera.x,
          camera.y,
          camera.w,
          camera.h,
          0,
          0,
          viewportWidth,
          viewportHeight
        );
      }),

    [
      src,
      canvas,
      getWindow,
      loupeCenter,
      loupeWidth,
      loupeHeight,
      viewportWidth,
      viewportHeight,
      state,
      textureCamera.value,
    ]
  );

  const textureCameraCenter = useComputed(
    "textureCameraCenter",
    () => textureCamera.value.camera.center,
    [textureCamera]
  );
  const color = useColorAtPoint(src, textureCameraCenter, "#000000");

  const scalingFactor = useValue(
    useComputed("scaleFactor", () => textureCamera.value.zoomFactor, [
      textureCamera,
    ])
  );

  const styles = useStyles(() => {
    return {
      viewport: {
        width: viewportWidth,
        height: viewportHeight,
        overflow: "",
        position: "relative",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        imageRendering: "pixelated",
      },
      canvas: {
        position: "absolute",
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        imageRendering: "pixelated",
        zIndex: 0,
      },
      center: {
        position: "relative",
        width: scalingFactor,
        height: scalingFactor,
        boxShadow: `inset 0px 0px 0px 1px ${HAIR_DARK}, ${HAIR_LIGHT_STROKE_SHADOW}`,
        zIndex: 1,
      },
    };
  }, [scalingFactor, viewportHeight, viewportWidth]);

  return (
    <div style={styles.viewport}>
      <canvas
        style={styles.canvas}
        // src={src}
        ref={setCanvas}
        width={viewportWidth}
        height={viewportHeight}
      />
      <div style={styles.center} />
      <CopyInput current={color} onCopy={() => undefined /* TODO */} />
      <LoupeLegend text={props.legendText} color={color} />
    </div>
  );
}

const SYSTEM_UI_MONO = `ui-monospace, Menlo, Monaco, "Cascadia Mono", "Segoe UI Mono", "Roboto Mono", "Oxygen Mono", "Ubuntu Monospace", "Source Code Pro", "Fira Mono", "Droid Sans Mono", "Courier New", monospace`;

function LoupeLegend(props: { text: Signal<string>; color: Signal<string> }) {
  const text = useValue(props.text);
  const color = useValue(props.color);

  const styles = useStyles(
    () => ({
      legend: {
        display: "flex",
        flexDirection: "row",
        position: "absolute",
        bottom: 0,
        left: 0,
        right: 0,
        // borderTopStyle: "solid",
        // borderImage: `linear-gradient(to bottom, ${HAIR_DARK} 0px, ${HAIR_DARK} 1px, ${HAIR_LIGHT} 2px, ${HAIR_DARK} 3px) 4`,
        // borderImageWidth: "4px 0px 0px 0px",
        backgroundColor: color,
      },
      text: {
        fontSize: 9,
        fontFamily: SYSTEM_UI_MONO,
        padding: "3px 0px",
        color: "white",
        textShadow:
          "0px 1px 0px rgba(0, 0, 0, 1), 0px -1px 0px rgba(0, 0, 0, 1), -1px 0px 0px rgba(0, 0, 0, 1), 1px 0px 0px rgba(0, 0, 0, 1)",
        width: "50%",
        textAlign: "center",
      },
    }),
    [color]
  );

  return (
    <div style={styles.legend}>
      <div style={styles.text}>{text}</div>
      <div style={styles.text}>{color}</div>
    </div>
  );
}

function CopyInput(props: {
  current: Computed<string>;
  onCopy?: (value: string) => void;
}) {
  const { current, onCopy } = props;
  const styles = useStyles(
    () => ({
      input: {
        position: "absolute",
        top: -10_000,
        left: -10_000,
        width: 0,
        height: 0,
      },
    }),
    []
  );

  const inputRef = useRef<HTMLInputElement>(null);
  useLayoutEffect(
    () =>
      react("updateInput", () => {
        const value = current.value;
        const input = inputRef.current;
        if (!input) {
          return;
        }
        input.value = value;
        input.select();
      }),
    [current]
  );

  return (
    <input
      ref={inputRef}
      type="text"
      value={current.value}
      readOnly
      onCopy={(e) => {
        const copiedColor = current.value;
        void TLShot.api.writeClipboardPlaintext(copiedColor);
        new Notification(`Copied ${copiedColor}`);
        requestAnimationFrame(() => {
          onCopy?.(copiedColor);
        });
      }}
      style={styles.input}
    />
  );
}

export function useDisplayImageBitmap(display: DisplayRecord) {
  const imageSrc = useMemo(() => {
    const url = createScreenshotRequestURL({
      displayId: display.displayId,
      id: createScreenshotID(),
      rect: undefined,
    });
    return String(url);
  }, [display.displayId]);

  // Large images lead to stuttering on the main thread from image decoding.
  // We use Worker to decode image in parallel.
  const [imageBitmap, setImageBitmap] = useState<ImageBitmap | undefined>(
    undefined
  );
  useEffect(() => {
    let cancelled = false;
    const worker = new Worker(
      new URL(
        "./imageDecoder.worker.ts",
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-ignore
        import.meta.url
      )
    );

    const asyncFn = async () => {
      const imageData = await debugPromise(
        "fetch image",
        fetch(imageSrc).then((r) => r.arrayBuffer())
      );
      if (cancelled) {
        return;
      }

      const promise = debugPromise(
        "worker.onmessage",
        new Promise<MessageEvent>((resolve, reject) => {
          worker.onerror = reject;
          worker.onmessageerror = reject;
          worker.onmessage = resolve;
        })
      );
      worker.postMessage(imageData, [imageData]);
      const event = await promise;
      if (cancelled) {
        return;
      }

      const bitmap = event.data as ImageBitmap;
      setImageBitmap(bitmap);
    };
    void asyncFn();

    return () => {
      cancelled = true;
      worker.terminate();
    };
  }, [imageSrc]);

  return imageBitmap;
}

function useColorAtPoint(
  img: ImageBitmap,
  point: Signal<{ x: number; y: number }>,
  defaultColor: string
) {
  const [eyeDropperCtx] = useState(() => {
    const canvas = new OffscreenCanvas(1, 1);
    const ctx = canvas.getContext("2d", {
      willReadFrequently: true,
    });
    if (!ctx) {
      throw new Error(`Failed to create eye dropper canvas`);
    }
    return ctx;
  });

  const eyeDropperColor = useComputed(
    "useColorAtPoint",
    () => {
      if (img && img.width > 0) {
        eyeDropperCtx.drawImage(
          img,
          point.value.x,
          point.value.y,
          1,
          1,
          0,
          0,
          1,
          1
        );
        const [r, g, b] = eyeDropperCtx.getImageData(0, 0, 1, 1).data;
        return (
          "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("")
        );
      } else {
        return defaultColor;
      }
    },
    [eyeDropperCtx, img, point, defaultColor]
  );

  return eyeDropperColor;
}
