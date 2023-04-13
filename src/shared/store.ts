import { RecordsDiff, Store, StoreSchema } from "@tldraw/tlstore";
import { DisplayRecord } from "./records/DisplayRecord";
import { WindowRecord } from "./records/WindowRecord";
import { EditorRecord } from "./records/EditorRecord";
import { CaptureActivityRecord } from "./records/CaptureActivityRecord";
import { computed } from "signia";

export type TLShotRecord =
  | DisplayRecord
  | WindowRecord
  | CaptureActivityRecord
  | EditorRecord;

export type TLShotStoreProps = {
  // Just for fun. Not used.
  process: "main" | "renderer";
};

export type TLShotStore = Store<TLShotRecord, TLShotStoreProps>;

const schema = StoreSchema.create<TLShotRecord, TLShotStoreProps>({
  display: DisplayRecord,
  window: WindowRecord,
  capture: CaptureActivityRecord,
  editor: EditorRecord,
});

export function createTLShotStore(props: TLShotStoreProps) {
  return new Store<TLShotRecord, TLShotStoreProps>({
    props,
    schema,
  });
}

export class TLShotStoreQueries {
  constructor(private store: TLShotStore) {}

  allActivities = computed("allActivities", () => [
    ...this.store.query.records("capture").value,
    ...this.store.query.records("editor").value,
  ]);

  hasActivities = computed(
    "hasActivities",
    () => this.allActivities.value.length > 0
  );
}

export function* iterateChanges(changes: RecordsDiff<TLShotRecord>) {
  for (const added of Object.values(changes.added)) {
    yield [added.id, undefined, added, "added"] as const;
  }
  for (const [before, after] of Object.values(changes.updated)) {
    yield [before.id, before, after, "updated"] as const;
  }
  for (const removed of Object.values(changes.removed)) {
    yield [removed.id, removed, undefined, "removed"] as const;
  }
}
