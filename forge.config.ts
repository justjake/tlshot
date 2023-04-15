import type { ForgeConfig } from "@electron-forge/shared-types";
import { MakerSquirrel } from "@electron-forge/maker-squirrel";
import { MakerZIP } from "@electron-forge/maker-zip";
import { MakerDeb } from "@electron-forge/maker-deb";
import { MakerRpm } from "@electron-forge/maker-rpm";
import { WebpackPlugin } from "@electron-forge/plugin-webpack";

import { mainConfig } from "./webpack.main.config";
import { rendererConfig } from "./webpack.renderer.config";
import { WebpackPluginEntryPoint } from "@electron-forge/plugin-webpack/dist/Config";

function createEntryPoint(windowName: string): WebpackPluginEntryPoint {
  return {
    html: `./src/renderer/${windowName}/index.html`,
    js: `./src/renderer/${windowName}/index.tsx`,
    name: windowName,
    preload: {
      // For some reason we can't import Node stuff in our preload:
      // __dirname is not defined
      // Issue: https://github.com/electron/forge/issues/2931
      // If we reboot after initial load, maybe it's fixed?
      // https://github.com/electron/forge/issues/2931#issuecomment-1492262041
      js: "./src/renderer/preload.ts",
      // TODO: should we set config here to manually enable Node integration
    },
  };
}

const editorEntryPoint = createEntryPoint("editor");

const config: ForgeConfig = {
  packagerConfig: {},
  rebuildConfig: {},
  makers: [
    new MakerSquirrel({}),
    new MakerZIP({}, ["darwin"]),
    new MakerRpm({}),
    new MakerDeb({}),
  ],
  plugins: [
    new WebpackPlugin({
      mainConfig,
      port: 3333,
      renderer: {
        config: rendererConfig,
        entryPoints: [
          editorEntryPoint,
          {
            ...editorEntryPoint,
            name: "editor_node",
            nodeIntegration: true,
          },
        ],
      },
    }),
  ],
};

export default config;
