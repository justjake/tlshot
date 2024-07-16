import {
  BootedNotification,
  BridgeEnvironment,
  BridgeErrorLike,
  BridgeNotificationMap,
  BridgeNotificationType,
  BridgeRequestMap,
  BridgeRequestType,
  DebugNotification,
  GetNameRequest,
  GetNameResponse,
} from "./BridgeTypes";

// Things that exist

declare const __BRIDGE_ENVIRONMENT__: BridgeEnvironment;

type TODO = unknown;
// https://developer.apple.com/documentation/webkit/wkscriptmessage
interface WebkitBridge {
  messageHandlers: {
    notify: {
      postMessage: (message: TODO) => void;
    };
    request: {
      postMessage: (message: TODO) => Promise<TODO>;
    };
  };
}

// Abstractions over those things

type BridgeNotificationTypeMap = {
  [K in keyof BridgeNotificationMap]: {
    type: K;
    data: BridgeNotificationMap[K];
  };
};

type BridgeRequestTypeMap = {
  [K in keyof BridgeRequestMap]: {
    type: K;
    data: BridgeRequestMap[K]["request"];
  };
};

type BridgeNotification<T extends BridgeNotificationType> =
  BridgeNotificationTypeMap[T];

type BridgeRequest<T extends BridgeRequestType> = BridgeRequestTypeMap[T];

type BridgeResponse<T extends BridgeRequestType> =
  BridgeRequestMap[T]["response"];

class Bridge {
  readonly webkit: WebkitBridge = (window as any).webkit ?? {
    messageHandlers: {
      notify: {
        postMessage: (...args) => {
          console.log("<< NOTIFY", ...args);
        },
      },
      request: {
        postMessage: (...args) => {
          console.log("<< REQUEST", ...args);
          return Promise.resolve("{}");
        },
      },
    },
  };
  readonly env: BridgeEnvironment = (window as any).__BRIDGE_ENVIRONMENT__ ?? {
    appName: "tlshot/web",
    theme: "dark",
    initialFileURL: undefined,
  };

  isWebOnly() {
    return this.env.appName.includes("web");
  }

  notify<T extends BridgeNotificationType>(
    notification: BridgeNotification<T>
  ) {
    const { type, data } = notification;
    const json = JSON.stringify(data);
    return this.webkit.messageHandlers.notify.postMessage({ type, json });
  }

  async request<T extends BridgeRequestType>(
    request: BridgeRequest<T>
  ): Promise<BridgeResponse<T>> {
    const { type, data } = request;
    const json = JSON.stringify(data);
    const responseJsonString =
      await this.webkit.messageHandlers.request.postMessage({
        type,
        json,
      });
    return JSON.parse(responseJsonString as string);
  }
}

function trySerializeForDebugging(value: unknown) {
  if (typeof value === "string") {
    return value;
  }
  try {
    return JSON.stringify(value, null, 2) ?? "undefined";
  } catch (error) {
    try {
      return String(value);
    } catch (error) {
      return "<<error serializing>>";
    }
  }
}

function parseUnknownError(value: unknown) {
  let name = "NonObjectError";
  let message = `typeof error == ${typeof value}`;
  let stack = "";
  if (typeof value === "object" && value !== null) {
    try {
      name = (value as any).name ?? "<<no error name>>";
      message = (value as any).message ?? "<<no error message>>";
      stack = (value as any).stack ?? "<<no error stack>>";
    } catch (error) {}
  }
  return { name, message, stack };
}

export const bridge = new Bridge();

if (!bridge.isWebOnly()) {
  window.addEventListener("error", (event) => {
    bridge.notify({
      type: "debug",
      data: { type: "error", error: parseUnknownError(event.error) },
    });
  });

  window.addEventListener("unhandledrejection", (event) => {
    bridge.notify({
      type: "debug",
      data: {
        type: "unhandledRejection",
        error: parseUnknownError(event.reason),
      },
    });
  });

  for (const name of ["error", "log", "debug"] as const) {
    const original = console[name].bind(console);
    console[name] = (...args: unknown[]) => {
      original(...args);
      bridge.notify({
        type: "debug",
        data: {
          type: "console",
          method: name,
          message: args.map(trySerializeForDebugging),
        },
      });
    };
  }
}
// For testing
bridge.notify({ type: "booted", data: { time: Date.now() } });
bridge.request({ type: "getName", data: {} }).then((response) => {
  console.log("bridge response", response);
});
