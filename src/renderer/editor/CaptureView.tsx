import React, { CSSProperties, useCallback, useMemo } from "react";
import { useState } from "react";
import { TlshotApiResponse } from "../../main/services";
import "./captureView.css";
import { createShapesFromFiles, useApp } from "@tldraw/editor";
import { ChildWindow, useGetWindow } from "./ChildWindow";
import { ModalOverlayWindow } from "./ModalOverlayWindow";
import { useStyles } from "./useStyles";
import { Reticle } from "./Reticle";

type CaptureViewState =
  | { type: "closed"; display?: undefined; sources?: undefined }
  | {
      type: "picker";
      sources: TlshotApiResponse["getSources"];
    }
  | {
      type: "reticle";
      sources: TlshotApiResponse["getSources"];
    };

export function CaptureView() {
  const [state, setState] = useState<CaptureViewState>({ type: "closed" });

  const startCapture = async (type: "picker" | "reticle") => {
    const sources = await window.TlshotAPI.getSources();
    console.log("got sources", {
      sources,
    });
    setState({
      type,
      sources,
    });
  };

  const app = useApp();
  const captureSourceToCanvas = useCallback(
    async (sourceId: string, rect?: DOMRect) => {
      const blob = await captureSource(sourceId, rect);
      await createShapesFromFiles(
        app,
        [Object.assign(blob as any, { name: "capture.png" })],
        app.viewportPageBounds.center,
        false
      );
    },
    [app]
  );

  const styles = useStyles(() => {
    const toolbar: CSSProperties = {
      position: "absolute",
      top: 0,
      right: 0,
      zIndex: 1000,
    };

    return { toolbar };
  }, []);

  const handleClose = useCallback(() => {
    setState({ type: "closed" });
  }, []);

  return (
    <>
      <div className="capture-view-toolbar" style={styles.toolbar}>
        <button onClick={() => startCapture("reticle")}>Drag</button>
        <button onClick={() => startCapture("picker")}>Pick Window</button>
      </div>
      {state.type !== "closed" && (
        <ModalOverlayWindow onClose={handleClose}>
          {state.type === "picker" ? (
            <SourcesGrid
              sources={state.sources}
              onClose={handleClose}
              onClickSource={(source) => {
                handleClose();
                captureSourceToCanvas(source.id);
              }}
            />
          ) : (
            <Reticle
              onSelect={(rect) => {
                handleClose();
                const displaySource = state.sources.find((s) => s.display_id);
                if (!displaySource) {
                  return;
                }
                console.log("got rect", { rect, displaySource });
                captureSourceToCanvas(displaySource.id, rect);
              }}
            />
          )}
        </ModalOverlayWindow>
      )}
    </>
  );
}

function SourcesGrid(props: {
  sources: TlshotApiResponse["getSources"];
  onClose: () => void;
  onClickSource: (source: CaptureSource) => void;
}) {
  const styles = useStyles(() => {
    const grid: CSSProperties = {
      height: "100%",
      width: "100%",
      background: "rgba(30, 30, 30, 0.4)",
      overflowY: "auto",
      display: "grid",
      gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
      gap: 24,
      padding: "24px 64px 64px 64px",
      overflowX: "clip",
    };
    return { grid };
  }, []);

  const sourceViews = useMemo(() => {
    return props.sources.map((source) => (
      <SourceView
        source={source}
        key={source.id}
        onClick={() => props.onClickSource(source)}
      />
    ));
  }, [props.sources]);

  return (
    <div className="sources-grid" style={styles.grid}>
      {sourceViews}
    </div>
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

async function captureSource(sourceId: string, rect?: DOMRect) {
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
      canvas.width = rect?.width ?? video.videoWidth;
      canvas.height = rect?.height ?? video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (!ctx) {
        throw new Error('Could not get canvas context for "2d"');
      }

      console.log("Drawing with clipped rect", rect);

      if (rect) {
        ctx.drawImage(
          video,
          // Source
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          // Dest
          0,
          0,
          canvas.width,
          canvas.height
        );
      } else {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      }

      canvas.toBlob((blob) => {
        if (!blob) {
          throw new Error("Could not get blob from canvas");
        }
        resolve(blob);
      }, "image/png");

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
