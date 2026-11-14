-- v1.46-levels (D169, 2026-10-30): the owner's 21 support tier avatar frames (owner-supplied art,
-- apps/mobile/assets/levels/support_frames/). Nobody owns them until the server gives one: reaching
-- support tier N (levels 1–5 = tier 1 … 96–99 = tier 20, level 100 = tier 21) gives the frames of
-- every tier reached so far, once each (source LEVEL_REWARD, not worn); frames are kept for good (owner).
-- bag.catalogue.ts keeps the same rows (checked by a unit test).

INSERT INTO "bag_items" ("code", "category", "name_ar", "name_en", "asset_key", "sort_order", "free") VALUES
  ('support_frame_01', 'AVATAR_FRAME', 'إطار الدعم 1', 'Support frame 1', 'support_frame_01', 10, false),
  ('support_frame_02', 'AVATAR_FRAME', 'إطار الدعم 2', 'Support frame 2', 'support_frame_02', 20, false),
  ('support_frame_03', 'AVATAR_FRAME', 'إطار الدعم 3', 'Support frame 3', 'support_frame_03', 30, false),
  ('support_frame_04', 'AVATAR_FRAME', 'إطار الدعم 4', 'Support frame 4', 'support_frame_04', 40, false),
  ('support_frame_05', 'AVATAR_FRAME', 'إطار الدعم 5', 'Support frame 5', 'support_frame_05', 50, false),
  ('support_frame_06', 'AVATAR_FRAME', 'إطار الدعم 6', 'Support frame 6', 'support_frame_06', 60, false),
  ('support_frame_07', 'AVATAR_FRAME', 'إطار الدعم 7', 'Support frame 7', 'support_frame_07', 70, false),
  ('support_frame_08', 'AVATAR_FRAME', 'إطار الدعم 8', 'Support frame 8', 'support_frame_08', 80, false),
  ('support_frame_09', 'AVATAR_FRAME', 'إطار الدعم 9', 'Support frame 9', 'support_frame_09', 90, false),
  ('support_frame_10', 'AVATAR_FRAME', 'إطار الدعم 10', 'Support frame 10', 'support_frame_10', 100, false),
  ('support_frame_11', 'AVATAR_FRAME', 'إطار الدعم 11', 'Support frame 11', 'support_frame_11', 110, false),
  ('support_frame_12', 'AVATAR_FRAME', 'إطار الدعم 12', 'Support frame 12', 'support_frame_12', 120, false),
  ('support_frame_13', 'AVATAR_FRAME', 'إطار الدعم 13', 'Support frame 13', 'support_frame_13', 130, false),
  ('support_frame_14', 'AVATAR_FRAME', 'إطار الدعم 14', 'Support frame 14', 'support_frame_14', 140, false),
  ('support_frame_15', 'AVATAR_FRAME', 'إطار الدعم 15', 'Support frame 15', 'support_frame_15', 150, false),
  ('support_frame_16', 'AVATAR_FRAME', 'إطار الدعم 16', 'Support frame 16', 'support_frame_16', 160, false),
  ('support_frame_17', 'AVATAR_FRAME', 'إطار الدعم 17', 'Support frame 17', 'support_frame_17', 170, false),
  ('support_frame_18', 'AVATAR_FRAME', 'إطار الدعم 18', 'Support frame 18', 'support_frame_18', 180, false),
  ('support_frame_19', 'AVATAR_FRAME', 'إطار الدعم 19', 'Support frame 19', 'support_frame_19', 190, false),
  ('support_frame_20', 'AVATAR_FRAME', 'إطار الدعم 20', 'Support frame 20', 'support_frame_20', 200, false),
  ('support_frame_21', 'AVATAR_FRAME', 'إطار الدعم 21', 'Support frame 21', 'support_frame_21', 210, false);
