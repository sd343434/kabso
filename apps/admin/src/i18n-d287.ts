/** D287 an agent's employees and what each did for the agent («الموظفون»): merged into i18n.ts. Arabic first. */
export const AR_D287 = {
  agentEmployees: 'الموظفون',
  agentEmployeesTitle: 'موظفو {name}',
  agentEmployeesIntro:
    'ما فعله كل موظف لصالح الوكيل: المبيعات، شراء الكرز (عملات دخلت المخزون) والطلبات المنجزة (عملات للمشترين). اليوم / ٧ أيام / ٣٠ يوماً.',
  agentEmployeesEmpty: 'لا موظفين.',
  empSales: 'المبيعات',
  empCherries: 'شراء الكرز',
  empOrders: 'الطلبات المنجزة',
  empPerms: 'الصلاحيات',
  empCanBuy: 'يمكنه شراء الكرز',
  empReceives: 'يستقبل طلبات الشراء',
  empOnShift: 'في الدوام',
  empRemoved: 'أُزيل {date}',
  empTotals: '{today} / {d7} / {d30}',
};
export const EN_D287: Record<keyof typeof AR_D287, string> = {
  agentEmployees: 'Employees',
  agentEmployeesTitle: '{name}’s employees',
  agentEmployeesIntro:
    'What each employee did for the agent: sales, cherry purchases (coins into the stock) and orders done (coins to buyers). Today / 7 days / 30 days.',
  agentEmployeesEmpty: 'No employees.',
  empSales: 'Sales',
  empCherries: 'Cherry purchases',
  empOrders: 'Orders done',
  empPerms: 'Permissions',
  empCanBuy: 'Can buy cherries',
  empReceives: 'Receives purchase orders',
  empOnShift: 'On shift',
  empRemoved: 'Removed {date}',
  empTotals: '{today} / {d7} / {d30}',
};
