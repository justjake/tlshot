import "./captureView.css";
import React, { CSSProperties, useCallback, useMemo, useState } from "react";
import { useStyles } from "./useStyles";
import { AppReticleWindows } from "./ReticleWindows";
import { AppSourcePickerWindow } from "./SourcePickerWindow";

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

  const startCapture = (type: "picker" | "reticle") => {
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
        return <AppSourcePickerWindow onClose={handleClose} />;
      case "reticle":
        return <AppReticleWindows onClose={handleClose} />;
      default:
        throw new Error("Unknown capture view type");
    }
  }, [state, handleClose]);

  return (
    <>
      <div className="capture-view-toolbar" style={styles.toolbar}>
        <button onClick={() => startCapture("reticle")}>Grab Area</button>{" "}
        <button onClick={() => startCapture("picker")}>Grab Window</button>
      </div>
      {activeCaptureView}
    </>
  );
}
