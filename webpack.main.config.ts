import type { Configuration } from "webpack";

import { rules, resolve } from "./webpack.rules";

rules.push({
  test: /\.png$/,
  type: "asset/resource",
});

export const mainConfig: Configuration = {
  /**
   * This is the main entry point for your application, it's the first file
   * that runs in the main process.
   */
  entry: "./src/main/index.ts",
  // Put your normal webpack config below here
  module: {
    rules,
  },
  // https://github.com/electron/forge/issues/1431#issuecomment-1132921895
  output: {
    assetModuleFilename: "[file][query][fragment]",
  },
  resolve,
};
