// Usage: copy to apps/<name>/eslint.config.mjs and add the imported packages as dev dependencies.
import js from "@eslint/js";
import eslintComments from "@eslint-community/eslint-plugin-eslint-comments";
import vitest from "@vitest/eslint-plugin";
import { defineConfig } from "eslint/config";
import sonarjs from "eslint-plugin-sonarjs";
import tseslint from "typescript-eslint";

export default defineConfig(
  { ignores: ["dist/", "build/", "coverage/"] },
  { linterOptions: { reportUnusedDisableDirectives: "error" } },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    files: ["**/*.{ts,tsx,mts,cts}"],
    plugins: { sonarjs, "@eslint-community/eslint-comments": eslintComments },
    rules: {
      "sonarjs/no-collapsible-if": "error",
      "sonarjs/no-identical-functions": "error",
      "sonarjs/no-duplicated-branches": "error",
      "sonarjs/cognitive-complexity": ["error", 15],
      "sonarjs/no-commented-code": "error",
      "@typescript-eslint/ban-ts-comment": [
        "error",
        {
          "ts-expect-error": "allow-with-description",
          "ts-ignore": true,
          "ts-nocheck": true,
          "ts-check": false,
        },
      ],
      "@eslint-community/eslint-comments/require-description": "error",
      "@eslint-community/eslint-comments/no-unlimited-disable": "error",
    },
  },
  {
    files: ["**/*.{test,spec}.{ts,tsx,mts,cts}"],
    plugins: { vitest },
    rules: {
      "vitest/no-focused-tests": "error",
      "vitest/no-disabled-tests": "error",
      "vitest/no-commented-out-tests": "error",
      "vitest/expect-expect": "error",
    },
  },
);
