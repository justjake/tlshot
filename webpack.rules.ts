import path from "path";
import type { ModuleOptions, ResolveOptions } from "webpack";

export const resolve: ResolveOptions = {
  alias: {
    "@": path.resolve(__dirname, "./src"),
  },
  extensions: [".js", ".ts", ".jsx", ".tsx", ".css", ".json"],
};

export const rules: Required<ModuleOptions>["rules"] = [
  // Add support for native node modules
  {
    // We're specifying native_modules in the test because the asset relocator loader generates a
    // "fake" .node file which is really a cjs file.
    test: /native_modules[/\\].+\.node$/,
    use: "node-loader",
  },
  {
    test: /[/\\]node_modules[/\\].+\.(m?js|node)$/,
    parser: { amd: false },
    use: {
      loader: "@vercel/webpack-asset-relocator-loader",
      options: {
        outputAssetBase: "native_modules",
      },
    },
  },
  {
    test: /\.tsx?$/,
    exclude: /(node_modules|\.webpack)/,
    use: {
      loader: "ts-loader",
      options: {
        transpileOnly: true,
      },
    },
  },
  // Needed for tldraw
  // https://stackoverflow.com/questions/69427025/programmatic-webpack-jest-esm-cant-resolve-module-without-js-file-exten
  {
    test: /tldraw.*\.m?js$/,
    resolve: {
      fullySpecified: false,
    },
  },
  {
    // Allows us to load tldraw assets via `import` statement.
    // Needed for @tldraw/assets.
    test: /@tldraw\/assets.*\.(svg|json|woff2|png|jpg)$/,
    // Files <8kb will be inlined as base64 URLs.
    // Files >8kb will be URLs pointing to the output file.
    // Inlining keeps our asset manifest small, and substantially improve
    // tldraw startup speed.
    // https://webpack.js.org/guides/asset-modules/
    type: "asset",
    generator: {
      // Place the tldraw assets in build/static/drawing
      filename: "drawing/[name]-[contenthash][ext]",
    },
  },
];
