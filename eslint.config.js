// @ts-check
import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import tseslint from "typescript-eslint";

// Raw HTML sinks. Rendering untrusted text through any of these is how Lantern's
// frontends got XSS. The only escape hatch lives in @cassie/escape (see its README).
const htmlSinkProperties = ["innerHTML", "outerHTML", "insertAdjacentHTML", "createContextualFragment"].map(
  (property) => ({ property, message: "Raw HTML sink. Render text with React, or use the @cassie/escape escape hatch." }),
);

/** @type {import("eslint").Linter.RulesRecord} */
export const safeRenderingRules = {
  "react/no-danger": "error",
  "no-restricted-properties": [
    "error",
    ...htmlSinkProperties,
    { object: "document", property: "write", message: "document.write is a raw HTML sink." },
    { object: "document", property: "writeln", message: "document.writeln is a raw HTML sink." },
  ],
  "no-restricted-syntax": [
    "error",
    {
      selector: "Property[key.name='dangerouslySetInnerHTML']",
      message: "dangerouslySetInnerHTML is forbidden. Use the @cassie/escape escape hatch.",
    },
    {
      selector: "JSXAttribute[name.name='srcDoc']",
      message: "srcDoc renders raw HTML. Use the @cassie/escape escape hatch.",
    },
  ],
  "no-eval": "error",
  "no-new-func": "error",
  "no-script-url": "error",
};

export default defineConfig(
  {
    ignores: ["**/node_modules/", "**/dist/", "**/coverage/", ".venv/", "**/.venv/"],
  },
  {
    linterOptions: { reportUnusedDisableDirectives: "error" },
  },
  js.configs.recommended,
  tseslint.configs.strictTypeChecked,
  tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
      globals: { ...globals.browser },
    },
    // Registered for every file so the safe-rendering rules apply everywhere.
    plugins: { react },
    // Keep in step with the react version in libs/ts/ui/package.json.
    settings: { react: { version: "19.3" } },
  },
  {
    files: ["**/*.{ts,tsx}"],
    ...react.configs.flat.recommended,
  },
  {
    files: ["**/*.{ts,tsx}"],
    ...react.configs.flat["jsx-runtime"],
  },
  reactHooks.configs.flat["recommended-latest"],
  {
    rules: {
      ...safeRenderingRules,
      "no-implied-eval": "off",
      "@typescript-eslint/no-implied-eval": "error",
    },
  },
  {
    files: ["eslint.config.js"],
    languageOptions: { globals: { ...globals.node } },
  },
);
