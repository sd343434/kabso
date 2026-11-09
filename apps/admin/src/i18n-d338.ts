/**
 * D338 (owner 2026-11-09: «أريد زر لإزالتهم وليس فقط إيقافهم»; CONVENTIONS §10.131): «حذف» of a gift — deleted for good
 * when nothing ever used it, archived otherwise — the «المحذوفة» filter and «استعادة». Merged into i18n.ts.
 */
export const AR_D338 = {
  giftDelete: 'حذف',
  giftDeleteForever: 'ستُحذف نهائياً: لم تُرسَل قط ولا يملكها أحد ولا تستخدمها فعالية. تُحذف ملفاتها أيضاً إن لم تستخدمها هدية أخرى.',
  giftDeleteArchive:
    'ستُنقل إلى «المحذوفة» لأن لها سجلاً{details}. تختفي من التطبيق والقوائم والفعاليات ولا تُرسَل بعد الآن، ويبقى اسمها وصورتها في السجل. يمكن استعادتها.',
  giftDeleteSends: 'أُرسلت {n} مرة',
  giftDeleteHolders: 'في حقائب {n} مستخدمين',
  giftDeleteConfirm: 'حذف نهائياً',
  giftArchiveConfirm: 'نقل إلى المحذوفة',
  giftDeletedToast: 'حُذفت الهدية نهائياً.',
  giftArchivedToast: 'نُقلت الهدية إلى المحذوفة.',
  giftArchived: 'محذوفة',
  giftArchivedFilter: 'المحذوفة ({n})',
  giftArchivedNote:
    'الهدايا المحذوفة لا تظهر في التطبيق ولا في الفعاليات ولا تُرسَل، ومن يملك منها قطعاً في حقيبته لا يراها حتى تُستعاد. يبقى سجلها كما هو.',
  giftRestore: 'استعادة',
  giftRestoreNote: 'تعود الهدية إلى القائمة والتطبيق وتُفعَّل.',
  giftArchivedSince: 'حُذفت في {date}',
};

export const EN_D338: Record<keyof typeof AR_D338, string> = {
  giftDelete: 'Delete',
  giftDeleteForever:
    'It will be deleted for good: it was never sent, nobody holds it and no event uses it. Its files go too unless another gift uses them.',
  giftDeleteArchive:
    'It will move to “Deleted” because it has a history{details}. It leaves the app, the lists and the events and can no longer be sent; its name and picture stay in the history. It can be restored.',
  giftDeleteSends: 'sent {n} times',
  giftDeleteHolders: 'in {n} users’ bags',
  giftDeleteConfirm: 'Delete for good',
  giftArchiveConfirm: 'Move to Deleted',
  giftDeletedToast: 'The gift was deleted for good.',
  giftArchivedToast: 'The gift was moved to Deleted.',
  giftArchived: 'Deleted',
  giftArchivedFilter: 'Deleted ({n})',
  giftArchivedNote:
    'Deleted gifts are not in the app or the events and cannot be sent; pieces in bags are not shown until the gift is restored. Their history stays.',
  giftRestore: 'Restore',
  giftRestoreNote: 'The gift goes back to the list and the app, switched on.',
  giftArchivedSince: 'Deleted on {date}',
};
