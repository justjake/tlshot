import { DisplayId } from "@/main/WindowDisplayService";
import { Rectangle } from "electron";
import { nanoid } from "nanoid";

export const SCREENSHOT_PROTOCOL = "screenshot";

type ScreenshotID = string & { __typename__: "ScreenshotID" };

export function createScreenshotID(): ScreenshotID {
  return nanoid() as ScreenshotID;
}

interface ScreenshotProtocolRequest {
  id: ScreenshotID;
  displayId: DisplayId;
  rect: Rectangle | undefined;
}

export function createScreenshotRequestURL(
  request: ScreenshotProtocolRequest
): URL {
  const url = new URL(`${SCREENSHOT_PROTOCOL}:${request.id}`);
  url.searchParams.append("displayId", JSON.stringify(request.displayId));
  if (request.rect) {
    const jsonRect: Rectangle = {
      x: request.rect.x,
      y: request.rect.y,
      width: request.rect.width,
      height: request.rect.height,
    };
    url.searchParams.append("rect", JSON.stringify(jsonRect));
  }
  return url;
}

export function parseScreenshotRequestURL(url: URL): ScreenshotProtocolRequest {
  if (url.protocol !== `${SCREENSHOT_PROTOCOL}:`) {
    throw new Error(`Not a screenshot protocol URL: ${String(url)}`);
  }
  const id = url.pathname as ScreenshotID;
  const displayId = JSON.parse(url.searchParams.get("displayId")!) as DisplayId;
  const request: ScreenshotProtocolRequest = { id, displayId, rect: undefined };
  const rectString = url.searchParams.get("rect");
  if (rectString) {
    request.rect = JSON.parse(rectString) as Rectangle;
  }
  return request;
}
