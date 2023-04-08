import { Display } from "electron";
import { useEffect, useState } from "react";

export interface DisplaysState {
  displays: Map<number, Display>;
  currentDisplay: number;
}

export function useDisplays() {
  const [state, setState] = useState<DisplaysState | undefined>(undefined);
  useEffect(() => {
    let unmounted = false;

    function handleDisplayUpdate(newState: DisplaysState) {
      if (unmounted) return;
      setState(newState);
    }

    const loadDisplays = async () => {
      const state = await window.TlshotAPI.subscribeToDisplays();
      if (unmounted) return;
      setState(state);
    };

    console.log(window.TlshotAPI);

    const off = window.TlshotAPI.onDisplaysChanged(handleDisplayUpdate);
    void loadDisplays();
    return () => {
      unmounted = true;
      off();
    };
  }, []);
  return state;
}
