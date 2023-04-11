module.exports = {
  env: {
    browser: true,
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/eslint-recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:@typescript-eslint/recommended-requiring-type-checking",
    "plugin:import/recommended",
    "plugin:import/electron",
    "plugin:import/typescript",
    "plugin:react-hooks/recommended",
  ],
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint", "unused-imports"],
  parserOptions: {
    project: "./tsconfig.eslint.json",
  },
  root: true,
  rules: {
    "@typescript-eslint/no-explicit-any": "off",
    "react-hooks/exhaustive-deps": [
      "error",
      {
        additionalHooks: "(useStyles)",
      },
    ],
    "@typescript-eslint/no-unused-vars": "off", // or "@typescript-eslint/no-unused-vars": "off",
    "unused-imports/no-unused-imports": "error",
    "unused-imports/no-unused-vars": [
      "warn",
      {
        vars: "all",
        varsIgnorePattern: "^_",
        args: "after-used",
        argsIgnorePattern: "^_",
      },
    ],
  },
  settings: {
    "import/resolver": {
      typescript: {
        project: "./tsconfig.eslint.json",
      },
    },
  },
};
