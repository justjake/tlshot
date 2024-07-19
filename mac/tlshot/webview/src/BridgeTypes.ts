export interface BridgeEnvironment {
  appName: string;
  theme: "dark" | "light";
  initialAsset: BridgeImageAssetProps | undefined;
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

interface SaveRequest {
  saveId: string;
}

interface SaveResponse {
  svg: string;
  width: number;
  height: number;
}

export interface ResponseNotification {
  requestId: string;
  type: BridgeIncomingType;
  error: BridgeErrorLike | null;
  json: string | null;
  httpUpload: boolean;
}

export interface BridgeNotificationMap {
  debug: DebugNotification;
  booted: BootedNotification;
  response: ResponseNotification;
}

export interface BridgeRequestMap {
  getName: {
    request: GetNameRequest;
    response: GetNameResponse;
  };
  createSvgAsset: {
    request: CreateSvgRequest;
    response: CreateSvgResponse;
  };
}

export interface BridgeIncomingMap {
  save: {
    request: SaveRequest;
    response: SaveResponse;
  };
}

export interface BridgeIncomingEnvelope {
  type: BridgeIncomingType;
  requestId: string;
  json: string;
}

export type BridgeNotificationType = keyof BridgeNotificationMap;
export type BridgeRequestType = keyof BridgeRequestMap;
export type BridgeIncomingType = keyof BridgeIncomingMap;

export type BridgeImageAssetProps = {
  name: string;
  fileSize: number;
  w: number;
  h: number;
  src: string;
  mimeType: string;
  isAnimated: boolean;
};

export enum BridgeProtocol {
  httpResponse = "tlshot-response",
  asset = "asset",
}

export interface CreateSvgRequest {
  assetId: string;
  svgText: string;
}

export interface CreateSvgResponse {
  assetUrl: string;
}
