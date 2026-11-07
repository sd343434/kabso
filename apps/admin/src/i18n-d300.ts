/**
 * D300 (owner 2026-11-07: «مدرسة المحتوى»): a medal whose level needs several numbers together — the levels editor
 * shows the three thresholds (followers, likes, views) of each level. Also «لاعب الأحكام»'s metric, PK points. Merged
 * into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D300 = {
  mdMetricALL_REQUIREMENTS: 'عدة شروط معاً (لصنّاع المحتوى)',
  mdMetricCREATOR_FOLLOWERS: 'المتابعون',
  mdMetricCREATOR_LIKES: 'الإعجابات',
  mdMetricCREATOR_VIEWS: 'المشاهدات',
  mdMetricPK_POINTS: 'نقاط PK (لاعب الأحكام)',
  mdReqHint:
    'يصل صانع المحتوى إلى المستوى عندما يبلغ الشروط الثلاثة معاً: المتابعون النشطون الآن، والإعجابات والمشاهدات من حسابات نشطة أخرى على منشوراته وريلزاته. لصنّاع المحتوى فقط.',
  mdReqRising: 'لكل مستوى حد لكل شرط، وكل حد أكبر من حدّ المستوى الذي قبله (1 … 10¹²).',
};

export const EN_D300: typeof AR_D300 = {
  mdMetricALL_REQUIREMENTS: 'Several requirements together (content creators)',
  mdMetricCREATOR_FOLLOWERS: 'Followers',
  mdMetricCREATOR_LIKES: 'Likes',
  mdMetricCREATOR_VIEWS: 'Views',
  mdMetricPK_POINTS: 'PK points (Dares Player)',
  mdReqHint:
    'A content creator reaches a level when all three are met together: ACTIVE followers now, and likes and views from other ACTIVE accounts on their posts and reels. Content creators only.',
  mdReqRising: 'Each level needs a threshold per requirement, each higher than the level before (1 … 10¹²).',
};
