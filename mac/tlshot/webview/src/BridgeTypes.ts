export interface BridgeEnvironment {
  appName: string;
  theme: "dark" | "light";
  initialFileURL?: string;
}

export interface BootedNotification {
  time: number;
}

export interface BridgeErrorLike {
  name: string;
  message: string;
  stack: string;
}

export type DebugNotification =
  | { type: "console"; method: "log" | "error" | "debug"; message: string[] }
  | { type: "unhandledRejection"; error: BridgeErrorLike }
  | { type: "error"; error: BridgeErrorLike };

export interface GetNameRequest {}
export interface GetNameResponse {
  name: string;
}

export interface BridgeNotificationMap {
  debug: DebugNotification;
  booted: BootedNotification;
}

export interface BridgeRequestMap {
  getName: {
    request: GetNameRequest;
    response: GetNameResponse;
  };
}

export type BridgeNotificationType = keyof BridgeNotificationMap;
export type BridgeRequestType = keyof BridgeRequestMap;
