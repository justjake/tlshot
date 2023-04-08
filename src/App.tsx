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

const TLDRAW_ASSETS = getBundlerAssetUrls({
  format(url) {
    return url;
  },
});

const UIContextProps: TldrawUiContextProviderProps = {
  assetUrls: TLDRAW_ASSETS,
};

export function App() {
  return (
    <TldrawEditor {...UIContextProps}>
      <TldrawUi {...UIContextProps}>
        <ContextMenu>
          <Canvas />
        </ContextMenu>
      </TldrawUi>
    </TldrawEditor>
  );
}
