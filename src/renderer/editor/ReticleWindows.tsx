/**
 * Renders a Reticle window for each display.
 */

import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { Reticle, ReticleState } from "./Reticle";
import { captureDisplay, createShapeFromBlob } from "./captureHelpers";
import { App, useApp } from "@tldraw/editor";
import { TLShot } from "../TLShotRendererApp";
import { useComputed, useValue } from "signia-react";
import { DisplayRecord } from "../../shared/records/DisplayRecord";
import { useState } from "react";

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
  const blob = await captureDisplay(display, rect);
  await createShapeFromBlob(app, blob.blob);
  app.zoomToFit();
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

  const [state] = useState(() => new ReticleState());

  const windows = displays.map((display) => (
    <ReticleWindow
      key={display.id}
      display={display}
      state={state}
      {...props}
    />
  ));

  return <>{windows}</>;
}

function ReticleWindow(props: {
  state: ReticleState;
  display: DisplayRecord;
  onClose: () => void;
  onSelect: (display: DisplayRecord, rect: DOMRect) => void;
}) {
  const { display, onClose, onSelect } = props;
  return (
    <ModalOverlayWindow
      key={display.id}
      onClose={props.onClose}
      display={display}
      // showInactive={true}
    >
      <Reticle
        state={props.state}
        onClose={props.onClose}
        onSelect={(rect) => onSelect(display, rect)}
        display={display}
      />
    </ModalOverlayWindow>
  );
}
