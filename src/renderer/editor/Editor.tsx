/**
 * https://docs.tldraw.dev/docs/ucg/usage
 */
import "@tldraw/tldraw/editor.css";
import "@tldraw/tldraw/ui.css";

import { getBundlerAssetUrls } from "@tldraw/assets";
import { TldrawEditor, Canvas } from "@tldraw/editor";
import {
  TldrawUi,
  ContextMenu,
  TldrawUiContextProviderProps,
} from "@tldraw/ui";
import React, { useState } from "react";
import { CaptureView } from "./CaptureToolbar";
import { useColorScheme } from "./useColorScheme";
import { DisplaysListener } from "./Displays";
import { TLShotRendererApp } from "../TLShotRendererApp";

const TLDRAW_ASSETS = getBundlerAssetUrls({
  format(url) {
    return url;
  },
});

const UIContextProps: TldrawUiContextProviderProps = {
  assetUrls: TLDRAW_ASSETS,
};

export function Editor() {
  const scheme = useColorScheme();
  const [tlshot] = useState(() => new TLShotRendererApp());

  return (
    <TldrawEditor
      onMount={(app) =>
        app.updateInstanceState({
          isDebugMode: false,
        })
      }
      isDarkMode={scheme === "dark"}
      {...UIContextProps}
    >
      <TldrawUi {...UIContextProps}>
        <ContextMenu>
          <Canvas />
        </ContextMenu>

        <DisplaysListener>
          <CaptureView />
        </DisplaysListener>
      </TldrawUi>
    </TldrawEditor>
  );
}
