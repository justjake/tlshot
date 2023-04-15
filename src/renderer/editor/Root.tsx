import { track, useValue } from "signia-react";
import { TLShot } from "../TLShotRendererApp";
import { EditorRecord, EditorRecordId } from "@/shared/records/EditorRecord";
import { Editor, getEditorApp } from "./Editor";
import { CAPTURE_ACTIVITY_ID } from "@/shared/records/CaptureActivityRecord";
import { useCallback, useEffect, useMemo, useState } from "react";
import * as captureHelpers from "./captureHelpers";
import { DisplayRecordId } from "@/shared/records/DisplayRecord";
import { SourcePickerWindow } from "./SourcePickerWindow";
import { CaptureSource } from "@/main/TLShotApi";
import { ReticleWindows } from "./ReticleWindows";
import { ChildWindow, useGetWindow } from "./ChildWindow";
import { useColorScheme } from "./useColorScheme";
import { useStyles } from "./useStyles";
import path from "path";
import { TLExportType, getSvgAsImage } from "@tldraw/editor";

export function Root() {
  const hasActivities = useValue(TLShot.queries.hasActivities);
  const [hasActivityAtLaunch] = useState(hasActivities);
  const keepOpenForActivities = hasActivityAtLaunch && hasActivities;

  useEffect(() => {
    void TLShot.api.log("Root:", {
      hasActivities,
      hasActivityAtLaunch,
      keepOpenForActivities,
    });
  });

  useEffect(() => {
    if (hasActivityAtLaunch && !hasActivities) {
      void TLShot.api.log("Root: last activity closed", {
        hasActivities,
        hasActivityAtLaunch,
      });
      const timeout = window.setTimeout(async () => {
        if (!TLShot.queries.hasActivities.value) {
          await TLShot.api.log("Root: closing window after 10 seconds idle");
          window.close();
        }
      }, 10_000);

      return () => {
        void TLShot.api.log("Root: gained activities, clearing timeout", {
          hasActivities,
          hasActivityAtLaunch,
        });
        window.clearTimeout(timeout);
      };
    }
  }, [hasActivityAtLaunch, hasActivities]);

  return (
    <>
      <RootDebugView />
      <EditorViews />
      <CaptureActivityView />
    </>
  );
}

function EditorViews() {
  const editorIds = Array.from(useValue(TLShot.store.query.ids("editor")));
  return (
    <>
      {editorIds.map((id) => (
        <EditorWindow key={id} id={id} />
      ))}
    </>
  );
}

const EditorWindow = track(function EditorWindow(props: {
  id: EditorRecordId;
}) {
  const scheme = useColorScheme();
  const backgroundColor = scheme === "dark" ? "#212529" : "#f8f9fa";

  const styles = useStyles(
    () => ({
      wrapper: {
        backgroundColor,
        height: "100%",
        display: "flex",
        flexDirection: "column",
      },
    }),
    [backgroundColor]
  );

  const editor = TLShot.store.get(props.id);
  const display =
    editor?.targetDisplay && TLShot.store.get(editor?.targetDisplay);
  const targetBounds = editor?.targetBounds;

  const proposedBounds = useMemo(() => {
    let {
      // eslint-disable-next-line prefer-const
      x = -1,
      // eslint-disable-next-line prefer-const
      y = -1,
      width = 800,
      height = 600,
    } = targetBounds ?? display?.bounds ?? {};

    // Add estimated padding for TLDraw's UI
    width += 30;
    height += 160;

    // Contain inside display working area. Not intended to be precise,
    // because the window manager will fix any issues.
    x = Math.max(display?.workArea.x ?? 0, x);
    y = Math.max(display?.workArea.y ?? 0, y);
    width = Math.min(
      (display?.workAreaSize.width ?? 0) * 0.8,
      Math.max(width, 640)
    );
    height = Math.min(
      (display?.workAreaSize.height ?? 0) * 0.8,
      Math.max(height, 480)
    );

    return {
      x,
      y,
      width,
      height,
    };
  }, [display, targetBounds]);

  if (!editor) {
    return null;
  }

  const name = `${path.basename(editor.filePath || "Untitled")} - TLShot`;

  return (
    <ChildWindow
      key={props.id}
      center="none"
      name={name}
      // TODO: we should make these smarter...
      features={{
        x: proposedBounds.x,
        y: proposedBounds.y,
        width: proposedBounds.width,
        height: proposedBounds.height,
        backgroundColor,
        titleBarStyle: "hiddenInset",
      }}
      hidden={editor.hidden}
      onUnload={() => {
        TLShot.store.remove([props.id]);
      }}
    >
      <div style={styles.wrapper}>
        <EditorTitleBar editor={editor} />
        <Editor editor={editor} />
      </div>
    </ChildWindow>
  );
});

const EditorTitleBar = track(function EditorTitleBar(props: {
  editor: EditorRecord;
}) {
  const { editor } = props;
  const preferences = TLShot.queries.preferences.value;
  const defaultFilePath = preferences
    ? preferences.saveLocation + "/"
    : undefined;
  const filePath = editor.filePath || defaultFilePath;

  const styles = useStyles(
    () => ({
      titleBar: {
        height: 42,
        paddingLeft: 70,
        WebkitAppRegion: "drag",
        width: "100%",

        display: "flex",
        justifyContent: "space-around",
        alignItems: "center",
      },
      inputArea: {
        WebkitAppRegion: "no-drag",
        flexGrow: 1,
        maxWidth: "calc(min(800px, 80%))",
        display: "flex",
        gap: 10,
        alignItems: "stretch",
        justifyContent: "center",
      },
      input: {
        flexGrow: 1,
      },
    }),
    []
  );

  const handleInputChange = useCallback(
    (e: string | React.ChangeEvent<HTMLInputElement>) => {
      TLShot.store.update(editor.id, (editor) => ({
        ...editor,
        filePath: typeof e === "string" ? e : e.target.value,
      }));
    },
    [editor.id]
  );

  const pathIsValid = useMemo(() => {
    if (!filePath) {
      return false;
    }

    if (filePath.endsWith("/")) {
      return false;
    }

    const ext = path.extname(filePath);
    switch (ext) {
      case ".png":
      case ".jpg":
        return true;
      default:
        return false;
    }
  }, [filePath]);

  const app = getEditorApp(editor);
  const valid = app?.shapeIds.size ?? 0 > 0;

  const getWindow = useGetWindow();
  const handleSaveClick = useCallback(async () => {
    let saveTo = filePath;
    if (!pathIsValid || !filePath) {
      // When invalid, open a save dialog.
      const result = await TLShot.api.saveDialog(getWindow.childWindowNanoid, {
        defaultPath: filePath,
        filters: [{ name: "Images", extensions: [".png", ".jpg"] }],
      });
      if (result.canceled || result.filePath === undefined) {
        return;
      }
      saveTo = result.filePath;
    }
    const app = getEditorApp(editor);
    if (!app) {
      throw new Error(`No app for editor ${editor.id}`);
    }

    // See @tldraw/ui/hooks/useExportAs.ts
    const format: TLExportType =
      path.extname(saveTo!) === ".jpg" ? "jpeg" : "png";
    const svg = await app.getSvg([...app.shapeIds], {
      // TODO: bigger scale = better line sharpness, but blurry image...
      scale: 1,
      background: false,
    });
    if (!svg) {
      throw new Error(`Failed to generate SVG`);
    }
    const image = await getSvgAsImage(svg, {
      type: format,
      quality: 1,
      scale: 1,
    });
    if (!image) {
      throw new Error(`Failed to generate image`);
    }
    await TLShot.api.writeFile(saveTo!, await image.arrayBuffer());
  }, [editor, filePath, getWindow.childWindowNanoid, pathIsValid]);

  const handleSaveAndCloseClick = async () => {
    await handleSaveClick();
    getWindow().close();
  };

  return (
    <div style={styles.titleBar}>
      <div style={styles.inputArea}>
        {filePath && (
          <input
            disabled={!valid}
            style={styles.input}
            value={filePath}
            onChange={handleInputChange}
          />
        )}
        {valid ? (
          <button onClick={handleSaveAndCloseClick}>Done</button>
        ) : (
          <button onClick={() => getWindow().close()}>Close</button>
        )}
      </div>
      <div />
    </div>
  );
});

function endCurrentActivity() {
  TLShot.store.remove([CAPTURE_ACTIVITY_ID]);
}

const CaptureActivityView = track(function CaptureActivityView() {
  const captureActivity = TLShot.store.get(CAPTURE_ACTIVITY_ID);

  if (!captureActivity) {
    return null;
  }

  switch (captureActivity.type) {
    case "fullScreen":
      return <CaptureFullScreenActivity />;
    case "area":
      return <CaptureAreaActivity />;
    case "window":
      return <CaptureWindowActivity />;
  }
});

function CaptureFullScreenActivity() {
  useEffect(() => {
    void captureHelpers.captureFullScreen();
    endCurrentActivity();
  }, []);
  return null;
}

function CaptureAreaActivity() {
  return (
    <ReticleWindows
      onClose={endCurrentActivity}
      onSelect={async (display, rect) => {
        const blob = await captureHelpers.captureDisplay(display, rect);
        captureHelpers.startEditorForCapture(blob, display.displayId);
      }}
    />
  );
}

const CaptureWindowActivity = track(function CaptureWindowActivity() {
  const [currentDisplayId, setCurrentDisplayId] = useState<
    DisplayRecordId | undefined
  >(undefined);
  useEffect(() => {
    void (async () => {
      const display = await TLShot.api.getCurrentDisplay();
      const recordId = DisplayRecordId.fromDisplayId(display.id);
      setCurrentDisplayId(recordId);
    })();
  }, []);

  const handlePickSource = useCallback(
    (source: CaptureSource) => {
      if (!currentDisplayId) {
        return;
      }
      endCurrentActivity();
      const asyncAction = async () => {
        const blob = await captureHelpers.captureUserMediaSource(
          source.id,
          undefined
        );
        captureHelpers.startEditorForCapture(blob, currentDisplayId);
      };
      requestAnimationFrame(() => void asyncAction());
    },
    [currentDisplayId]
  );

  const display = currentDisplayId && TLShot.store.get(currentDisplayId);
  if (!display) {
    return null;
  }

  return (
    <SourcePickerWindow
      onClose={endCurrentActivity}
      coverDisplay={display}
      onPickSource={handlePickSource}
    />
  );
});

/**
 * Rendered in the root window in case it's visible for debugging.
 */
export function RootDebugView() {
  const style = useStyles(() => {
    return {
      root: {
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "1em 12%",
      },
    };
  }, []);

  return (
    <div style={style.root}>
      <h1>TLShot Debugger</h1>
      <p>
        This window is only visible when debugging TLShot. During normal
        operation it's hidden.
      </p>
      <p>
        This window will open automatically at launch if the DevTools were open
        when the window closed.
      </p>
      <p>
        <button onClick={() => void TLShot.api.closeDevTools()}>
          Close DevTools & Hide
        </button>
      </p>
    </div>
  );
}
