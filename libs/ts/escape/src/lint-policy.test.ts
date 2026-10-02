// The ban on raw HTML sinks is a security rule, so it gets tests like any other.
import { ESLint } from "eslint";
import react from "eslint-plugin-react";
import tseslint from "typescript-eslint";
import { describe, expect, it } from "vitest";

import { safeRenderingRules } from "../../../../eslint.config.js";

const eslint = new ESLint({
  overrideConfigFile: true,
  overrideConfig: [
    {
      files: ["**/*.tsx"],
      languageOptions: {
        parser: tseslint.parser,
        parserOptions: { ecmaFeatures: { jsx: true } },
      },
      plugins: { react },
      settings: { react: { version: "19.0" } },
      rules: safeRenderingRules,
    },
  ],
});

async function ruleIds(code: string): Promise<string[]> {
  const [result] = await eslint.lintText(code, { filePath: "probe.tsx" });
  return (result?.messages ?? []).map((m) => m.ruleId ?? "fatal");
}

describe("safe rendering lint policy", () => {
  it.each([
    ["innerHTML assignment", "el.innerHTML = untrusted;"],
    ["outerHTML assignment", "el.outerHTML = untrusted;"],
    ["insertAdjacentHTML", "el.insertAdjacentHTML('beforeend', untrusted);"],
    ["createContextualFragment", "range.createContextualFragment(untrusted);"],
    ["document.write", "document.write(untrusted);"],
  ])("rejects %s", async (_name, code) => {
    expect(await ruleIds(code)).toContain("no-restricted-properties");
  });

  it("rejects dangerouslySetInnerHTML in JSX", async () => {
    expect(await ruleIds("const x = <div dangerouslySetInnerHTML={{ __html: u }} />;")).toContain(
      "react/no-danger",
    );
  });

  it("rejects dangerouslySetInnerHTML passed as a props object", async () => {
    expect(await ruleIds("createElement('div', { dangerouslySetInnerHTML: { __html: u } });")).toContain(
      "no-restricted-syntax",
    );
  });

  it("rejects iframe srcDoc", async () => {
    expect(await ruleIds("const x = <iframe srcDoc={u} />;")).toContain("no-restricted-syntax");
  });

  it("rejects eval and new Function", async () => {
    const ids = await ruleIds("eval(u); new Function(u);");
    expect(ids).toContain("no-eval");
    expect(ids).toContain("no-new-func");
  });

  it("allows rendering text through React", async () => {
    expect(await ruleIds("const x = <p>{untrusted}</p>; el.textContent = untrusted;")).toEqual([]);
  });
});
