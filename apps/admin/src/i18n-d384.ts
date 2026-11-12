/**
 * D384 (owner 2026-11-12: the VIP «صورة متحركة», an animated cut-out picture on the person card): the user page's
 * review and removal of the clip, merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D384 = {
  ctAnimatedAvatar: 'الصورة المتحركة (VIP)',
  ctRemoveAnimatedAvatar: 'حذف الصورة المتحركة',
};

export const EN_D384: Record<keyof typeof AR_D384, string> = {
  ctAnimatedAvatar: 'Animated picture (VIP)',
  ctRemoveAnimatedAvatar: 'Remove animated picture',
};
