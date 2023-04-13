import React, { useCallback, useEffect, useMemo, useState } from "react";
// eslint-disable-next-line import/default
import NewWindow, { IWindowFeatures } from "react-new-window";
import {
  BrowserWindowId,
  ChildWindowNanoid,
} from "../../main/WindowDisplayService";
import { nanoid } from "nanoid";
import { TLShot } from "../TLShotRendererApp";

interface ChildWindowInfo {
  childWindowId: ChildWindowNanoid;
  registered: Promise<void>;
  window?: WeakRef<Window>;
  browserWindowId?: BrowserWindowId;
}

class ChildWindowRegistry {
  public readonly ROOT_WINDOW: ChildWindowNanoid;
  private handles = new Map<ChildWindowNanoid, ChildWindowInfo>();
  private ready = new WeakMap<ChildWindowInfo, () => void>();

  constructor() {
    this.ROOT_WINDOW = this.createId();
    this.register(this.ROOT_WINDOW, globalThis.window);
  }

  createId(): ChildWindowNanoid {
    const childWindowId: ChildWindowNanoid = nanoid();
    const handle = {
      childWindowId,
    } as ChildWindowInfo;
    handle.registered = new Promise((resolve) => {
      this.ready.set(handle, resolve);
    });
    this.handles.set(childWindowId, handle);
    return childWindowId;
  }

  register(id: ChildWindowNanoid, childWindow: Window) {
    const handle = this.handles.get(id);
    if (!handle) {
      throw new Error(`Child window ID not found: ${id}`);
    }
    handle.window = new WeakRef(childWindow);
    this.ready.get(handle)?.();
    this.ready.delete(handle);
  }

  unregister(id: ChildWindowNanoid) {
    this.handles.delete(id);
  }

  getWindow(id: ChildWindowNanoid): Window {
    const childWindow = this.handles.get(id)?.window?.deref();
    if (!childWindow) {
      throw new Error(`Child window not found: ${id}`);
    }
    return childWindow;
  }

  getRootWindow(): Window {
    return this.getWindow(this.ROOT_WINDOW);
  }
}

export const Windows = new ChildWindowRegistry();

const ChildWindowNanoidContext = React.createContext<ChildWindowNanoid>(
  Windows.ROOT_WINDOW
);
ChildWindowNanoidContext.displayName = "ChildWindowNanoid";

interface GetWindowFunction {
  (): Window;
  childWindowNanoid: ChildWindowNanoid;
}

export function useGetWindow(): GetWindowFunction {
  const childWindowNanoid = React.useContext(ChildWindowNanoidContext);
  return useMemo(() => {
    const getWindow = () => Windows.getWindow(childWindowNanoid);
    getWindow.childWindowNanoid = childWindowNanoid;
    return getWindow;
  }, [childWindowNanoid]);
}

export type ChildWindowFeatures = Electron.BrowserWindowConstructorOptions &
  IWindowFeatures & { childWindowId?: ChildWindowNanoid };

export interface ChildWindowProps {
  name: string;
  copyStyles?: boolean;
  features?: Electron.BrowserWindowConstructorOptions & IWindowFeatures;
  onOpen?: (childWindow: Window, handle: ChildWindowNanoid) => void;
  onUnload?: () => void;
  children: React.ReactNode;
  center: "parent" | "screen" | "none";
  hidden?: boolean;
  alwaysOnTop?: boolean | "screen-saver";
}

export function ChildWindow(props: ChildWindowProps) {
  const { hidden, alwaysOnTop } = props;
  const [id] = useState(() => Windows.createId());
  const [open, setOpen] = useState(false);

  const applyProps = useCallback(
    () =>
      TLShot.api.updateChildWindow(id, {
        show: !hidden,
        alwaysOnTop,
      }),
    [id, hidden, alwaysOnTop]
  );

  const handleOpen = (childWindow: Window) => {
    Windows.register(id, childWindow);
    void applyProps();
    props.onOpen?.(childWindow, id);
    setOpen(true);
  };

  const handleUnload = () => {
    props.onUnload?.();
    setOpen(false);
  };

  useEffect(() => {
    if (open) {
      return () => {
        // Avoid de-registering the window while cleanup effects are running in our subtree.
        setTimeout(() => {
          Windows.unregister(id);
        }, 30);
      };
    }
  }, [open, id]);

  const features: ChildWindowFeatures = useMemo(
    () =>
      ({
        show: !hidden,
        alwaysOnTop: Boolean(alwaysOnTop),
        ...props.features,
        childWindowId: id,
      } as ChildWindowFeatures),
    [hidden, alwaysOnTop, props.features, id]
  );

  useEffect(() => {
    if (open) {
      void applyProps();
    }
  }, [applyProps, open]);

  return (
    <NewWindow
      title={props.name}
      copyStyles={props.copyStyles}
      features={features}
      onOpen={handleOpen}
      onUnload={handleUnload}
      center={props.center as never}
    >
      {open && (
        <ChildWindowNanoidContext.Provider value={id}>
          {props.children}
        </ChildWindowNanoidContext.Provider>
      )}
    </NewWindow>
  );
}
