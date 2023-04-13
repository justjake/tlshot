import { TLShotRecord, TLShotStore } from "./store";

/**
 * Hold non-serializable values related to records in-memory.
 */
export class RecordAttachmentMap<Record extends TLShotRecord, Value> {
  public map = new Map<Record["id"], Value>();
  public readonly dispose: () => void;

  constructor(store: TLShotStore) {
    this.dispose = store.listen(({ changes }) => {
      for (const record of Object.values(changes.removed)) {
        this.map.delete(record.id);
      }
    });
  }
}
