import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";
import { Display, Rectangle } from "electron";
import {
  DisplayId,
  ChildWindowNanoid,
  BrowserWindowId,
} from "../../main/WindowPositionService";

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
