/**
 * Renders a Reticle window for each display.
 */

import React from "react";
import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { Reticle } from "./Reticle";
import { captureUserMediaSource, createShapeFromBlob } from "./captureHelpers";
import { App, useApp } from "@tldraw/editor";
import { TLShot } from "../TLShotRendererApp";
import { useComputed, useValue } from "signia-react";
import { DisplayRecord } from "../../shared/records/DisplayRecord";

export function AppReticleWindows(props: { onClose: () => void }) {
  const app = useApp();
  return (
    <ReticleWindows
      onClose={props.onClose}
      onSelect={(display, rect) =>
        void captureDisplayRectToApp(app, display, rect)
      }
    />
  );
}

async function captureDisplayRectToApp(
  app: App,
  display: DisplayRecord,
  rect: DOMRect
) {
  const source = await TLShot.api.getDisplaySource(display.displayId);
  if (!source) {
    throw new Error(`No source for display ${display.id}`);
  }

  const blob = await captureUserMediaSource(source.id, rect);
  await createShapeFromBlob(app, blob);
}

export function ReticleWindows(props: {
  onClose: () => void;
  onSelect: (display: DisplayRecord, rect: DOMRect) => void;
}) {
  const displays = useValue(
    useComputed(
      "displays",
      () => TLShot.store.query.records("display").value,
      []
    )
  );

  const windows = displays.map((display) => {
    return (
      <ModalOverlayWindow
        key={display.id}
        onClose={props.onClose}
        display={display}
      >
        <Reticle
          onClose={props.onClose}
          displayId={display.displayId}
          onSelect={(rect) => props.onSelect(display, rect)}
        />
      </ModalOverlayWindow>
    );
  });

  return <>{windows}</>;
}
