import { describe, expect, it } from "vitest";

import * as ui from "./index";

describe("@cassie/ui", () => {
  it("loads", () => {
    expect(ui).toBeTypeOf("object");
  });
});
