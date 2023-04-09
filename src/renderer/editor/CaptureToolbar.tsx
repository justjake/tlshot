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
import { SourcePickerWindow } from "./SourcePickerWindow";

type CaptureViewState =
  | { type: "closed" }
  | { type: "picker" }
  | { type: "reticle" };

export function CaptureView() {
  const [state, setState] = useState<CaptureViewState>({ type: "closed" });

  const styles = useStyles(() => {
    const toolbar: CSSProperties = {
      position: "absolute",
      top: "var(--space-3)",
      right: "var(--space-3)",
      zIndex: 1000,
    };

    return { toolbar };
  }, []);

  const startCapture = async (type: "picker" | "reticle") => {
    setState({
      type,
    });
  };

  const handleClose = useCallback(() => {
    setState({ type: "closed" });
  }, []);

  const activeCaptureView = useMemo(() => {
    switch (state.type) {
      case "closed":
        return null;
      case "picker":
        return <SourcePickerWindow onClose={handleClose} />;
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
