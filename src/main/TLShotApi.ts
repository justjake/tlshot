import { app, desktopCapturer, ipcMain, screen, BrowserWindow } from "electron";

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
import { MainProcessStore } from "./MainProcessStore";

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

  focusTopWindowNearMouse() {
    const mouse = screen.getCursorScreenPoint();
    const topBrowserWindow = BrowserWindow.getAllWindows().find((bw) => {
      const bounds = bw.getBounds();
      return (
        mouse.x >= bounds.x &&
        mouse.x <= bounds.x + bounds.width &&
        mouse.y >= bounds.y &&
        mouse.y <= bounds.y + bounds.height &&
        bw.isAlwaysOnTop()
      );
    });
    if (!topBrowserWindow) {
      console.log("No window found under mouse", mouse);
    }
    topBrowserWindow?.focus();
    topBrowserWindow?.focusOnWebView();
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

  openDevTools() {
    return this.rootWindowService.openDevTools();
  }

  closeDevTools() {
    return this.rootWindowService.closeDevTools();
  }

  updateChildWindow(
    _event: Electron.IpcMainInvokeEvent,
    id: ChildWindowNanoid,
    options: {
      show?: boolean;
      alwaysOnTop?: boolean | "screen-saver";
    }
  ) {
    const windowRecord = MainProcessStore.query.record("window", () => ({
      childWindowId: {
        eq: id,
      },
    })).value;
    if (!windowRecord) {
      throw new Error(`updateChildWindow: not found: ${id}`);
    }
    const browserWindow = BrowserWindow.fromId(windowRecord.browserWindowId);
    if (!browserWindow) {
      throw new Error(`updateChildWindow: not found: ${id}`);
    }
    for (const [key, value] of Object.entries(options)) {
      if (key === "show") {
        if (value) {
          browserWindow.show();
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
    }
  }
}

export async function startServices() {
  applyContentSecurityPolicy();
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
