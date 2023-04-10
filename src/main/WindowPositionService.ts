import {
  screen,
  Display,
  BrowserWindow,
  webContents,
  WebContents,
} from "electron";
import { nanoid } from "nanoid";
import { ChildWindowFeatures } from "../renderer/editor/ChildWindow";

export type WebContentsId = number & { __typename__?: "WebContents" };
export type BrowserWindowId = number & { __typename__?: "BrowserWindow" };
export type DisplayId = number & { __typename__?: "Display" };

/**
 * When we create a new window from within a WebContents with the ChildWindow
 * component inside the renderer process, we don't have access to the newly
 * created window's BrowserWindow instance or a way to associate the renderer
 * window with the BrowserWindow once it's created.
 *
 * To add some linkage, we can add a custom ID property to the "features" object
 * inside the renderer, which is visible in did-create-window event on the
 * parent's WebContents.
 *
 * This is the type of that ID.
 */
export type ChildWindowNanoid = string /* nanoid */ & {
  __typename__?: "ChildWindowNanoid";
};

declare module "electron" {
  interface BrowserWindow {
    id: BrowserWindowId;
    childWindowId?: ChildWindowNanoid;
  }
}

export interface DisplayInfo extends Display {
  id: DisplayId;
}

export interface BrowserWindowInfo {
  // IDs
  browserWindowId: BrowserWindowId;
  childWindowId: ChildWindowNanoid | undefined;

  // Relationships
  displayId: DisplayId;

  // Info
  bounds: Electron.Rectangle;
  isVisible: boolean;
  isAlwaysOnTop: boolean;
}

export interface WindowsAndDisplays {
  windows: {
    [id in BrowserWindowId]: BrowserWindowInfo;
  };
  displays: {
    [id in DisplayId]: DisplayInfo;
  };
}

export type WindowPositionServiceEvents = {
  "window-display-subscribed": WindowsAndDisplays;
  "window-changed": BrowserWindowInfo;
  "window-removed": BrowserWindowId;
  "display-changed": DisplayInfo;
  "display-removed": DisplayId;
};

export type WindowPositionServiceEvent = {
  [K in keyof WindowPositionServiceEvents]: {
    type: K;
    data: WindowPositionServiceEvents[K];
  };
}[keyof WindowPositionServiceEvents];

export class WindowPositionService {
  subscribers = new Set<WebContents>();

  constructor() {
    screen.on("display-added", (_event, display) =>
      this.handleDisplayChanged(display)
    );
    screen.on("display-metrics-changed", (_event, display) =>
      this.handleDisplayChanged(display)
    );
    screen.on("display-removed", (_event, display) =>
      this.handleDisplayRemoved(display)
    );
  }

  addSubscriber(subscriber: WebContents, ownId: ChildWindowNanoid) {
    const browserWindow: BrowserWindow | null =
      BrowserWindow.fromWebContents(subscriber);
    if (!browserWindow) {
      return;
    }

    if (browserWindow.childWindowId && browserWindow.childWindowId !== ownId) {
      throw new Error(
        `BrowserWindow already has a childWindowId: ${browserWindow.childWindowId}`
      );
    }

    browserWindow.childWindowId = ownId;
    this.handleWindowChanged(browserWindow);

    this.subscribers.add(subscriber);
    subscriber.once("destroyed", () => {
      this.subscribers.delete(subscriber);
    });

    this.dispatch("window-display-subscribed", this.getWindowsAndDisplays());
  }

  handleDisplayChanged(display: Electron.Display) {
    this.dispatch("display-changed", display);
  }

  handleDisplayRemoved(display: Electron.Display) {
    this.dispatch("display-removed", display.id);
  }

  handleWindowCreated(
    browserWindow: BrowserWindow,
    features: ChildWindowFeatures | undefined
  ) {
    const childId = features?.childWindowId;
    if (childId) {
      // this.webIdToBrowserId.set(childId, browserWindow.id as BrowserWindowId);
      browserWindow.childWindowId = childId;
      // browserWindow.once("closed", () => {
      //   this.webIdToBrowserId.delete(childId);
      // });
    }

    // Follow newly created windows
    browserWindow.webContents.on("did-create-window", (newWindow, details) => {
      this.handleWindowCreated(
        newWindow,
        details.options as ChildWindowFeatures
      );
    });

    // Follow window positioning
    browserWindow.on("moved", () => {
      this.handleWindowChanged(browserWindow);
    });
    browserWindow.on("resized", () => {
      this.handleWindowChanged(browserWindow);
    });
    browserWindow.on("closed", () => {
      this.handleWindowClosed(browserWindow);
    });

    this.handleWindowChanged(browserWindow);
  }

  handleWindowChanged(browserWindow: BrowserWindow) {
    this.dispatch("window-changed", this.getBrowserWindowInfo(browserWindow));
  }

  handleWindowClosed(browserWindow: BrowserWindow) {
    this.dispatch("window-removed", browserWindow.id);
  }

  getBrowserWindowInfo(browserWindow: BrowserWindow): BrowserWindowInfo {
    const display = screen.getDisplayMatching(browserWindow.getBounds());
    return {
      browserWindowId: browserWindow.id as BrowserWindowId,
      childWindowId: browserWindow.childWindowId,
      displayId: display.id as DisplayId,
      bounds: browserWindow.getBounds(),
      isVisible: browserWindow.isVisible(),
      isAlwaysOnTop: browserWindow.isAlwaysOnTop(),
    };
  }

  getWindowsAndDisplays(): WindowsAndDisplays {
    const result: WindowsAndDisplays = {
      windows: {},
      displays: {},
    };
    for (const bw of BrowserWindow.getAllWindows()) {
      result.windows[bw.id] = this.getBrowserWindowInfo(bw);
    }
    for (const display of screen.getAllDisplays()) {
      result.displays[display.id] = display;
    }
    return result;
  }

  private dispatch<T extends keyof WindowPositionServiceEvents>(
    event: T,
    info: WindowPositionServiceEvents[T]
  ) {
    console.log(`WindowPositionService: ${event}:`, info);
    this.subscribers.forEach((wc) =>
      wc.send("WindowPositionService", { type: event, data: info })
    );
  }
}