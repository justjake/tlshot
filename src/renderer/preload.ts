// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

import { contextBridge, ipcRenderer } from "electron";
import type {
  AllServiceEvents,
  TlshotApiClient,
  TlshotApiRequest,
  TlshotApiResponse,
} from "@/main/services";

const DEBUG = true;

class TlshotApiClientImpl implements TlshotApiClient {
  createMethod<T extends keyof TlshotApiClient>(name: T): TlshotApiClient[T] {
    return function asyncMethod(
      ...args: TlshotApiRequest[T]
    ): Promise<TlshotApiResponse[T]> {
      if (DEBUG) {
        console.warn("TlshotApiClient: call:", name, args);
      }
      return ipcRenderer.invoke(name, ...args) as Promise<TlshotApiResponse[T]>;
    } as any as TlshotApiClient[T];
  }

  getSources = this.createMethod("getSources");
  getCurrentDisplay = this.createMethod("getCurrentDisplay");
  setAlwaysOnTop = this.createMethod("setAlwaysOnTop");
  captureAllDisplays = this.createMethod("captureAllDisplays");
  getDisplaySource = this.createMethod("getDisplaySource");
  focusTopWindowNearMouse = this.createMethod("focusTopWindowNearMouse");
  subscribeToStore = this.createMethod("subscribeToStore");

  addServiceListener = <ChannelName extends keyof AllServiceEvents>(
    channelName: ChannelName,
    handler: (event: AllServiceEvents[ChannelName]) => void
  ) => {
    const listener = (_: unknown, event: AllServiceEvents[ChannelName]) => {
      if (DEBUG) {
        console.warn(
          "TlshotApiClient: event:",
          channelName,
          event.type,
          event.data
        );
      }
      handler(event);
    };
    ipcRenderer.on(channelName, listener);
    return () => ipcRenderer.removeListener(channelName, listener);
  };
}

contextBridge.exposeInMainWorld("TlshotAPI", new TlshotApiClientImpl());

declare global {
  interface Window {
    TlshotAPI: TlshotApiClientImpl;
  }
}
