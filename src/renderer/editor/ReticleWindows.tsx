/**
 * Renders a Reticle window for each display.
 */

import React from "react";
import { DisplayProvider, useDisplays } from "./Displays";
import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { Reticle } from "./Reticle";
import { Display } from "electron";
import { captureUserMediaSource, createShapeFromBlob } from "./captureHelpers";
import { App, useApp } from "@tldraw/editor";

export function ReticleWindows(props: { onClose: () => void }) {
  const displays = useDisplays();
  const app = useApp();

  if (!displays) {
    return null;
  }

  const windows = Array.from(displays.displays.values()).map((display) => {
    return (
      <ModalOverlayWindow
        key={display.id}
        onClose={props.onClose}
        display={display}
      >
        <DisplayProvider self={display}>
          <Reticle
            onClose={props.onClose}
            onSelect={(rect) => onSelectDisplay(app, display, rect)}
          />
        </DisplayProvider>
      </ModalOverlayWindow>
    );
  });

  return <>{windows}</>;
}

async function onSelectDisplay(app: App, display: Display, rect: DOMRect) {
  const source = await window.TlshotAPI.getDisplaySource(display.id);
  if (!source) {
    throw new Error(`No source for display ${display.id}`);
  }

  const blob = await captureUserMediaSource(source.id, rect);
  await createShapeFromBlob(app, blob);
}
