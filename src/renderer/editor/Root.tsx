import { track, useValue } from "signia-react";
import { TLShot } from "../TLShotRendererApp";
import { EditorRecordId } from "@/shared/records/EditorRecord";
import { Editor } from "./Editor";
import { CAPTURE_ACTIVITY_ID } from "@/shared/records/CaptureActivityRecord";
import { useCallback, useEffect, useState } from "react";
import * as captureHelpers from "./captureHelpers";
import { DisplayRecordId } from "@/shared/records/DisplayRecord";
import { SourcePickerWindow } from "./SourcePickerWindow";
import { CaptureSource } from "@/main/TLShotApi";
import { ReticleWindows } from "./ReticleWindows";
import { ChildWindow } from "./ChildWindow";
import { useColorScheme } from "./useColorScheme";
import { useStyles } from "./useStyles";

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
      // eslint-disable-next-line @typescript-eslint/no-misused-promises
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

  const editor = TLShot.store.get(props.id);
  if (!editor) {
    return null;
  }
  return (
    <ChildWindow
      key={props.id}
      center="screen"
      name="tlshot"
      // TODO: we should make these smarter...
      features={{
        width: 800,
        height: 600,
        backgroundColor,
      }}
      hidden={editor.hidden}
      onUnload={() => {
        TLShot.store.remove([props.id]);
      }}
    >
      <Editor editor={editor} />;
    </ChildWindow>
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
      // eslint-disable-next-line @typescript-eslint/no-misused-promises
      onSelect={async (display, rect) => {
        const source = await TLShot.api.getDisplaySource(display.displayId);
        const blob = await captureHelpers.captureUserMediaSource(
          source.id,
          rect
        );
        captureHelpers.startEditorForCapture(blob);
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

  const handlePickSource = useCallback((source: CaptureSource) => {
    endCurrentActivity();
    const asyncAction = async () => {
      const blob = await captureHelpers.captureUserMediaSource(
        source.id,
        undefined
      );
      captureHelpers.startEditorForCapture(blob);
    };
    requestAnimationFrame(() => void asyncAction());
  }, []);

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
        <button onClick={() => void TLShot.api.openDevTools()}>
          Open DevTools
        </button>{" "}
        <button onClick={() => void TLShot.api.closeDevTools()}>
          Close DevTools & Hide
        </button>
      </p>
    </div>
  );
}
