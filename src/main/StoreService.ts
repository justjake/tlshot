import { RecordsDiff, StoreSnapshot } from "@tldraw/tlstore";
import { TLShotRecord } from "@/shared/store";
import { Service } from "./Service";
import { MainProcessStore } from "./MainProcessStore";

type TLShotStoreEvents = {
  Init: StoreSnapshot<TLShotRecord>;
  Changes: RecordsDiff<TLShotRecord>;
};

export class StoreService extends Service<
  "Service/TLShotStore",
  TLShotStoreEvents
> {
  constructor() {
    super("Service/TLShotStore", () => {
      return MainProcessStore.listen(({ changes, source }) => {
        if (source === "remote") {
          return;
        }

        this.emit({ type: "Changes", data: changes });
      });
    });
  }

  addSubscriber(subscriber: Electron.WebContents): void {
    super.addSubscriber(subscriber);
    this.emit({ type: "Init", data: MainProcessStore.serialize() });
  }
}
