/**
 * D337 (owner: «اجعل هذه الصورة التلقائية لأي حساب»): an account without a photo shows the owner's default picture,
 * never its initial; a photo still shows as itself. The user cell keeps the names beside it.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { Avatar, UserCell } from "../src/components";

describe("D337 default avatar", () => {
  it("shows the default picture, not the initial, when there is no photo", () => {
    const html = renderToStaticMarkup(<Avatar url={null} name="Sara" />);
    expect(html).toContain('data-default-avatar="true"');
    expect(html).toContain("kabso_default_avatar_192");
    expect(html).toContain('class="avatar default"');
    expect(html).toContain('alt=""');
    expect(html).not.toContain(">S<");
  });

  it("keeps the large size class", () => {
    const html = renderToStaticMarkup(<Avatar url={null} name="سارة" large />);
    expect(html).toContain('class="avatar lg default"');
    expect(html).not.toContain(">س<");
  });

  it("shows a photo when there is one", () => {
    const html = renderToStaticMarkup(<Avatar url="https://cdn.example/a.webp" name="Sara" />);
    expect(html).toContain('src="https://cdn.example/a.webp"');
    expect(html).not.toContain("data-default-avatar");
  });

  it("the user cell: default picture beside the names", () => {
    const html = renderToStaticMarkup(<UserCell username="sara_1" displayName="Sara" avatarUrl={null} />);
    expect(html).toContain('data-default-avatar="true"');
    expect(html).toContain("Sara");
    expect(html).toContain("@sara_1");
  });
});
