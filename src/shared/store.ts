import { RecordsDiff, Store, StoreSchema } from "@tldraw/tlstore";
import { DisplayRecord, DisplayRecordId } from "./records/DisplayRecord";
import { WindowRecord } from "./records/WindowRecord";
import { EditorRecord } from "./records/EditorRecord";
import {
  CAPTURE_ACTIVITY_ID,
  CaptureActivityRecord,
} from "./records/CaptureActivityRecord";
import { computed } from "signia";
import { PreferencesRecord } from "./records/PreferencesRecord";
import { ChildWindowNanoid } from "@/main/WindowDisplayService";

export type TLShotRecord =
  | DisplayRecord
  | WindowRecord
  | CaptureActivityRecord
  | EditorRecord
  | PreferencesRecord;

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
  preferences: PreferencesRecord,
});

export function createTLShotStore(props: TLShotStoreProps) {
  return new Store<TLShotRecord, TLShotStoreProps>({
    props,
    schema,
  });
}

export class TLShotStoreQueries {
  constructor(private store: TLShotStore) {}

  preferences = this.store.query.record("preferences");

  allEditors = this.store.query.records("editor");

  hasEditors = computed("hasEditors", () => this.allEditors.value.length > 0);

  visibleWindows = this.store.query.records("window", () => ({
    isVisible: {
      eq: true,
    },
  }));

  hasCaptureActivity = computed("hasCaptureActivity", () =>
    Boolean(this.store.get(CAPTURE_ACTIVITY_ID))
  );

  hasVisibleWindows = computed(
    "hasVisibleWindows",
    () => this.visibleWindows.value.length > 0
  );

  allActivities = computed("allActivities", () => [
    ...this.store.query.records("capture").value,
    ...this.allEditors.value,
  ]);

  hasActivities = computed(
    "hasActivities",
    () => this.allActivities.value.length > 0
  );

  getWindowDisplay(
    childWindowId: ChildWindowNanoid
  ): DisplayRecord | undefined {
    const windowRecord = this.store.query
      .exec("window", {
        childWindowId: {
          eq: childWindowId,
        },
      })
      .at(0);
    if (!windowRecord) return undefined;

    const displayId = DisplayRecordId.fromDisplayId(windowRecord.displayId);
    return this.store.get(displayId);
  }
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
