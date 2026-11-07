/**
 * D295 (owner 2026-11-06: content creators go live «صانع محتوى»): the creators list's source and «فعّله وكيل: …», the
 * team's revocation of a membership, the host grant's refusal of a creator, and «حظر الوكالة — تفعيل صانع محتوى وهمي»
 * (OWNER: the amount forfeited shown before confirming). Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D295 = {
  statusREVOKED: 'مُلغاة العضوية',
  creatorSourceAPPLICATION: 'طلب من الشخص',
  creatorSourceAGENCY: 'تفعيل وكالة',
  creatorActivatedBy: 'فعّله وكيل: {agent}',
  creatorActivatedByAgency: 'الوكالة',
  creatorMemberActive: 'عضو الآن',
  creatorMemberEnded: 'انتهت العضوية',
  creatorRevoke: 'إلغاء العضوية',
  creatorRevokeTitle: 'إلغاء عضوية صانع المحتوى',
  creatorRevokeIntro:
    'تنتهي العضوية وصلاحية البث التي منحتها، ويُنهى بثه الجاري إن وُجد. يبقى الطلب محفوظاً مع السبب، ويمكنه التقديم من جديد.',
  creatorRevokedBy: 'ألغاها: {name}',
  agencyBan: 'حظر الوكالة — تفعيل صانع محتوى وهمي',
  agencyBanTitle: 'حظر الوكالة',
  agencyBanIntro:
    'تُغلق الوكالة نهائياً ويُحرَّر أعضاؤها، وتُلغى عضويات صناع المحتوى الوهميين الذين تحددهم أدناه فقط، ويخسر الوكيل أرباح الوكالة التي لم يسحبها بعد. لا يُسترجع ما سُحب، ولا تُمسّ أرباح المضيفين وصناع المحتوى.',
  agencyBanCommission: 'عمولة الوكالة للوكيل (صافية)',
  agencyBanBalance: 'رصيد الوكيل الآن',
  agencyBanLocked: 'كرز مقفل (مهام)',
  agencyBanHeld: 'محجوز لطلب سحب (لا يُمسّ)',
  agencyBanForfeit: 'سيُخصم من الوكيل',
  agencyBanCreators: 'صناع المحتوى الذين فعّلتهم الوكالة',
  agencyBanTickHint:
    'ضع علامة على الوهميين فقط: تُلغى عضوياتهم. من لا تضع عليه علامة يبقى صانع محتوى ويُحرَّر من الوكالة.',
  agencyBanTicked: 'المحدَّدون كوهميين: {n}',
  agencyBanNoCreators: 'لم تفعّل هذه الوكالة أي صانع محتوى.',
  agencyBanned: 'محظورة',
  agencyBannedOn: 'حُظرت في {date}: خُصم {forfeited} كرزة من {commission}',
  agencyBanDone: 'حُظرت الوكالة. خُصم {forfeited} كرزة.',
  agencyBanAlready: 'الوكالة محظورة من قبل؛ لم يتغير شيء.',
  agencyCloseReasonBANNED: 'حظر (تفعيل صانع محتوى وهمي)',
  d295ErrCreator: 'هذا الشخص صانع محتوى: صلاحية البث تتبع عضويته. لا يمكن أن يكون مضيفاً أيضاً.',
  d295ErrHost: 'هذا الشخص مضيف: لا يمكن أن يكون صانع محتوى أيضاً.',
  sourceCREATOR: 'صانع محتوى',
} as const;

export const EN_D295: Record<keyof typeof AR_D295, string> = {
  statusREVOKED: 'Membership ended',
  creatorSourceAPPLICATION: 'Own application',
  creatorSourceAGENCY: 'Agency activation',
  creatorActivatedBy: 'Activated by agent: {agent}',
  creatorActivatedByAgency: 'Agency',
  creatorMemberActive: 'Member now',
  creatorMemberEnded: 'Membership ended',
  creatorRevoke: 'End membership',
  creatorRevokeTitle: 'End the creator membership',
  creatorRevokeIntro:
    'The membership and the hosting permission it gave end, and a running live is ended. The application is kept with the reason; the person may apply again.',
  creatorRevokedBy: 'Ended by: {name}',
  agencyBan: 'Ban the agency — fake creator activation',
  agencyBanTitle: 'Ban the agency',
  agencyBanIntro:
    'The agency is closed for good and its members released, only the fake creators you tick below lose their membership, and the agent loses the agency earnings not withdrawn yet. Money already withdrawn is not taken back; the hosts’ and creators’ own earnings are not touched.',
  agencyBanCommission: 'Agency commission to the agent (net)',
  agencyBanBalance: 'Agent’s balance now',
  agencyBanLocked: 'Locked cherries (tasks)',
  agencyBanHeld: 'Held for a withdrawal (not touched)',
  agencyBanForfeit: 'To be forfeited',
  agencyBanCreators: 'Creators this agency activated',
  agencyBanTickHint:
    'Tick only the fake ones: their memberships end. Anyone not ticked stays a creator and is released from the agency.',
  agencyBanTicked: 'Ticked as fake: {n}',
  agencyBanNoCreators: 'This agency activated no creator.',
  agencyBanned: 'Banned',
  agencyBannedOn: 'Banned on {date}: {forfeited} of {commission} cherries forfeited',
  agencyBanDone: 'The agency is banned. {forfeited} cherries forfeited.',
  agencyBanAlready: 'The agency was banned before; nothing changed.',
  agencyCloseReasonBANNED: 'Banned (fake creator activation)',
  d295ErrCreator:
    'This person is a content creator: the hosting permission follows the membership. A creator cannot also be a host.',
  d295ErrHost: 'This person is a host: a host cannot also be a content creator.',
  sourceCREATOR: 'Content creator',
};
