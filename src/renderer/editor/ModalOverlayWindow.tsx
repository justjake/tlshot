import React, { useEffect } from "react";
import { ChildWindow, useGetWindow } from "./ChildWindow";
import { Display } from "electron";

export function ModalOverlayWindow(props: {
  children: React.ReactNode;
  onClose: () => void;
  display?: Display;
}) {
  const getWindow = useGetWindow();

  const left = props.display?.bounds.x ?? 0;
  const top = props.display?.bounds.y ?? 0;
  const width = props.display?.bounds.width ?? getWindow().screen.width;
  const height = props.display?.bounds.height ?? getWindow().screen.height;

  return (
    <ChildWindow
      name="Take screenshot"
      onUnload={props.onClose}
      onOpen={async (_, handle) => {
        await handle.registered;
        if (handle.browserWindowId) {
          window.TlshotAPI.setAlwaysOnTop(handle.browserWindowId);
        }
      }}
      center="none"
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
  const getWindow = useGetWindow();
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        props.onEscape?.();
      }
    }

    function handleBlur() {
      props.onBlur?.();
    }

    getWindow().addEventListener("keydown", handleKeyDown);
    getWindow().addEventListener("blur", handleBlur);
    return () => {
      getWindow().removeEventListener("keydown", handleKeyDown);
      getWindow().removeEventListener("blur", handleBlur);
    };
  }, [getWindow]);

  return null;
}
