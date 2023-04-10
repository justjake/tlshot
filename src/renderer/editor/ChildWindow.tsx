import React, { useEffect, useMemo, useState } from "react";
import NewWindow, { IWindowFeatures } from "react-new-window";
import { ChildWindowNanoid } from "../../main/WindowPositionService";

interface ChildWindowHandle {
  ephemeralId: number;
  webContentsId?: number;
  browserWindowId?: number;
  registered: Promise<void>;
}

class ChildWindowRegistry {
  private nextId = 0;
  private windows = new WeakMap<ChildWindowHandle, Window>();
  private handles = new Set<ChildWindowHandle>();
  private ready = new WeakMap<ChildWindowHandle, () => void>();

  public readonly ROOT_WINDOW = this.createHandle();
  constructor() {
    Object.assign(this.ROOT_WINDOW, { root: true });
    this.register(this.ROOT_WINDOW, globalThis.window);
  }

  createHandle(): ChildWindowHandle {
    const id = this.nextId++;
    const handle: Partial<ChildWindowHandle> = {
      ephemeralId: id,
    };
    handle.registered = new Promise((resolve) => {
      this.ready.set(handle as ChildWindowHandle, resolve);
    });
    return handle as ChildWindowHandle;
  }

  register(handle: ChildWindowHandle, newWindow: Window) {
    this.handles.add(handle);
    this.windows.set(handle, newWindow);
    window.TlshotAPI.getRecentWindowId().then((response) => {
      if (response) {
        for (const otherHandle of this.handles) {
          if (otherHandle.ephemeralId === handle.ephemeralId) {
            continue;
          }

          if (
            otherHandle.webContentsId === response.latestWindow.webContentsId ||
            otherHandle.browserWindowId ===
              response.latestWindow.browserWindowId
          ) {
            console.log("Found existing handle", otherHandle, response);
            return;
          }
        }
        handle.webContentsId = response.latestWindow.webContentsId;
        handle.browserWindowId = response.latestWindow.browserWindowId;
        console.log("Registered handle browserWindowId", handle);
      } else {
        console.log("no window found for handle", handle);
      }
      this.ready.get(handle)?.();
      this.ready.delete(handle);
    });
  }

  unregister(handle: ChildWindowHandle) {
    this.handles.delete(handle);
    this.windows.delete(handle);
  }

  getWindow(handle: ChildWindowHandle): Window {
    const childWindow = this.windows.get(handle);
    if (!childWindow) {
      throw new Error(`Child window ${handle.ephemeralId} not found`);
    }
    return childWindow;
  }
}

export const Windows = new ChildWindowRegistry();

const ChildWindowHandleContext = React.createContext<ChildWindowHandle>(
  Windows.ROOT_WINDOW
);
ChildWindowHandleContext.displayName = "ChildWindow";

interface GetWindowFunction {
  (): Window;
  handle: ChildWindowHandle;
}

export function useGetWindow(): GetWindowFunction {
  const handle = React.useContext(ChildWindowHandleContext);
  return useMemo(() => {
    const getWindow = () => Windows.getWindow(handle);
    getWindow.handle = handle;
    return getWindow;
  }, [handle]);
}

export type ChildWindowFeatures = Electron.BrowserWindowConstructorOptions &
  IWindowFeatures & { childWindowId?: ChildWindowNanoid };

export interface ChildWindowProps {
  name: string;
  copyStyles?: boolean;
  features?: Electron.BrowserWindowConstructorOptions & IWindowFeatures;
  onOpen?: (childWindow: Window, handle: ChildWindowHandle) => void;
  onUnload?: () => void;
  children: React.ReactNode;
  center: "parent" | "screen" | "none";
}

export function ChildWindow(props: ChildWindowProps) {
  const [handle] = useState(() => Windows.createHandle());
  const [open, setOpen] = useState(false);

  const handleOpen = (childWindow: Window) => {
    Windows.register(handle, childWindow);
    props.onOpen?.(childWindow, handle);
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
          Windows.unregister(handle);
        }, 30);
      };
    }
  }, [open, handle]);

  return (
    <NewWindow
      title={props.name}
      copyStyles={props.copyStyles}
      features={props.features}
      onOpen={handleOpen}
      onUnload={handleUnload}
      center={props.center as any}
    >
      {open && (
        <ChildWindowHandleContext.Provider value={handle}>
          {props.children}
        </ChildWindowHandleContext.Provider>
      )}
    </NewWindow>
  );
}
