import { Store, StoreSchema } from "@tldraw/tlstore";
import { DisplayRecord } from "./records/DisplayRecord";
import { WindowRecord } from "./records/WindowRecord";

export type TLShotRecord = DisplayRecord | WindowRecord;

export type TLShotStoreProps = {
  // Just for fun. Not used.
  process: "main" | "renderer";
};

export type TLShotStore = Store<TLShotRecord, TLShotStoreProps>;

const schema = StoreSchema.create<TLShotRecord, TLShotStoreProps>({
  display: DisplayRecord,
  window: WindowRecord,
});

export function createTLShotStore(props: TLShotStoreProps) {
  return new Store<TLShotRecord, TLShotStoreProps>({
    props,
    schema,
  });
}
