// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

import { contextBridge, ipcRenderer } from "electron";
import type {
  TlshotApi,
  TlshotApiClient,
  TlshotApiRequest,
  TlshotApiResponse,
} from "../main/services";

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
}

contextBridge.exposeInMainWorld("TlshotAPI", new TlshotApiClientImpl());

declare global {
  interface Window {
    TlshotAPI: TlshotApiClient;
  }
}
