import { screen, Display, BrowserWindow, WebContents } from "electron";
import { ChildWindowFeatures } from "@/renderer/editor/ChildWindow";
import { MainProcessStore } from "./MainProcessStore";
import { WindowRecord, WindowRecordId } from "@/shared/records/WindowRecord";
import { DisplayRecord } from "@/shared/records/DisplayRecord";
import { Service } from "./Service";

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

export class WindowDisplayService extends Service<
  "Services/WindowDisplay",
  Record<string, never>
> {
  constructor() {
    super("Services/WindowDisplay", () => {
      const handleDisplayChanged = (_event: unknown, display: Display) => {
        this.handleDisplayChanged(display);
      };
      const handleDisplayRemoved = (_event: unknown, display: Display) => {
        this.handleDisplayRemoved(display);
      };
      screen.on("display-added", handleDisplayChanged);
      screen.on("display-metrics-changed", handleDisplayChanged);
      screen.on("display-removed", handleDisplayRemoved);

      MainProcessStore.put([
        ...screen
          .getAllDisplays()
          .map((display) => this.getDisplayRecord(display)),
        ...BrowserWindow.getAllWindows().map((browserWindow) =>
          this.getWindowRecord(browserWindow)
        ),
      ]);

      return () => {
        screen.off("display-added", handleDisplayChanged);
        screen.off("display-metrics-changed", handleDisplayChanged);
        screen.off("display-removed", handleDisplayRemoved);

        // TODO: should we remove all the Display / Window records?
      };
    });
  }

  windowRecordId(id: BrowserWindowId) {
    return WindowRecord.createCustomId(String(id));
  }

  displayRecordId(id: DisplayId) {
    return DisplayRecord.createCustomId(String(id));
  }

  addSubscriberAndUpdateWindow(
    subscriber: WebContents,
    ownId: ChildWindowNanoid
  ) {
    const browserWindow: BrowserWindow | null =
      BrowserWindow.fromWebContents(subscriber);
    if (!browserWindow) {
      return;
    }

    // TODO: what about if the window's webcontents reload - then there'll be a new call w/ a new ownId,
    // but it's the same browser window 🧐
    if (browserWindow.childWindowId && browserWindow.childWindowId !== ownId) {
      console.warn(
        `BrowserWindow(${browserWindow.id}): Changing childWindowId from ${browserWindow.childWindowId} to ${ownId}`
      );
    }

    browserWindow.childWindowId = ownId;
    this.handleWindowChanged(browserWindow);

    this.addSubscriber(subscriber);
  }

  handleDisplayChanged(display: Electron.Display) {
    MainProcessStore.put([this.getDisplayRecord(display)]);
  }

  handleDisplayRemoved(display: Electron.Display) {
    MainProcessStore.remove([this.displayRecordId(display.id)]);
  }

  getDisplayRecord(display: Display): DisplayRecord {
    return DisplayRecord.create({
      ...display,
      id: this.displayRecordId(display.id),
      displayId: display.id,
    });
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
    const id = this.windowRecordId(browserWindow.id);
    browserWindow.on("closed", () => {
      this.handleWindowClosed(id);
    });

    this.handleWindowChanged(browserWindow);
  }

  handleWindowChanged(browserWindow: BrowserWindow) {
    MainProcessStore.put([this.getWindowRecord(browserWindow)]);
  }

  handleWindowClosed(id: WindowRecordId) {
    MainProcessStore.remove([id]);
  }

  getWindowRecord(browserWindow: BrowserWindow): WindowRecord {
    const display = screen.getDisplayMatching(browserWindow.getBounds());
    return WindowRecord.create({
      id: this.windowRecordId(browserWindow.id),
      browserWindowId: browserWindow.id,
      childWindowId: browserWindow.childWindowId,
      displayId: display.id as DisplayId,
      bounds: browserWindow.getBounds(),
      isVisible: browserWindow.isVisible(),
      isAlwaysOnTop: browserWindow.isAlwaysOnTop(),
    });
  }
}
