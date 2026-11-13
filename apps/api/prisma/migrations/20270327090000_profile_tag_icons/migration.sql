-- v1.91-social (D292, CONVENTIONS §10.106; owner 2026-11-06, option 1: the person picks an icon for each tag): the
-- icon of each profile tag, in the tags' order. A closed set the app draws with its own icons (never emoji), or
-- `flag:<ISO 3166-1 alpha-2>` (the app's bundled flag art). Set with `PATCH /me` (`tagIcons`, one per tag, with
-- `tags`); an app that sends only `tags` keeps each tag's icon by its text. Rows before this migration have none
-- ('{}', read as `default` for every tag).
ALTER TABLE "user_profiles" ADD COLUMN "tag_icons" VARCHAR(24)[] NOT NULL DEFAULT ARRAY[]::VARCHAR(24)[];
-- Empty, or exactly one icon per tag.
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_tag_icons_len"
  CHECK (cardinality("tag_icons") = 0 OR cardinality("tag_icons") = cardinality("tags"));
-- Backstop for the API's validation: no null entry, and only the closed set or `flag:XX`.
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_tag_icons_values"
  CHECK (
    array_position("tag_icons", NULL) IS NULL
    AND array_to_string("tag_icons", ',') ~
      '^((default|crown|fire|trophy|gamepad|music|mic|moon|heart|star|gem|camera|book|sport|palette|globe|flag:[A-Z]{2})(,|$))*$'
  );
