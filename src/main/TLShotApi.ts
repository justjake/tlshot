import {
  app,
  desktopCapturer,
  ipcMain,
  screen,
  BrowserWindow,
  dialog,
  SaveDialogOptions,
  SaveDialogReturnValue,
  clipboard,
} from "electron";
import fs from "fs-extra";
import path from "path";
import { Box2d, Vec2d } from "@tldraw/primitives";

import {
  ChildWindowNanoid,
  WindowDisplayService,
} from "./WindowDisplayService";
import { StoreService } from "./StoreService";
import { AnyServiceEvent, Service } from "./Service";
import { applyContentSecurityPolicy } from "./contentSecurityPolicy";
import { installDevtoolsExtensions } from "./devtools";
import { RecordsDiff } from "@tldraw/tlstore";
import { TLShotRecord } from "@/shared/store";
import { RootWindowService } from "./RootWindowService";
import { objectEntries } from "@/shared/typeUtils";
import { enableScreenshotProtocol } from "./screenshotServer";

export type TLShotApiResponse = {
  [K in keyof TLShotApi]: TLShotApi[K] extends (...args: any) => infer R
    ? Awaited<R>
    : never;
};

export type TLShotApiRequest = {
  [K in keyof TLShotApi]: TLShotApi[K] extends (
    first: any,
    ...rest: infer R
  ) => any
    ? R
    : never;
};

export type TLShotApiClient = {
  [K in keyof TLShotApi as TLShotApi[K] extends (...args: any) => any
    ? K
    : never]: (...args: TLShotApiRequest[K]) => Promise<TLShotApiResponse[K]>;
};

export type CaptureSource = TLShotApiResponse["getSources"][number];

interface DialogKind {
  open: {
    req: Electron.OpenDialogOptions;
    res: Electron.OpenDialogReturnValue;
  };
  save: {
    req: Electron.SaveDialogOptions;
    res: Electron.SaveDialogReturnValue;
  };
}

export class TLShotApi {
  private static instance: TLShotApi | undefined;
  static getInstance() {
    if (!this.instance) {
      this.instance = new TLShotApi();
      this.connect(this.instance);
    }
    return this.instance;
  }

  // https://www.electronjs.org/docs/latest/api/ipc-renderer#ipcrendererinvokechannel-args
  private static connect(instance: TLShotApi) {
    const methodNames = Object.getOwnPropertyNames(
      TLShotApi.prototype
    ) as Array<keyof TLShotApi>;

    console.log("methodNames", methodNames);

    for (const methodName of methodNames) {
      if (methodName === ("constructor" as any)) continue;

      const method = instance[methodName];
      if (typeof method !== "function") continue;

      console.log("TLShotApi: connecting method:", methodName, method);
      ipcMain.handle(methodName, method.bind(instance));
    }
  }

  public storeService = new StoreService();
  public windowDisplayService = new WindowDisplayService();
  public rootWindowService = new RootWindowService();

  log(_event: Electron.IpcMainInvokeEvent, ...msg: unknown[]) {
    console.log("Renderer:", ...msg);
  }

  getMousePosition() {
    const screenPoint = screen.getCursorScreenPoint();
    const display = screen.getDisplayNearestPoint(screenPoint);
    const windows = BrowserWindow.getAllWindows();
    const getScore = (bw: BrowserWindow) => {
      let score = 0;
      const bounds = bw.getBounds();
      const box = Box2d.From({
        x: bounds.x,
        y: bounds.y,
        h: bounds.height,
        w: bounds.width,
      });
      if (box.containsPoint(screenPoint)) score += 500;
      if (screen.getDisplayMatching(box).id === display.id) score += 200;
      if (bw.isAlwaysOnTop()) score += 100;
      const distance = Vec2d.Dist(screenPoint, box.center);
      score += 99 / (distance + 1);
      return score;
    };
    const topWindow = windows.sort((a, b) => getScore(b) - getScore(a)).at(0);
    const windowPoint =
      topWindow && Vec2d.From(screenPoint).sub(topWindow.getBounds());
    return {
      screenPoint,
      windowPoint: windowPoint?.toJson(),
      closestWindowId: topWindow?.id,
      closestDisplayId: display.id,
    };
  }

  focusTopWindowNearMouse() {
    const pos = this.getMousePosition();
    const topBrowserWindow =
      typeof pos.closestWindowId === "number" &&
      BrowserWindow.fromId(pos.closestWindowId);
    if (topBrowserWindow) {
      topBrowserWindow?.focus();
      topBrowserWindow?.focusOnWebView();
      console.log("closest", pos);
    } else {
      console.log("No window found under mouse", pos);
    }
  }

  focusWindow(_event: Electron.IpcMainInvokeEvent, id: ChildWindowNanoid) {
    const browserWindow = this.windowDisplayService.mustGetBrowserWindow(id);
    browserWindow.focus();
    browserWindow.focusOnWebView();
  }

  // https://www.electronjs.org/docs/latest/api/desktop-capturer
  async getSources() {
    const sources = await desktopCapturer.getSources({
      types: ["window", "screen"],
      fetchWindowIcons: true,
      thumbnailSize: {
        width: 500,
        height: 500,
      },
    });
    return sources.map((source) => ({
      ...source,
      appIcon: source.appIcon?.toDataURL() || undefined,
      thumbnail: source.thumbnail?.toDataURL(),
    }));
  }

  async getDisplaySource(
    _event: Electron.IpcMainInvokeEvent,
    displayId: number
  ) {
    const sources = await desktopCapturer.getSources({
      types: ["screen"],
      fetchWindowIcons: false,
      thumbnailSize: {
        width: 0,
        height: 0,
      },
    });

    const source = sources.find(
      (source) => source.display_id === String(displayId)
    );
    if (!source) {
      throw new Error(`No source found for display ${displayId}`);
    }

    return {
      ...source,
      appIcon: undefined,
      thumbnail: undefined,
    };
  }

  async saveDialog(
    _event: Electron.IpcMainInvokeEvent,
    childWindowId: ChildWindowNanoid,
    options: SaveDialogOptions
  ): Promise<SaveDialogReturnValue> {
    return dialog.showSaveDialog(
      this.windowDisplayService.mustGetBrowserWindow(childWindowId),
      options
    );
  }

  async writeFile(
    _event: Electron.IpcMainInvokeEvent,
    filePath: string,
    contents: ArrayBuffer
  ) {
    await fs.mkdirp(path.dirname(filePath));
    await fs.writeFile(filePath, Buffer.from(contents));
  }

  writeClipboardPlaintext(_event: Electron.IpcMainInvokeEvent, text: string) {
    clipboard.writeText(text);
  }

  getCurrentDisplay() {
    return screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
  }

  subscribeToStore(
    event: Electron.IpcMainInvokeEvent,
    childWindowId: ChildWindowNanoid
  ) {
    this.storeService.addSubscriber(event.sender);
    this.windowDisplayService.addSubscriberAndUpdateWindow(
      event.sender,
      childWindowId
    );
  }

  sendStoreUpdate(
    _event: Electron.IpcMainInvokeEvent,
    data: RecordsDiff<TLShotRecord>
  ) {
    this.storeService.handleRendererUpdate(data);
  }

  quit() {
    app.quit();
  }

  captureArea() {
    this.storeService.upsertCaptureActivity("area");
  }

  captureWindow() {
    this.storeService.upsertCaptureActivity("window");
  }

  captureFullscreen() {
    this.storeService.upsertCaptureActivity("fullScreen");
  }

  cancelCapture() {
    this.storeService.removeCaptureActivity();
  }

  openDevTools(_: unknown, options = { once: false }) {
    return this.rootWindowService.openDevTools(options);
  }

  closeDevTools() {
    return this.rootWindowService.closeDevTools();
  }

  updateChildWindow(
    _event: Electron.IpcMainInvokeEvent,
    id: ChildWindowNanoid,
    options: {
      show?: boolean | "showInactive";
      alwaysOnTop?: boolean | "screen-saver";
      edited?: boolean;
    }
  ) {
    const browserWindow =
      TLShotApi.getInstance().windowDisplayService.mustGetBrowserWindow(id);
    for (const [key, value] of objectEntries(options)) {
      if (key === "show") {
        if (value) {
          if (value === "showInactive") {
            browserWindow.showInactive();
          } else {
            browserWindow.show();
          }
        } else {
          browserWindow.hide();
        }
      }

      if (key === "alwaysOnTop") {
        browserWindow.setAlwaysOnTop(
          Boolean(value),
          typeof value === "string" ? value : undefined,
          value === "screen-saver" ? 1 : undefined
        );
      }

      if (key === "edited") {
        browserWindow.setDocumentEdited(Boolean(value));
      }
    }
  }
}

export async function startServices() {
  applyContentSecurityPolicy();
  enableScreenshotProtocol();
  await installDevtoolsExtensions();
  TLShotApi.getInstance();
}

export type AllServices = {
  [K in WindowDisplayService["channelName"]]: WindowDisplayService;
} & {
  [K in StoreService["channelName"]]: StoreService;
};

export type AllServiceEvents = {
  [K in keyof AllServices]: AllServices[K] extends Service<any, infer E>
    ? AnyServiceEvent<E>
    : never;
};
