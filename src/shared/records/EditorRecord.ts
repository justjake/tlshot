import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";
import { PreferencesRecord } from "./PreferencesRecord";
import path from "path";
import { DisplayRecordId } from "./DisplayRecord";
import { Rectangle, Size } from "electron";

const EditorRecordTypeName = "editor" as const;
type EditorRecordTypeName = typeof EditorRecordTypeName;
export type EditorRecordId = ID<EditorRecord>;

export interface EditorRecord extends BaseRecord<EditorRecordTypeName> {
  hidden: boolean;
  filePath: string | undefined;
  createdAt: number | undefined;
  targetBounds?: Size & Partial<Rectangle>;
  targetDisplay?: DisplayRecordId;
}

export const EditorRecord = createRecordType<EditorRecord>(
  EditorRecordTypeName,
  {
    validator: T.any,
  }
);

export function getDefaultFilePath(
  preferences: PreferencesRecord,
  createdAt: number
) {
  const date = new Date(createdAt);
  // Produce a filename like TLShot 2022-02-23 at 3.50.30 PM.png
  const pad = (num: number) => num.toString().padStart(2, "0");
  const filename = `TLShot ${date.getFullYear()}-${pad(
    date.getMonth() + 1
  )}-${pad(date.getDate())} at ${date.getHours() % 12}.${pad(
    date.getMinutes()
  )}.${pad(date.getSeconds())} ${date.getHours() > 12 ? "PM" : "AM"}.png`;
  return path.join(preferences.saveLocation, filename);
}
