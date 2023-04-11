import React, { useEffect, useState } from "react";
import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { SourcesGrid } from "./SourcePicker";
import { CaptureSource } from "../../main/services";
import { captureUserMediaSource, createShapeFromBlob } from "./captureHelpers";
import { useApp } from "@tldraw/editor";
import { TLShot } from "../TLShotRendererApp";

export function SourcePickerWindow(props: { onClose: () => void }) {
  const [sources, setSource] = useState<CaptureSource[] | undefined>();
  useEffect(() => {
    const get = async () => {
      const sources = await TLShot.api.getSources();
      setSource(sources);
    };
    void get();
  }, []);

  const app = useApp();

  if (!sources) {
    return null;
  }

  return (
    <ModalOverlayWindow onClose={props.onClose}>
      <SourcesGrid
        sources={sources}
        onClose={props.onClose}
        onClickSource={(source) => {
          props.onClose();
          requestAnimationFrame(async () => {
            const blob = await captureUserMediaSource(source.id, undefined);
            createShapeFromBlob(app, blob);
          });
        }}
      />
    </ModalOverlayWindow>
  );
}
