import { useEffect } from "react";
import { useGetWindow } from "./ChildWindow";

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
