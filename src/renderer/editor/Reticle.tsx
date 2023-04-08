import { useEffect, useRef, useState } from "react";
import { useStyles } from "./useStyles";
import React from "react";
import { useGetWindow } from "./ChildWindow";

export function Reticle(props: { onSelect: (rect: DOMRect) => void }) {
  const vertical = useRef<HTMLDivElement>(null);
  const horizontal = useRef<HTMLDivElement>(null);
  const bg = useRef<HTMLDivElement>(null);
  const wrapper = useRef<HTMLDivElement>(null);
  const [dragOrigin, setDragOrigin] = useState<
    { x: number; y: number } | undefined
  >(undefined);

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

        top: "50%",
      },
      v: {
        position: "absolute",
        width: hairWidth,
        height: "500%",
        borderLeft: hairStroke,
        borderRight: hairStroke,
        background: hairFill,

        left: "50%",
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

  const getWindow = useGetWindow();
  useEffect(() => {
    function handleMouseDown(e: MouseEvent) {
      const origin = { x: e.clientX, y: e.clientY };
      isDragging.current = true;
      mousePosition.current = startPosition.current = origin;
      setDragOrigin(origin);
    }

    function handleMouseMove(e: MouseEvent) {
      if (!vertical.current || !horizontal.current || !bg.current) {
        return;
      }
      mousePosition.current = { x: e.clientX, y: e.clientY };
      vertical.current.style.left = `${e.clientX - 1.5}px`;
      horizontal.current.style.top = `${e.clientY - 1.5}px`;
      if (isDragging.current) {
        bg.current.style.clipPath = getClipPath();
      }
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

    getWindow().addEventListener("mousedown", handleMouseDown);
    getWindow().addEventListener("mousemove", handleMouseMove);
    getWindow().addEventListener("mouseup", handleMouseUp);
    return () => {
      getWindow().removeEventListener("mousedown", handleMouseDown);
      getWindow().removeEventListener("mousemove", handleMouseMove);
      getWindow().removeEventListener("mouseup", handleMouseUp);
    };
  }, [props.onSelect, getWindow]);

  return (
    <div ref={wrapper} style={styles.wrapper}>
      <div ref={bg} className="reticle-bg" style={styles.bg} />
      <div
        className="reticle-hair horizontal"
        ref={horizontal}
        style={styles.h}
      />
      <div className="reticle-hair vertical" ref={vertical} style={styles.v} />
      {dragOrigin && <div className="drag-origin" style={styles.origin} />}
    </div>
  );
}
