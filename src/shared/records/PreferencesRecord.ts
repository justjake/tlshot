import { Preferences } from "@/main/MainProcessPreferences";
import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";

const PreferencesRecordTypeName = "preferences" as const;
type PreferencesRecordTypeName = typeof PreferencesRecordTypeName;
export type PreferencesRecordId = ID<PreferencesRecord>;

export interface PreferencesRecord
  extends BaseRecord<PreferencesRecordTypeName>,
    Preferences {}

export const PreferencesRecord = createRecordType<PreferencesRecord>(
  PreferencesRecordTypeName,
  {
    validator: T.any,
  }
);

export const PREFERENCES_ID = PreferencesRecord.createCustomId("singleton");
