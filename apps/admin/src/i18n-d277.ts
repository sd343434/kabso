/**
 * D277 (owner): the host's two daily targets are in cherries — «هدف الهدايا» and «هدف هدايا الحظ». The tasks page
 * names the unit of each target («كرز» / «عملة»). Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D277 = {
  tasksUnitCherries: 'كرز',
  tasksUnitCoins: 'عملة',
  tasksUnitNote: 'هدف الهدايا وهدف هدايا الحظ بالكرز: ما يصل المضيف فعلاً من الهدايا.',
};

export const EN_D277: Record<keyof typeof AR_D277, string> = {
  tasksUnitCherries: 'cherries',
  tasksUnitCoins: 'coins',
  tasksUnitNote: 'The gifts target and the lucky gifts target are in cherries: what the host really receives from gifts.',
};
