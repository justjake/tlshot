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
import React from "react";
import { CaptureView } from "./CaptureView";
import { useColorScheme } from "./useColorScheme";

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

  return (
    <TldrawEditor isDarkMode={scheme === "dark"} {...UIContextProps}>
      <TldrawUi {...UIContextProps}>
        <ContextMenu>
          <Canvas />
        </ContextMenu>
        <CaptureView />
      </TldrawUi>
    </TldrawEditor>
  );
}
