import { AllServiceEvents } from "@/main/TLShotApi";
import { TLShotStoreQueries, createTLShotStore } from "@/shared/store";
import { Windows } from "./editor/ChildWindow";
import { DEBUGGING } from "@/shared/debugging";

export class TLShotRendererApp {
  public readonly api = globalThis.window.TlshotAPI;
  public readonly store = createTLShotStore({
    process: "renderer",
  });
  public readonly queries = new TLShotStoreQueries(this.store);
  public readonly ready: Promise<void>;
  private becomeReady!: () => void;

  constructor() {
    this.api.addServiceListener("Service/TLShotStore", this.handleStoreEvent);
    void this.api.subscribeToStore(Windows.ROOT_WINDOW);
    this.store.listen(({ source, changes }) => {
      if (source === "remote") return;
      void this.api.sendStoreUpdate(changes);
    });
    this.ready = new Promise<void>((resolve) => (this.becomeReady = resolve));
  }

  private handleStoreEvent = (
    event: AllServiceEvents["Service/TLShotStore"]
  ) => {
    switch (event.type) {
      case "Init":
        this.store.mergeRemoteChanges(() => {
          this.store.deserialize(event.data);
        });
        this.becomeReady();
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
}

export const TLShot = new TLShotRendererApp();
// eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
DEBUGGING.TLShot = TLShot;
