import React, { useEffect } from "react";
import { ChildWindow, useGetWindow } from "./ChildWindow";
import { DisplayRecord } from "../../shared/records/DisplayRecord";

export function ModalOverlayWindow(props: {
  children: React.ReactNode;
  onClose: () => void;
  display?: DisplayRecord;
  showInactive?: boolean;
}) {
  const getParent = useGetWindow();

  const left = props.display?.bounds.x ?? 0;
  const top = props.display?.bounds.y ?? 0;
  const width = props.display?.bounds.width ?? getParent().screen.width;
  const height = props.display?.bounds.height ?? getParent().screen.height;

  return (
    <ChildWindow
      name="Take screenshot"
      alwaysOnTop="screen-saver"
      onUnload={props.onClose}
      center={props.display ? "none" : "screen"}
      showInactive={props.showInactive}
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
        resizable: false,
        focusable: false,
        skipTaskbar: true,

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
