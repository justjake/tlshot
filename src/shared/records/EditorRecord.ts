import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";

const EditorRecordTypeName = "editor" as const;
type EditorRecordTypeName = typeof EditorRecordTypeName;
export type EditorRecordId = ID<EditorRecord>;

export interface EditorRecord extends BaseRecord<EditorRecordTypeName> {
  // Placeholder stuff, just for brainstorming.
  hidden: boolean;
  filePath: string | undefined;
}

export const EditorRecord = createRecordType<EditorRecord>(
  EditorRecordTypeName,
  {
    validator: T.any,
  }
);
