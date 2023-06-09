// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

import { contextBridge, ipcRenderer } from "electron";
import type {
  AllServiceEvents,
  TLShotApiClient,
  TLShotApiRequest,
  TLShotApiResponse,
} from "@/main/TLShotApi";

const DEBUG = true;

class TlshotApiClientImpl implements TLShotApiClient {
  createMethod<T extends keyof TLShotApiClient>(name: T): TLShotApiClient[T] {
    return function asyncMethod(
      ...args: TLShotApiRequest[T]
    ): Promise<TLShotApiResponse[T]> {
      if (DEBUG) {
        console.warn("TlshotApiClient: call:", name, args);
      }
      return ipcRenderer.invoke(name, ...args) as Promise<TLShotApiResponse[T]>;
    } as any as TLShotApiClient[T];
  }

  // nativeCaptureDisplayToFile = captureDisplayToFile;
  // readImage = async (fileName: string) => {
  //   const buf = await readFile(fileName)
  //   return new Blob([buf], { type: 'image/png' })
  // }

  getSources = this.createMethod("getSources");
  getCurrentDisplay = this.createMethod("getCurrentDisplay");
  getDisplaySource = this.createMethod("getDisplaySource");
  focusTopWindowNearMouse = this.createMethod("focusTopWindowNearMouse");
  subscribeToStore = this.createMethod("subscribeToStore");
  sendStoreUpdate = this.createMethod("sendStoreUpdate");
  log = this.createMethod("log");
  openDevTools = this.createMethod("openDevTools");
  closeDevTools = this.createMethod("closeDevTools");
  updateChildWindow = this.createMethod("updateChildWindow");
  quit = this.createMethod("quit");
  captureArea = this.createMethod("captureArea");
  captureWindow = this.createMethod("captureWindow");
  captureFullscreen = this.createMethod("captureFullscreen");
  saveDialog = this.createMethod("saveDialog");
  writeFile = this.createMethod("writeFile");
  getMousePosition = this.createMethod("getMousePosition");
  cancelCapture = this.createMethod("cancelCapture");
  focusWindow = this.createMethod("focusWindow");

  // TODO: color copying is still busted...
  writeClipboardPlaintext = this.createMethod("writeClipboardPlaintext");

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
