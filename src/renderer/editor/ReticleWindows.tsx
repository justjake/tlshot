/**
 * Renders a Reticle window for each display.
 */

import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { Reticle, useDisplayImageSrc } from "./Reticle";
import { captureDisplay, createShapeFromBlob } from "./captureHelpers";
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

  const windows = displays.map((display) => (
    <ReticleWindow key={display.id} display={display} {...props} />
  ));

  return <>{windows}</>;
}

function ReticleWindow(props: {
  display: DisplayRecord;
  onClose: () => void;
  onSelect: (display: DisplayRecord, rect: DOMRect) => void;
}) {
  const { display, onClose, onSelect } = props;
  const loupeSrc = useDisplayImageSrc(props.display);
  if (!loupeSrc) return null;
  return (
    <ModalOverlayWindow
      key={display.id}
      onClose={props.onClose}
      display={display}
    >
      <Reticle
        onClose={props.onClose}
        onSelect={(rect) => onSelect(display, rect)}
        src={loupeSrc}
      />
    </ModalOverlayWindow>
  );
}
