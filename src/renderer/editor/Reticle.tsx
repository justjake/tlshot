import React, {
  CSSProperties,
  ForwardedRef,
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { useStyles } from "./useStyles";
import { useGetWindow } from "./ChildWindow";
import { captureUserMediaSource } from "./captureHelpers";
import { TLShot } from "../TLShotRendererApp";
import { DisplayId } from "../../main/WindowDisplayService";

export function Reticle(props: {
  displayId: DisplayId;
  onSelect: (rect: DOMRect) => void;
  onClose: () => void;
}) {
  const getWindow = useGetWindow();

  const vertical = useRef<HTMLDivElement>(null);
  const horizontal = useRef<HTMLDivElement>(null);
  const bg = useRef<HTMLDivElement>(null);
  const wrapper = useRef<HTMLDivElement>(null);
  const dimensions = useRef<DragDimensionsRef>(null);

  const [dragOrigin, setDragOrigin] = useState<
    { x: number; y: number } | undefined
  >(undefined);
  const [mouseState, setMouseState] = useState<
    { x: number; y: number } | undefined
  >();

  const styles = useStyles(() => {
    const hairWidth = 3;
    const hairStroke = `1px solid rgba(255, 255, 255, 0.3)`;
    const hairFill = `1px solid rgba(0, 0, 0, 0.4)`;
    return {
      wrapper: {
        height: "100%",
        overflow: "clip",
        cursor: "none",
      },
      bg: {
        background: dragOrigin ? "rgba(0,0,0,0.3)" : "rgba(100, 100, 100, 0.2)",
        position: "absolute",
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
      },
      h: {
        position: "absolute",
        width: "500%",
        height: hairWidth,
        borderTop: hairStroke,
        borderBottom: hairStroke,
        background: hairFill,
      },
      v: {
        position: "absolute",
        width: hairWidth,
        height: "500%",
        borderLeft: hairStroke,
        borderRight: hairStroke,
        background: hairFill,
      },
      origin: {
        position: "absolute",
        width: hairWidth,
        height: hairWidth,
        background: "rgba(255, 255, 255, 0.7)",
        left: (dragOrigin?.x || 0) - hairWidth / 2,
        top: (dragOrigin?.y || 0) - hairWidth / 2,
      },
    };
  }, [dragOrigin]);

  const isDragging = useRef(false);
  const mousePosition = useRef({ x: 0, y: 0 });
  const startPosition = useRef({ x: 0, y: 0 });

  // Grab focus when the mouse enters the window
  const hasMouseState = Boolean(mouseState);
  useEffect(() => {
    if (hasMouseState) {
      console.log("become active");
      void TLShot.api.focusTopWindowNearMouse();
    }
  }, [hasMouseState]);

  useEffect(() => {
    function handleMouseDown(e: MouseEvent) {
      const origin = { x: e.clientX, y: e.clientY };
      isDragging.current = true;
      mousePosition.current = startPosition.current = origin;
      setDragOrigin(origin);
    }

    function handleMouseMove(e: MouseEvent) {
      // Imperatively move the reticle. Faster than React re-render.
      dimensions.current?.setPosition(mousePosition.current);

      if (vertical.current && horizontal.current && bg.current) {
        mousePosition.current = { x: e.clientX, y: e.clientY };
        vertical.current.style.left = `${e.clientX - 1.5}px`;
        horizontal.current.style.top = `${e.clientY - 1.5}px`;
        if (isDragging.current) {
          bg.current.style.clipPath = getClipPath();
        }
      }

      setMouseState({ x: e.clientX, y: e.clientY });
    }

    function handleMouseUp() {
      setDragOrigin(undefined);
      isDragging.current = false;
      if (bg.current) {
        bg.current.style.clipPath = "none";
      }

      const minX = Math.min(startPosition.current.x, mousePosition.current.x);
      const maxX = Math.max(startPosition.current.x, mousePosition.current.x);
      const minY = Math.min(startPosition.current.y, mousePosition.current.y);
      const maxY = Math.max(startPosition.current.y, mousePosition.current.y);
      const width = maxX - minX;
      const height = maxY - minY;
      const rect = new DOMRect(minX, minY, width, height);

      // Close the window immediately so we aren't included in the capture
      if (wrapper.current) {
        wrapper.current.style.display = "none";
      }
      getWindow().close();
      requestAnimationFrame(() => {
        props.onSelect(rect);
      });
    }

    function getClipPath() {
      const topLeft = "0% 0%";
      const bottomLeft = "0% 100%";
      const topRight = "100% 0%";
      const bottomRight = "100% 100%";
      const leftX = Math.min(startPosition.current.x, mousePosition.current.x);
      const rightX = Math.max(startPosition.current.x, mousePosition.current.x);
      const topY = Math.min(startPosition.current.y, mousePosition.current.y);
      const bottomY = Math.max(
        startPosition.current.y,
        mousePosition.current.y
      );
      const polygon = [
        topLeft,
        bottomLeft,
        `${leftX}px 100%`,
        `${leftX}px ${topY}px`,
        `${rightX}px ${topY}px`,
        `${rightX}px ${bottomY}px`,
        `${leftX}px ${bottomY}px`,
        `${leftX}px 100%`,
        bottomRight,
        topRight,
      ];
      return `polygon(${polygon.join(", ")})`;
    }

    function handleLoseMouse() {
      // mouseout occurs over transparent portions of the screen?
      // console.log("mouse out", e.relatedTarget, e);
      setMouseState(undefined);
    }

    getWindow().addEventListener("mousedown", handleMouseDown);
    getWindow().addEventListener("mousemove", handleMouseMove);
    getWindow().addEventListener("mouseup", handleMouseUp);
    getWindow().addEventListener("mouseleave", handleLoseMouse);
    getWindow().addEventListener("blur", handleLoseMouse);
    return () => {
      getWindow().removeEventListener("mousedown", handleMouseDown);
      getWindow().removeEventListener("mousemove", handleMouseMove);
      getWindow().removeEventListener("mouseup", handleMouseUp);
      getWindow().removeEventListener("mouseleave", handleLoseMouse);
      getWindow().removeEventListener("blur", handleLoseMouse);
    };
  }, [props.onSelect, getWindow, props]);

  return (
    <div ref={wrapper} style={styles.wrapper}>
      <div ref={bg} className="reticle-bg" style={styles.bg} />
      {dragOrigin && <div className="drag-origin" style={styles.origin} />}
      {mouseState && (
        <>
          <div
            className="reticle-hair horizontal"
            ref={horizontal}
            style={styles.h}
          />
          <div
            className="reticle-hair vertical"
            ref={vertical}
            style={styles.v}
          />
          <DragDimensions
            displayId={props.displayId}
            onClose={props.onClose}
            origin={dragOrigin}
            current={mouseState}
            ref={dimensions}
          />
        </>
      )}
    </div>
  );
}

interface DragDimensionsRef {
  setPosition(point: { x: number; y: number }): void;
}

// Needs a rewrite
const DragDimensions = forwardRef(function DragDimensions(
  props: {
    displayId: DisplayId;
    origin: { x: number; y: number } | undefined;
    current: { x: number; y: number };
    onClose: () => void;
  },
  ref: ForwardedRef<DragDimensionsRef>
) {
  const offset = 8;
  const mousePositionRef = useRef(props.current);
  const wrapper = useRef<HTMLDivElement | null>(null);
  const setPosition = useCallback((point: { x: number; y: number }) => {
    mousePositionRef.current = point;
    if (wrapper.current) {
      wrapper.current.style.left = `${point.x + offset}px`;
      wrapper.current.style.top = `${point.y + offset}px`;
    }
  }, []);
  useImperativeHandle(
    ref,
    () => ({
      setPosition,
    }),
    [setPosition]
  );

  useLayoutEffect(() => {
    setPosition(mousePositionRef.current);
  }, [setPosition]);

  const bgImageElement = useRef<HTMLImageElement | null>(null);

  const [bg, setBg] = useState<string | undefined>();
  useEffect(() => {
    // On mount, capture the screen to use as loupe
    let unmounted = false;
    let blobUrl: string | undefined = undefined;
    const perform = async () => {
      const source = await TLShot.api.getDisplaySource(props.displayId);
      if (unmounted) {
        return;
      }

      const blob = await captureUserMediaSource(source.id, undefined);
      if (unmounted) {
        return;
      }

      blobUrl = URL.createObjectURL(blob);
      setBg(blobUrl);
    };
    void perform();
    return () => {
      unmounted = true;
      if (blobUrl) {
        setBg(undefined);
        URL.revokeObjectURL(blobUrl);
      }
    };
  }, [props.displayId]);

  const getWindow = useGetWindow();

  const [canvas] = useState(() => {
    const canvas = document.createElement("canvas");
    canvas.width = 1;
    canvas.height = 1;
    return canvas;
  });

  const currentColor = useMemo(() => {
    const ctx = canvas.getContext("2d", {
      willReadFrequently: true,
    });
    if (!ctx || !bgImageElement.current) {
      return undefined;
    }
    ctx.drawImage(
      bgImageElement.current,
      mousePositionRef.current.x,
      mousePositionRef.current.y,
      1,
      1,
      0,
      0,
      1,
      1
    );
    const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data;
    return "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("");
  }, [canvas]);

  const style = useStyles(() => {
    const bgSize = 128;
    const boundaryZone = bgSize + offset * 2;
    const bgScale = 5;
    const currentWindowWidth = getWindow().innerWidth;
    const currentWindowHeight = getWindow().innerHeight;

    let flipX = false;
    flipX ||= Boolean(
      props.origin &&
        props.origin.x > mousePositionRef.current.x &&
        props.origin.y > mousePositionRef.current.y
    );
    flipX ||= mousePositionRef.current.x + boundaryZone > currentWindowWidth;
    if (flipX && mousePositionRef.current.x - boundaryZone < 0) {
      flipX = false;
    }
    const flipY =
      mousePositionRef.current.y + boundaryZone > currentWindowHeight;
    const translateX = flipX ? `calc(-100% - ${offset * 2}px)` : "0px";
    const translateY = flipY ? `calc(-100% - ${offset * 2}px)` : "0px";
    const hairStroke = `1px solid rgba(255, 255, 255, 0.3)`;
    const hairFill = `1px solid rgba(0, 0, 0, 0.4)`;

    const textStyle: CSSProperties = {
      padding: "2px 0px",
      color: "white",
      textShadow:
        "0px 1px 0px rgba(0, 0, 0, 1), 0px -1px 0px rgba(0, 0, 0, 1), -1px 0px 0px rgba(0, 0, 0, 1), 1px 0px 0px rgba(0, 0, 0, 1)",
      width: "50%",
      textAlign: "center",
    };

    return {
      spot: {
        width: bgSize,
        position: "absolute",
        transform: `translate(${translateX}, ${translateY})`,
        borderRadius: 3,
        background: "rgba(0, 0, 0, 0.7)",
        border: "2px solid rgba(0, 0, 0, 0.7)",
        color: "white",
        fontSize: 9,
        fontFamily: SYSTEM_UI_MONO,
        textAlign: "center",
        overflow: "clip",
        imageRendering: "pixelated",
        top: mousePositionRef.current.y,
        left: mousePositionRef.current.x,
      },
      texts: {
        display: "flex",
        flexDirection: "row",
        position: "absolute",
        bottom: 0,
        left: 0,
        right: 0,
        background: currentColor,
        borderTop: hairFill,
      },
      color: textStyle,
      pos: textStyle,
      bg: {
        width: bgSize,
        height: bgSize,
        backgroundImage: bg && `url(${bg})`,
        backgroundSize: currentWindowWidth * bgScale,
        backgroundRepeat: "no-repeat",
        backgroundPositionX: -mousePositionRef.current.x * bgScale + bgSize / 2,
        backgroundPositionY: -mousePositionRef.current.y * bgScale + bgSize / 2,
        position: "relative",
      },
      v: {
        position: "absolute",
        width: 7,
        height: bgSize,
        left: bgSize / 2 - 4,
        borderLeft: hairStroke,
        borderRight: hairStroke,
      },
      h: {
        position: "absolute",
        width: bgSize,
        height: 7,
        top: bgSize / 2 - 4,
        borderTop: hairStroke,
        borderBottom: hairStroke,
      },
    };
  }, [getWindow, props.origin, currentColor, bg]);

  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    inputRef.current?.select();
  }, [currentColor]);

  const dx = props.origin
    ? Math.abs(props.origin.x - mousePositionRef.current.x)
    : mousePositionRef.current.x;
  const dy = props.origin
    ? Math.abs(props.origin.y - mousePositionRef.current.y)
    : mousePositionRef.current.y;

  if (!bg) {
    return null;
  }

  return (
    <div className="drag-dimensions" style={style.spot} ref={wrapper}>
      <input
        ref={inputRef}
        type="text"
        value={currentColor || "#000000"}
        readOnly
        onCopy={(e) => {
          const copiedColor = currentColor || "#000000";
          console.log("onCopy", copiedColor);
          e.clipboardData.setData("text/plain", copiedColor);
          new Notification(`Copied ${copiedColor}`);
          requestAnimationFrame(() => {
            props.onClose();
          });
        }}
        style={{
          position: "absolute",
          top: -10_000,
          left: -10_000,
        }}
      />
      <div className="loupe" style={style.bg}>
        <div style={style.v} />
        <div style={style.h} />
      </div>
      <img
        ref={bgImageElement}
        src={bg}
        style={{
          display: "none",
        }}
      />
      <div style={style.texts}>
        <div style={style.pos}>
          {String(dx).padStart(4)} x {String(dy).padEnd(4)}
        </div>
        <div style={style.color}>{currentColor}</div>
      </div>
    </div>
  );
});

const SYSTEM_UI_MONO = `ui-monospace, 
             Menlo, Monaco, 
             "Cascadia Mono", "Segoe UI Mono", 
             "Roboto Mono", 
             "Oxygen Mono", 
             "Ubuntu Monospace", 
             "Source Code Pro",
             "Fira Mono", 
             "Droid Sans Mono", 
             "Courier New", monospace
`.trim();
