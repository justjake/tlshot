import React, { CSSProperties, useCallback, useEffect, useMemo } from "react";
import { useState } from "react";
import { TlshotApiResponse } from "../../main/services";
import "./captureView.css";
import { createShapesFromFiles, useApp } from "@tldraw/editor";
import { ChildWindow, Windows, useGetWindow } from "./ChildWindow";
import { ChildWindowEscapeListener } from "./ChildWindowEscapeListener";

type CaptureViewState =
  | { type: "closed"; display?: undefined; sources?: undefined }
  | {
      type: "open";
      sources: TlshotApiResponse["getSources"];
      display: Electron.Display | undefined;
    };

export function CaptureView() {
  const [state, setState] = useState<CaptureViewState>({ type: "closed" });

  const handleButtonClick = async () => {
    console.log(window.TlshotAPI, screen);
    const sources = await window.TlshotAPI.getSources();
    const display = await window.TlshotAPI.getCurrentDisplay({} as any);
    console.log("got sources", {
      sources,
      display,
    });
    setState({
      type: "open",
      sources,
      display,
    });
  };

  const app = useApp();
  const captureSourceToCanvas = useCallback(
    async (sourceId: string) => {
      const blob = await captureSource(sourceId);
      await createShapesFromFiles(
        app,
        [Object.assign(blob as any, { name: "capture.png" })],
        app.viewportPageBounds.center,
        false
      );
    },
    [app]
  );

  const sourceViews = useMemo(() => {
    if (state.type === "closed") {
      return null;
    }
    return state.sources.map((source) => (
      <SourceView
        source={source}
        key={source.id}
        onClick={() => {
          setState({ type: "closed" });
          captureSourceToCanvas(source.id);
        }}
      />
    ));
  }, [state]);

  const styles = useStyles(() => {
    const toolbar: CSSProperties = {
      position: "absolute",
      top: 0,
      right: 0,
      zIndex: 1000,
    };
    const open: CSSProperties = {
      height: "100%",
      width: "100%",
      background: "rgba(30, 30, 30, 0.4)",
      backdropFilter: "blur(6px)",
      overflowY: "auto",
      display: "grid",
      gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
      gap: 24,
      padding: "24px 64px 64px 64px",
      overflowX: "clip",
    };

    return { toolbar, open };
  }, []);

  const handleClose = useCallback(() => {
    setState({ type: "closed" });
  }, []);

  const getWindow = useGetWindow();
  const dims = state.display?.bounds;

  return (
    <>
      <div className="capture-view-toolbar" style={styles.toolbar}>
        <button onClick={handleButtonClick}>Capture!</button>
      </div>
      {state.type === "open" && (
        <ChildWindow
          name="Take screenshot"
          onUnload={handleClose}
          onOpen={async (win, handle) => {
            console.log("onOpen", { handle });
            await handle.registered;
            if (handle.browserWindowId) {
              window.TlshotAPI.setAlwaysOnTop(
                handle.browserWindowId as any,
                handle.browserWindowId
              );
            }
          }}
          center="none"
          features={{
            transparent: true,
            backgroundColor: "#00000000",
            hasShadow: false,
            width: getWindow().screen.width,
            height: getWindow().screen.height,
            left: 0,
            top: 0,
            useContentSize: true,
            alwaysOnTop: true,
            enableLargerThanScreen: true,
            titleBarStyle: "hidden",
            frame: false,
            roundedCorners: false,
            hiddenInMissionControl: true,
          }}
        >
          <ChildWindowEscapeListener
            onBlur={handleClose}
            onEscape={handleClose}
          />
          <div
            className="capture-view-sources"
            style={styles.open}
            onClick={handleClose}
          >
            {sourceViews}
          </div>
        </ChildWindow>
      )}
    </>
  );
}

type CaptureSource = TlshotApiResponse["getSources"][0];

function SourceView(props: { source: CaptureSource; onClick?: () => void }) {
  const { source, onClick } = props;

  const styles = useStyles(
    () => ({
      wrapper: {
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        position: "relative",
      },
      thumbnail: {
        borderRadius: 3,
        // boxShadow: "var(--shadow-4)",
        maxWidth: "100%",
        maxHeight: "100%",
        width: "auto",
        height: "auto",
        boxShadow:
          "inset 0 1px 0 rgba(255,255,255,.6), 0 22px 70px 4px rgba(0,0,0,0.56), 0 0 0 1px rgba(0, 0, 0, 0.0)",
      },
      icon: {
        width: 48,
        height: 48,
        objectFit: "contain",
        marginTop: -24,
      },
      name: {
        fontSize: 14,
        fontWeight: "medium",
        color: "white",
        textShadow: "0px 1px 3px rgba(0, 0, 0, 0.8)",
        textAlign: "center",

        padding: "0 24px",
        overflow: "hidden",
        minWidth: 0,
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",

        maxWidth: "100%",
        lineHeight: 1.5,
      },
    }),
    []
  );

  return (
    <div style={styles.wrapper}>
      <img
        className="captureSource__thumbnail"
        onClick={onClick}
        style={styles.thumbnail}
        alt={source.name}
        src={source.thumbnail}
      />
      {source.appIcon && (
        <img
          style={styles.icon}
          className="captureSource__icon"
          src={source.appIcon}
        />
      )}
      <div style={styles.name}>{source.name}</div>
    </div>
  );
}

function useStyles<T extends Record<string, CSSProperties>>(
  fn: () => T,
  deps: unknown[]
): T {
  return useMemo(fn, deps);
}

async function captureSource(sourceId: string) {
  const electronParameters = {
    mandatory: {
      chromeMediaSource: "desktop",
      chromeMediaSourceId: sourceId,
      minWidth: 1280,
      maxWidth: 4000,
      minHeight: 720,
      maxHeight: 4000,
    },
  };

  const stream = await navigator.mediaDevices.getUserMedia({
    audio: false,
    video: electronParameters as any,
  });

  const video = document.createElement("video");
  video.style.cssText = "position:absolute;top:-10000px;left:-10000px;";

  const resultPromise = new Promise<Blob>((resolve) => {
    video.addEventListener("loadedmetadata", () => {
      video.style.width = video.videoWidth + "px";
      video.style.height = video.videoHeight + "px";

      video.play();

      const canvas = document.createElement("canvas");
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (!ctx) {
        throw new Error('Could not get canvas context for "2d"');
      }

      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      // const dataUrl = canvas.toDataURL("image/png");
      // resolve(dataUrl);

      canvas.toBlob((blob) => {
        if (!blob) {
          throw new Error("Could not get blob from canvas");
        }
        resolve(blob);
      });

      video.srcObject = null;
      video.remove();
      canvas.remove();
      try {
        // Destroy connect to stream
        stream.getTracks()[0].stop();
      } catch (e) {
        console.warn("Error removing stream track: ", e);
      }
    });
  });

  video.srcObject = stream;
  document.body.appendChild(video);

  return resultPromise;
}
