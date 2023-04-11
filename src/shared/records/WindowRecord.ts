import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";
import { Rectangle } from "electron";
import {
  DisplayId,
  ChildWindowNanoid,
  BrowserWindowId,
} from "../../main/WindowDisplayService";

const WindowRecordTypeName = "window" as const;
type WindowRecordTypeName = typeof WindowRecordTypeName;

export interface WindowRecord extends BaseRecord<WindowRecordTypeName> {
  // Own IDs
  browserWindowId: BrowserWindowId;
  childWindowId: ChildWindowNanoid | undefined;

  // Relationships
  displayId: DisplayId;

  // Info
  bounds: Rectangle;
  isVisible: boolean;
  isAlwaysOnTop: boolean;
}

export type WindowRecordId = ID<WindowRecord>;

export const WindowRecord = createRecordType<WindowRecord>(
  WindowRecordTypeName,
  {
    validator: T.any,
  }
);
