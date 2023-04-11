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

export function ReticleWindows(props: { onClose: () => void }) {
  const displays = useValue(
    useComputed(
      "displays",
      () => TLShot.store.query.records("display").value,
      []
    )
  );
  const app = useApp();

  if (!displays) {
    return null;
  }

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
          onSelect={(rect) => void onSelectDisplay(app, display, rect)}
        />
      </ModalOverlayWindow>
    );
  });

  return <>{windows}</>;
}

async function onSelectDisplay(
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
