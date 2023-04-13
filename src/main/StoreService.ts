import { RecordsDiff, StoreSnapshot } from "@tldraw/tlstore";
import { TLShotRecord, iterateChanges } from "@/shared/store";
import { Service } from "./Service";
import { MainProcessStore } from "./MainProcessStore";
import {
  CAPTURE_ACTIVITY_ID,
  CaptureActivityRecord,
} from "@/shared/records/CaptureActivityRecord";
import { EditorRecord } from "@/shared/records/EditorRecord";
import { WindowRecord } from "@/shared/records/WindowRecord";
import { DisplayRecord } from "@/shared/records/DisplayRecord";

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
        this.logChanges(source, changes);

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

  handleRendererUpdate(update: RecordsDiff<TLShotRecord>) {
    MainProcessStore.mergeRemoteChanges(() => {
      MainProcessStore.applyDiff(update);
    });
  }

  upsertCaptureActivity(type: CaptureActivityRecord["type"]) {
    MainProcessStore.put([
      CaptureActivityRecord.create({
        id: CAPTURE_ACTIVITY_ID,
        type,
      }),
    ]);
  }

  createEditorWindow() {
    MainProcessStore.put([
      EditorRecord.create({
        filePath: undefined,
        hidden: false,
      }),
    ]);
  }

  private logChanges(
    source: "remote" | "user",
    changes: RecordsDiff<TLShotRecord>
  ) {
    for (const [id, before, after, change] of iterateChanges(changes)) {
      if (
        change === "updated" &&
        (WindowRecord.isId(id) || DisplayRecord.isId(id))
      ) {
        continue;
      }

      console.log(
        `Store: ${source === "remote" ? "renderer" : "main"}/${change}:`,
        id,
        after || before
      );
    }
  }
}
