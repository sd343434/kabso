/**
 * D283c (owner: «ايدي للمشرفين والادارة بحيث ايدي الموظفين يبدأ Kabso01»): the official staff ID «Kabso01» on each card
 * of «الموظفون والصلاحيات», the search of the staff list (staff ID, name, username or email) and the staff ID in the
 * next steps after a grant. Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D283C = {
  staffIdLabel: "ID: {id}",
  staffIdTitle: "رقم الموظف الرسمي",
  staffSearch: "ابحث بـ ID الموظف أو الاسم أو البريد",
  staffSearchNone: "لا يوجد موظف يطابق «{q}».",
  staffNextId: "رقم الموظف: {id} — يظهر في التطبيق مكان اسم المستخدم.",
  staffIdNote: "لكل موظف رقم رسمي (Kabso01، Kabso02، …) يُعطى مع أول صلاحية ويبقى له، ولا يُعطى لغيره أبدًا.",
};

export const EN_D283C: typeof AR_D283C = {
  staffIdLabel: "ID: {id}",
  staffIdTitle: "Official staff ID",
  staffSearch: "Search by staff ID, name or email",
  staffSearchNone: "No staff member matches “{q}”.",
  staffNextId: "Staff ID: {id} — shown in the app instead of the username.",
  staffIdNote:
    "Each staff member has an official ID (Kabso01, Kabso02, …) given with their first role; it stays theirs and is never given to anyone else.",
};
