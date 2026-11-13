/**
 * D286 (owner: «عندما يقوم المشرف بالعمل يتم تفعيل زر مناوبة»): opening «بثوثي» in «البث الآن» is staff work (the API
 * switches the shift on); the page's own 15 s refresh says `background` so a shift turned off by hand stays off. The
 * new staff member's next steps say the shift is automatic and moderation needs no code. Both languages.
 */
import { describe, expect, it } from "vitest";
import { DICTIONARIES } from "../src/i18n";
import { livesListParams } from "../src/pages/Lives";

describe("D286 «بثوثي» and the automatic shift", () => {
  it("opening «بثوثي» asks for my lives (staff work); the refresh is background", () => {
    expect(livesListParams(1, "MINE", "", false)).toEqual({
      page: 1,
      pageSize: 24,
      sort: "viewers",
      order: "desc",
      assigned: "me",
    });
    expect(livesListParams(2, "MINE", "mine", true)).toMatchObject({
      page: 2,
      assigned: "me",
      background: "true",
      region: "mine",
    });
  });

  it("only «بثوثي» ever carries background; the other chips never ask for my lives", () => {
    expect(livesListParams(1, "REPORTED", "", true)).not.toHaveProperty(
      "background",
    );
    expect(livesListParams(1, "REPORTED", "", true)).toMatchObject({
      reported: "true",
    });
    expect(livesListParams(1, "", "", true)).not.toHaveProperty("assigned");
    expect(livesListParams(1, "", "", false)).not.toHaveProperty("background");
  });

  it("the next steps say the shift is automatic and moderation needs no code", () => {
    expect(DICTIONARIES.ar.staffNextShift).toContain("تلقائياً");
    expect(DICTIONARIES.ar.staffNextShift).toContain("لا يُطلب رمز المصادقة");
    expect(DICTIONARIES.en.staffNextShift).toContain("turns on by itself");
    expect(DICTIONARIES.en.staffNextShift).toContain("no authenticator code");
  });
});
