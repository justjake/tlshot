// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

import { contextBridge, ipcRenderer } from "electron";
import type {
  TlshotApiClient,
  TlshotApiRequest,
  TlshotApiResponse,
} from "../main/services";
import type { DisplaysState } from "./editor/Displays";
import {
  WindowsAndDisplays,
  ChildWindowNanoid,
  WindowPositionServiceEvent,
} from "../main/WindowPositionService";

class TlshotApiClientImpl implements TlshotApiClient {
  createMethod<T extends keyof TlshotApiClient>(name: T): TlshotApiClient[T] {
    return function asyncMethod(
      ...args: TlshotApiRequest[T]
    ): Promise<TlshotApiResponse[T]> {
      console.warn("TlshotApiClient: call:", name, args);
      return ipcRenderer.invoke(name, ...args);
    } as any;
  }

  getSources = this.createMethod("getSources");
  getCurrentDisplay = this.createMethod("getCurrentDisplay");
  getRecentWindowId = this.createMethod("getRecentWindowId");
  setAlwaysOnTop = this.createMethod("setAlwaysOnTop");
  subscribeToDisplays = this.createMethod("subscribeToDisplays");
  captureAllDisplays = this.createMethod("captureAllDisplays");
  getDisplaySource = this.createMethod("getDisplaySource");
  focusTopWindowNearMouse = this.createMethod("focusTopWindowNearMouse");
  subscribeToWindowPositionService = this.createMethod(
    "subscribeToWindowPositionService"
  );

  onDisplaysChanged = (callback: (state: DisplaysState) => void) => {
    const listener = (_: unknown, state: DisplaysState) => callback(state);
    ipcRenderer.on("displaysChanged", listener);
    return () => ipcRenderer.removeListener("displaysChanged", listener);
  };

  onWindowOrDisplayChanged = (
    ownId: ChildWindowNanoid,
    callback: (state: WindowsAndDisplays) => void
  ) => {
    let state: WindowsAndDisplays = {
      windows: {},
      displays: {},
    };

    const listener = (_: unknown, event: WindowPositionServiceEvent) => {
      let newState = {
        windows: { ...state.windows },
        displays: { ...state.displays },
      };
      switch (event.type) {
        case "display-changed":
          newState.displays[event.data.id] = event.data;
          break;
        case "window-changed":
          newState.windows[event.data.browserWindowId] = event.data;
          break;
        case "display-removed":
          delete newState.displays[event.data];
          break;
        case "window-removed":
          delete newState.windows[event.data];
          break;
        case "window-display-subscribed":
          newState = event.data;
          break;
      }
      state = newState;
      callback(state);
    };

    ipcRenderer.on("WindowPositionService", listener);
    void this.subscribeToWindowPositionService(ownId);
  };
}

contextBridge.exposeInMainWorld("TlshotAPI", new TlshotApiClientImpl());

declare global {
  interface Window {
    TlshotAPI: TlshotApiClientImpl;
  }
}
