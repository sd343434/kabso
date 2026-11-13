/**
 * D288 (owner: «ان البلاغ يصل كل المشرفين والدعم والذي يقوم بحله يضغط تم حله»): the shared report queue
 * «البلاغات المشتركة» — the unresolved / resolved tabs, «تم حله» with an optional note, who resolved it and when, the
 * OWNER's reopen, and the nav badge. Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D288 = {
  repTabOpen: 'غير محلولة',
  repTabResolved: 'تم حلها',
  repResolve: 'تم حله',
  repResolveTitle: 'تم حل البلاغ',
  repResolveIntro: 'يصبح البلاغ محلولاً لكل فريق الإشراف والدعم، ويظهر اسمك ووقت الحل. لا يُتخذ أي إجراء على المحتوى.',
  repResolveNote: 'ملاحظة (اختيارية، يراها الفريق)',
  repResolvedBy: 'حلّه {name} · {when}',
  repResolvedUnknown: 'تم الحل · {when}',
  repResolutionNote: 'ملاحظة الحل',
  repAlreadyResolved: 'تم حله بالفعل من عضو آخر في الفريق — حدّثنا القائمة.',
  repReopen: 'إعادة فتح',
  repReopenTitle: 'إعادة فتح البلاغ',
  repReopenIntro: 'يعود البلاغ إلى «غير محلولة» لكل الفريق. ما نُفِّذ على المحتوى لا يُلغى.',
  repOutcomeACTIONED: 'تم الحل',
  repOutcomeDISMISSED: 'مرفوض',
  repSharedHint: 'البلاغات مشتركة بين المشرفين والدعم: من يحل البلاغ يضغط «تم حله».',
  navReportsOpen: '{count} بلاغ غير محلول',
};

export const EN_D288: Record<keyof typeof AR_D288, string> = {
  repTabOpen: 'Unresolved',
  repTabResolved: 'Resolved',
  repResolve: 'Mark resolved',
  repResolveTitle: 'Mark the report resolved',
  repResolveIntro:
    'The report becomes resolved for every moderator and support member, with your name and the time. Nothing is done to the content.',
  repResolveNote: 'Note (optional, the team sees it)',
  repResolvedBy: 'Resolved by {name} · {when}',
  repResolvedUnknown: 'Resolved · {when}',
  repResolutionNote: 'Resolution note',
  repAlreadyResolved: 'Another team member already resolved it — the list was refreshed.',
  repReopen: 'Reopen',
  repReopenTitle: 'Reopen the report',
  repReopenIntro: 'The report goes back to «Unresolved» for the whole team. What was done to the content is not undone.',
  repOutcomeACTIONED: 'Resolved',
  repOutcomeDISMISSED: 'Dismissed',
  repSharedHint: 'Reports are shared by the moderators and the support: whoever resolves one presses «Mark resolved».',
  navReportsOpen: '{count} unresolved reports',
};
