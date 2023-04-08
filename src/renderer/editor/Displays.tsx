import React, { useContext } from "react";
import { Display } from "electron";
import { createContext, useEffect, useMemo, useState } from "react";

export interface DisplaysState {
  displays: Map<number, Display>;
  currentDisplay: number;
}

export interface DisplayContextValue {
  displays: Map<number, Display>;
  currentDisplay: number;
  self: Display;
}

const DisplayContext = createContext<DisplayContextValue | undefined>(
  undefined
);

export function DisplaysListener({ children }: { children: React.ReactNode }) {
  const displays = useDisplayListener();
  const value = useMemo<DisplayContextValue | undefined>(() => {
    if (!displays) {
      return undefined;
    }

    const self = displays.displays.get(displays.currentDisplay);
    if (!self) {
      throw new Error(`Unknown current display ${displays.currentDisplay}`);
    }
    return {
      ...displays,
      self,
    };
  }, [displays]);
  return (
    <DisplayContext.Provider value={value}>{children}</DisplayContext.Provider>
  );
}

export function DisplayProvider(props: {
  self: Display;
  children: React.ReactNode;
}) {
  const currentValue = useContext(DisplayContext);
  const newValue = useMemo<DisplayContextValue | undefined>(() => {
    if (!currentValue) {
      return undefined;
    }

    return {
      ...currentValue,
      self: props.self,
    };
  }, [currentValue, props.self]);
  return (
    <DisplayContext.Provider value={newValue}>
      {props.children}
    </DisplayContext.Provider>
  );
}

export function useDisplays(): DisplayContextValue | undefined {
  return useContext(DisplayContext);
}

function useDisplayListener() {
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

    const off = window.TlshotAPI.onDisplaysChanged(handleDisplayUpdate);
    void loadDisplays();
    return () => {
      unmounted = true;
      off();
    };
  }, []);
  return state;
}
