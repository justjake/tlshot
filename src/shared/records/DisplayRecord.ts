import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";
import { Display } from "electron";
import { DisplayId } from "../../main/WindowDisplayService";

const DisplayRecordTypeName = "display" as const;
type DisplayRecordTypeName = typeof DisplayRecordTypeName;

export interface DisplayRecord
  extends BaseRecord<DisplayRecordTypeName>,
    Omit<Display, "id"> {
  // Own IDs
  displayId: DisplayId;
}

export type DisplayRecordId = ID<DisplayRecord>;

export const DisplayRecord = createRecordType<DisplayRecord>(
  DisplayRecordTypeName,
  {
    validator: T.any,
  }
);
