import React, { useEffect, useState } from "react";
import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { SourcesGrid } from "./SourcePicker";
import { CaptureSource } from "../../main/TLShotApi";
import { captureUserMediaSource, createShapeFromBlob } from "./captureHelpers";
import { useApp } from "@tldraw/editor";
import { TLShot } from "../TLShotRendererApp";
import { useComputed, useValue } from "signia-react";
import { useGetWindow } from "./ChildWindow";
import { DisplayRecord } from "@/shared/records/DisplayRecord";

export function AppSourcePickerWindow(props: { onClose: () => void }) {
  const app = useApp();
  const getWindow = useGetWindow();
  const display = useValue(
    useComputed(
      "activeDisplay",
      () => {
        const windowRecord = TLShot.store.query.record("window", () => ({
          childWindowId: {
            eq: getWindow.childWindowNanoid,
          },
        })).value;
        const display =
          windowRecord &&
          TLShot.store.query.record("display", () => ({
            displayId: {
              eq: windowRecord?.displayId,
            },
          })).value;
        return display;
      },
      [getWindow.childWindowNanoid]
    )
  );

  const onPickSource = (source: CaptureSource) => {
    props.onClose();
    // eslint-disable-next-line @typescript-eslint/no-misused-promises
    requestAnimationFrame(async () => {
      const blob = await captureUserMediaSource(source.id, undefined);
      void createShapeFromBlob(app, blob);
    });
  };

  return (
    <SourcePickerWindow
      coverDisplay={display}
      onClose={props.onClose}
      onPickSource={onPickSource}
    />
  );
}

export function SourcePickerWindow(props: {
  coverDisplay: DisplayRecord | undefined;
  onClose: () => void;
  onPickSource: (source: CaptureSource) => void;
}) {
  const [sources, setSource] = useState<CaptureSource[] | undefined>();
  useEffect(() => {
    const get = async () => {
      const sources = await TLShot.api.getSources();
      setSource(sources);
    };
    void get();
  }, []);

  if (!sources) {
    return null;
  }

  return (
    <ModalOverlayWindow display={props.coverDisplay} onClose={props.onClose}>
      <SourcesGrid
        sources={sources}
        onClose={props.onClose}
        onClickSource={props.onPickSource}
      />
    </ModalOverlayWindow>
  );
}
