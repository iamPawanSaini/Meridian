// ESLint flat config for the Next.js app (T04a). Packages arrive with the T21 manifest:
// typescript-eslint and @next/eslint-plugin-next (verify names and versions then).
import nextPlugin from "@next/eslint-plugin-next";
import tseslint from "typescript-eslint";

export default tseslint.config(
  ...tseslint.configs.recommended,
  {
    plugins: { "@next/next": nextPlugin },
    rules: {
      ...nextPlugin.configs.recommended.rules,
      ...nextPlugin.configs["core-web-vitals"].rules,
    },
  },
  { ignores: [".next/**", "node_modules/**", "coverage/**"] }, // T21: build output, not source
);
