import React, { useEffect } from "react";
import { ChildWindow, useGetWindow } from "./ChildWindow";

export function ModalOverlayWindow(props: {
  children: React.ReactNode;
  onClose: () => void;
}) {
  const getWindow = useGetWindow();
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
        transparent: true,
        backgroundColor: "#00000000",
        hasShadow: false,
        width: getWindow().screen.width,
        height: getWindow().screen.height,
        left: 0,
        top: 0,
        useContentSize: true,
        alwaysOnTop: true,
        enableLargerThanScreen: true,
        titleBarStyle: "hidden",
        frame: false,
        roundedCorners: false,
        hiddenInMissionControl: true,
      }}
    >
      <ChildWindowEscapeListener
        onBlur={props.onClose}
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
