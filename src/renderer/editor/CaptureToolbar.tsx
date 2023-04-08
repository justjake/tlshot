import React, { CSSProperties, useCallback, useMemo } from "react";
import { useState } from "react";
import { TlshotApiResponse } from "../../main/services";
import "./captureView.css";
import { createShapesFromFiles, useApp } from "@tldraw/editor";
import { ChildWindow, useGetWindow } from "./ChildWindow";
import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { useStyles } from "./useStyles";
import { Reticle } from "./Reticle";
import { useDisplays } from "./Displays";
import { SourcesGrid } from "./SourcePicker";
import { ReticleWindows } from "./ReticleWindows";

type CaptureViewState =
  | { type: "closed"; display?: undefined; sources?: undefined }
  | {
      type: "picker";
      sources: TlshotApiResponse["getSources"];
    }
  | {
      type: "reticle";
      sources?: undefined;
    };

export function CaptureView() {
  const [state, setState] = useState<CaptureViewState>({ type: "closed" });
  const displays = useDisplays();

  const startCapture = async (type: "picker" | "reticle") => {
    if (type === "picker") {
      const sources = await window.TlshotAPI.getSources();
      setState({
        type,
        sources,
      });
    } else {
      setState({
        type,
      });
    }
  };

  const app = useApp();
  const captureSourceToCanvas = useCallback(
    async (sourceId: string, rect?: DOMRect) => {
      const blob = await captureSource(sourceId, rect);
      await createShapesFromFiles(
        app,
        [Object.assign(blob as any, { name: "capture.png" })],
        app.viewportPageBounds.center,
        false
      );
    },
    [app]
  );

  const styles = useStyles(() => {
    const toolbar: CSSProperties = {
      position: "absolute",
      top: 0,
      right: 0,
      zIndex: 1000,
    };

    return { toolbar };
  }, []);

  const handleClose = useCallback(() => {
    setState({ type: "closed" });
  }, []);

  const activeCaptureView = useMemo(() => {
    switch (state.type) {
      case "closed":
        return null;
      case "picker":
        return (
          <ModalOverlayWindow onClose={handleClose}>
            <SourcesGrid
              sources={state.sources}
              onClose={handleClose}
              onClickSource={(source) => {
                handleClose();
                captureSourceToCanvas(source.id);
              }}
            />
          </ModalOverlayWindow>
        );
      case "reticle":
        return <ReticleWindows onClose={handleClose} />;
      default:
        throw new Error("Unknown capture view type");
    }
  }, [state, handleClose]);

  return (
    <>
      <div className="capture-view-toolbar" style={styles.toolbar}>
        <button onClick={() => startCapture("reticle")}>Drag</button>{" "}
        <button onClick={() => startCapture("picker")}>Pick Window</button>
      </div>
      {activeCaptureView}
    </>
  );
}
