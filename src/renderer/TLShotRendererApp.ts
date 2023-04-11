import { AllServiceEvents } from "@/main/services";
import { createTLShotStore } from "@/shared/store";
import { Windows } from "./editor/ChildWindow";
import { DEBUGGING } from "@/shared/debugging";

export class TLShotRendererApp {
  public readonly api = globalThis.window.TlshotAPI;
  public readonly store = createTLShotStore({
    process: "renderer",
  });

  constructor() {
    this.api.addServiceListener("Service/TLShotStore", this.handleStoreEvent);
    void this.api.subscribeToStore(Windows.ROOT_WINDOW);
  }

  private handleStoreEvent = (
    event: AllServiceEvents["Service/TLShotStore"]
  ) => {
    switch (event.type) {
      case "Init":
        this.store.mergeRemoteChanges(() => {
          this.store.deserialize(event.data);
        });
        break;
      case "Changes":
        this.store.mergeRemoteChanges(() => {
          this.store.applyDiff(event.data);
        });
        break;
      default:
        throw new Error(
          `Unknown TLShotStore event type: ${(event as { type: string }).type}`
        );
    }
  };

  private queries() {
    this.store.query.record("window", () => ({
      childWindowId: {
        eq: Windows.ROOT_WINDOW,
      },
    }));
  }
}

export const TLShot = new TLShotRendererApp();
// eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
DEBUGGING.TLShot = TLShot;
