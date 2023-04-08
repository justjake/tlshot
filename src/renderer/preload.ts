// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

import { contextBridge, ipcRenderer } from "electron";
import type {
  TlshotApiClient,
  TlshotApiRequest,
  TlshotApiResponse,
} from "../main/services";
import type { DisplaysState } from "./editor/Displays";

class TlshotApiClientImpl implements TlshotApiClient {
  createMethod<T extends keyof TlshotApiClient>(name: T): TlshotApiClient[T] {
    return function asyncMethod(
      ...args: TlshotApiRequest[T]
    ): Promise<TlshotApiResponse[T]> {
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

  onDisplaysChanged = (callback: (state: DisplaysState) => void) => {
    const listener = (_: unknown, state: DisplaysState) => callback(state);
    ipcRenderer.on("displaysChanged", listener);
    return () => ipcRenderer.removeListener("displaysChanged", listener);
  };
}

contextBridge.exposeInMainWorld("TlshotAPI", new TlshotApiClientImpl());

declare global {
  interface Window {
    TlshotAPI: TlshotApiClientImpl;
  }
}
