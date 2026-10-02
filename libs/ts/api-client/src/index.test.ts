import { describe, expect, it } from "vitest";

import * as client from "./index";

describe("@cassie/api-client", () => {
  it("loads", () => {
    expect(client).toBeTypeOf("object");
  });
});
