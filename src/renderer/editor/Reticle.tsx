import React, {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { useStyles } from "./useStyles";
import { useGetWindow } from "./ChildWindow";
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

class ReticleState {
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

  readonly isInWindow = computed("reticle.isInWindow", () => {
    return this.mouse.value.x >= 0 && this.mouse.value.y >= 0;
  });

  readonly legendText = computed("reticle.legendText", () => {
    const rect = this.rect.value;
    const mouse = this.mouse.value;
    const { x, y } = rect ? { x: rect.width, y: rect.height } : mouse;
    return `${String(x).padStart(4)} x ${String(y).padEnd(4)}`;
  });
}

export function Reticle(props: {
  onSelect: (rect: DOMRect) => void;
  onClose: () => void;
  src: string;
}) {
  const { onSelect, onClose, src } = props;
  const [state] = useState(() => new ReticleState());
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

  // Grab focus when the mouse enters the window
  const isInWindow = useValue(state.isInWindow);
  useLayoutEffect(() => {
    if (isInWindow) {
      void TLShot.api.focusTopWindowNearMouse();
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
        loupeSrc={src}
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
  loupeSrc: string;
}) {
  const { state, loupeSize, loupePixelSize, loupeOffset, loupeSrc } = props;

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
        cursor: "none",
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
        if (!v || !h || !loupe || !bg) {
          return;
        }

        // Update the clipping mask of the background
        const selection = state.rect.value;
        if (selection) {
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
        loupe.style.transform = `translate(${loupePos.x}px, ${loupePos.y}px)`;
      }),
    [loupeSize, loupeOffset, state, getWindow]
  );

  return (
    <>
      <div style={styles.bg} ref={bgRef} />
      <div style={styles.h} ref={hRef} />
      <div style={styles.v} ref={vRef} />
      <div style={styles.loupe} ref={loupeRef}>
        <Loupe
          src={loupeSrc}
          loupeWidth={loupePixelSize}
          loupeHeight={loupePixelSize}
          loupeCenter={state.mouse}
          viewportWidth={loupeSize}
          viewportHeight={loupeSize}
          legendText={state.legendText}
        />
      </div>
    </>
  );
}

function Loupe(props: {
  src: string;

  // Pixels of the source image
  loupeCenter: Signal<{ x: number; y: number }>;
  loupeWidth: number;
  loupeHeight: number;

  // Size of the loupe on screen
  viewportWidth: number;
  viewportHeight: number;

  legendText: Signal<string>;
}) {
  const {
    src,
    loupeCenter,
    loupeWidth,
    loupeHeight,
    viewportWidth,
    viewportHeight,
  } = props;

  const [img, setImg] = useState<HTMLImageElement | null>(null);
  const color = useColorAtPoint(img, loupeCenter, "#000000");
  const { transform, scalingFactor } = useImageTransform({
    viewportWidth,
    viewportHeight,
    loupeWidth,
    loupeHeight,
    point: loupeCenter,
  });

  const styles = useStyles(() => {
    return {
      viewport: {
        width: viewportWidth,
        height: viewportHeight,
        overflow: "clip",
        position: "relative",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      },
      img: {
        position: "absolute",
        top: 0,
        left: 0,
        transformOrigin: "top left",
        willChange: "transform",
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

  useLayoutEffect(
    () =>
      react("applyImageTransform", () => {
        if (!img) {
          return;
        }
        img.style.transform = transform.value;
      }),
    [img, transform]
  );

  const getWindow = useGetWindow();

  return (
    <div style={styles.viewport}>
      <img
        style={styles.img}
        src={src}
        ref={setImg}
        width={getWindow().innerWidth}
        height={getWindow().innerHeight}
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

export function useDisplayImageSrc(display: DisplayRecord) {
  return useMemo(() => {
    const url = createScreenshotRequestURL({
      displayId: display.displayId,
      id: createScreenshotID(),
      rect: undefined,
    });
    return String(url);
  }, [display.displayId]);
}

function useImageTransform(args: {
  viewportWidth: number;
  viewportHeight: number;
  loupeWidth: number;
  loupeHeight: number;
  point: Signal<{ x: number; y: number }>;
}) {
  const { viewportWidth, viewportHeight, loupeWidth, loupeHeight, point } =
    args;

  const scalingFactor = useMemo(() => {
    const dw = viewportWidth / loupeWidth;
    const dh = viewportHeight / loupeHeight;
    return Math.max(dw, dh);
  }, [loupeHeight, loupeWidth, viewportHeight, viewportWidth]);

  const transform = useComputed(
    "useImageTransform",
    () => {
      // TODO: fudge pushes pixel off the bottom of the screen at the bottom edge
      const fudge = loupeWidth % 2 === 0 ? 0 : 0.5;
      const value = point.value;
      const z = scalingFactor;
      const camera = {
        x: value.x + fudge - viewportWidth / 2 / z,
        y: value.y + fudge - viewportHeight / 2 / z,
        z,
      };
      return `scale(${camera.z}) translate(${-camera.x}px, ${-camera.y}px) `;
    },
    [point, scalingFactor, viewportHeight, viewportWidth]
  );

  return {
    scalingFactor,
    transform,
  };
}

function useColorAtPoint(
  img: HTMLImageElement | null,
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

  let imageError = false;

  const eyeDropperColor = useComputed(
    "useColorAtPoint",
    () => {
      if (img && !imageError) {
        const xScale = img.naturalWidth / img.width;
        const yScale = img.naturalHeight / img.height;
        try {
          eyeDropperCtx.drawImage(
            img,
            point.value.x * xScale,
            point.value.y * yScale,
            1,
            1,
            0,
            0,
            1,
            1
          );
        } catch (error) {
          imageError = true;
          throw error;
        }
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
