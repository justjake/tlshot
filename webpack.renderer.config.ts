import type { Configuration } from "webpack";

import { rules, getResolveOptions } from "./webpack.rules";
import { plugins } from "./webpack.plugins";

rules.push({
  test: /\.css$/,
  use: [{ loader: "style-loader" }, { loader: "css-loader" }],
});

export const rendererConfig: Configuration = {
  module: {
    rules,
  },
  plugins,
  resolve: {
    ...getResolveOptions(),
    fallback: {
      path: require.resolve("path-browserify"),
    },
  },
};
