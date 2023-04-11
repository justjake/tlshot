import React, { CSSProperties, useMemo } from "react";
import { TlshotApiResponse } from "../../main/services";
import { useStyles } from "./useStyles";

type CaptureSource = TlshotApiResponse["getSources"][0];

export function SourcesGrid(props: {
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
  }, [props]);

  return (
    <div className="sources-grid" style={styles.grid}>
      {sourceViews}
    </div>
  );
}

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
