import { BaseRecord, ID, createRecordType } from "@tldraw/tlstore";
import { T } from "@tldraw/tlvalidate";

const CaptureActivityRecordTypeName = "capture" as const;
type CaptureActivityRecordTypeName = typeof CaptureActivityRecordTypeName;
export type CaptureActivityRecordId = ID<CaptureActivityRecord>;

export interface CaptureActivityRecord
  extends BaseRecord<CaptureActivityRecordTypeName> {
  type: "window" | "area" | "fullScreen";
}

export const CaptureActivityRecord = createRecordType<CaptureActivityRecord>(
  CaptureActivityRecordTypeName,
  {
    validator: T.any,
  }
);

export const CAPTURE_ACTIVITY_ID =
  CaptureActivityRecord.createCustomId("singleton");
