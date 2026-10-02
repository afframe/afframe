// Example ESLint flat config for a TypeScript app. Copy to apps/<name>/eslint.config.mjs.
// Dev dependencies: eslint, @eslint/js, typescript-eslint, eslint-plugin-sonarjs,
// @vitest/eslint-plugin, @eslint-community/eslint-plugin-eslint-comments.
// Every rule is an error: a new app starts clean, so there is no baseline to grandfather.
import js from "@eslint/js";
import eslintComments from "@eslint-community/eslint-plugin-eslint-comments";
import vitest from "@vitest/eslint-plugin";
import { defineConfig } from "eslint/config";
import sonarjs from "eslint-plugin-sonarjs";
import tseslint from "typescript-eslint";

export default defineConfig(
  { ignores: ["dist/", "build/", "coverage/"] },
  // A disable comment that no longer suppresses anything fails the lint.
  { linterOptions: { reportUnusedDisableDirectives: "error" } },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    files: ["**/*.{ts,tsx,mts,cts}"],
    plugins: { sonarjs, "@eslint-community/eslint-comments": eslintComments },
    rules: {
      // Duplicated or needlessly nested logic, a common shape of generated code.
      "sonarjs/no-collapsible-if": "error",
      "sonarjs/no-identical-functions": "error",
      "sonarjs/no-duplicated-branches": "error",
      "sonarjs/cognitive-complexity": ["error", 15],
      "sonarjs/no-commented-code": "error",
      // Suppressions must say why; @ts-ignore and @ts-nocheck are banned.
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
      // No skipped, focused or assertion-free tests reach main.
      "vitest/no-focused-tests": "error",
      "vitest/no-disabled-tests": "error",
      "vitest/no-commented-out-tests": "error",
      "vitest/expect-expect": "error",
    },
  },
);
