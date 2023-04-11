import React, { useEffect } from "react";
import { ChildWindow, useGetWindow } from "./ChildWindow";
import { TLShot } from "../TLShotRendererApp";
import { waitUntil } from "../../shared/signiaHelpers";
import { DisplayRecord } from "../../shared/records/DisplayRecord";

export function ModalOverlayWindow(props: {
  children: React.ReactNode;
  onClose: () => void;
  display?: DisplayRecord;
}) {
  const getParent = useGetWindow();

  const left = props.display?.bounds.x ?? 0;
  const top = props.display?.bounds.y ?? 0;
  const width = props.display?.bounds.width ?? getParent().screen.width;
  const height = props.display?.bounds.height ?? getParent().screen.height;

  return (
    <ChildWindow
      name="Take screenshot"
      onUnload={props.onClose}
      // eslint-disable-next-line @typescript-eslint/no-misused-promises
      onOpen={async (_, handle) => {
        const query = TLShot.store.query.record("window", () => ({
          childWindowId: {
            eq: handle,
          },
        }));
        const browserId = await waitUntil(
          "modalOverlayBrowserId",
          () => query.value?.browserWindowId
        );
        void TLShot.api.setAlwaysOnTop(browserId);
      }}
      center={props.display ? "none" : "screen"}
      features={{
        // Styling.
        transparent: true,
        backgroundColor: "#00000000",
        hasShadow: false,
        alwaysOnTop: true,
        enableLargerThanScreen: true,
        titleBarStyle: "hidden",
        frame: false,
        roundedCorners: false,
        hiddenInMissionControl: true,

        // Sizing.
        left,
        top,
        width,
        height,
        useContentSize: true,
      }}
    >
      <ChildWindowEscapeListener
        // onBlur={props.onClose}
        onEscape={props.onClose}
      />
      {props.children}
    </ChildWindow>
  );
}

export function ChildWindowEscapeListener(props: {
  onEscape?: () => void;
  onBlur?: () => void;
}) {
  const { onEscape, onBlur } = props;
  const getWindow = useGetWindow();
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        onEscape?.();
      }
    }

    function handleBlur() {
      onBlur?.();
    }

    getWindow().addEventListener("keydown", handleKeyDown);
    getWindow().addEventListener("blur", handleBlur);
    return () => {
      getWindow().removeEventListener("keydown", handleKeyDown);
      getWindow().removeEventListener("blur", handleBlur);
    };
  }, [getWindow, onBlur, onEscape]);

  return null;
}
