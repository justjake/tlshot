// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

import { contextBridge, ipcRenderer } from "electron";
import type { TlshotApi } from "../main/services";

class TlshotApiClient implements TlshotApi {
  createMethod<T extends keyof TlshotApi>(name: T): TlshotApi[T] {
    type Method = TlshotApi[T];
    return function asyncMethod(
      ...args: Parameters<Method>
    ): ReturnType<Method> {
      return ipcRenderer.invoke(name, ...args) as any;
    } as any;
  }

  getSources = this.createMethod("getSources");
  getCurrentDisplay = this.createMethod("getCurrentDisplay");
  getRecentWindowId = this.createMethod("getRecentWindowId");
  setAlwaysOnTop = this.createMethod("setAlwaysOnTop");
}

contextBridge.exposeInMainWorld("TlshotAPI", new TlshotApiClient());

declare global {
  interface Window {
    TlshotAPI: TlshotApi;
  }
}
