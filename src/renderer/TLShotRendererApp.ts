import { nanoid } from "nanoid";
import { ChildWindowNanoid } from "../main/WindowDisplayService";
import { AllServiceEvents } from "../main/services";
import { createTLShotStore } from "../shared/store";
import { createContext, useContext } from "react";

export class TLShotRendererApp {
  public readonly rootWindowNanoid = nanoid() as ChildWindowNanoid;
  public readonly api = globalThis.window.TlshotAPI;
  public readonly store = createTLShotStore({
    process: "renderer",
  });

  constructor() {
    this.api.addServiceListener("Service/TLShotStore", this.handleStoreEvent);
    this.api.subscribeToStore(this.rootWindowNanoid);
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
          `Unknown TLShotStore event type: ${(event as any).type}`
        );
    }
  };
}

const TLShotContext = createContext<TLShotRendererApp | undefined>(undefined);
TLShotContext.displayName = "TLShot";

export function useTLShot(): TLShotRendererApp {
  const tlshot = useContext(TLShotContext);
  if (!tlshot) {
    throw new Error("TLShot context not found");
  }
  return tlshot;
}
