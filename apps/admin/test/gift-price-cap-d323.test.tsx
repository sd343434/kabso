/**
 * D323 (owner: «تاج الافتتاح» at 3 000 000 coins was refused by the browser with "Value must be less than or equal to
 * 1000000"): the gift form's price accepts 0 … 100 000 000 coins, as the server, and sends the number as typed.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { translate, type Lang } from "../src/i18n";
import {
  GIFT_PRICE_MAX,
  GiftForm,
  giftBody,
  giftPriceInputProps,
  type GiftCategoryChoice,
} from "../src/pages/Catalog";

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const categories: GiftCategoryChoice[] = [
  {
    code: "POPULAR",
    kind: "NORMAL",
    nameAr: "شائعة",
    nameEn: "Popular",
    enabled: true,
  },
];

const priceInput = (html: string) =>
  /<input[^>]*id="gf-priceCoins"[^>]*>/.exec(html)?.[0] ?? "";

describe("D323 gift price cap in the panel form", () => {
  it("the cap is 100 000 000 coins", () => {
    expect(GIFT_PRICE_MAX).toBe(100_000_000);
    expect(giftPriceInputProps).toMatchObject({
      type: "number",
      min: 0,
      max: 100_000_000,
    });
  });

  for (const lang of ["ar", "en"] as const) {
    it(`the «السعر بالعملات» input allows up to 100000000 (${lang})`, () => {
      const html = renderToStaticMarkup(
        <AppContext.Provider value={state(lang)}>
          <GiftForm
            gift={null}
            categories={categories}
            uploads={undefined}
            onClose={() => undefined}
            onDone={() => undefined}
          />
        </AppContext.Provider>,
      );
      const input = priceInput(html);
      expect(input).toContain('type="number"');
      expect(input).toContain('min="0"');
      expect(input).toContain('max="100000000"');
      expect(input).not.toContain('max="1000000"');
    });
  }

  it("the browser check: 3 000 000 and 100 000 000 pass, 100 000 001 does not (as the input’s max)", () => {
    const fits = (v: number) =>
      v >= giftPriceInputProps.min && v <= giftPriceInputProps.max;
    expect(fits(3_000_000)).toBe(true);
    expect(fits(100_000_000)).toBe(true);
    expect(fits(100_000_001)).toBe(false);
  });

  it("sends a 3 000 000 price as the number typed", () => {
    const body = giftBody(
      {
        code: "opening_crown",
        category: "POPULAR",
        nameAr: "تاج الافتتاح",
        nameEn: "Opening Crown",
        priceCoins: "3000000",
        sortOrder: "0",
      },
      null,
    );
    expect(body.priceCoins).toBe(3_000_000);
  });
});
