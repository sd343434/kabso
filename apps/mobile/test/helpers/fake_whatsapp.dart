import 'dart:typed_data';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';

/// D355: a fake `/staff/whatsapp/*` for the widget tests and goldens (no
/// network). Synthetic customers only.
final d355Now = DateTime.utc(2026, 11, 10, 9, 30);

const waMe = WaStaffRef(userId: 'me', displayName: 'هدى', staffId: 'Kabso03');
const waMona = WaStaffRef(userId: 's2', displayName: 'منى', staffId: 'Kabso02');

/// D366: the payments agents of the transfer sheet.
const waKhalid = WaStaffRef(
  userId: 's3',
  displayName: 'خالد',
  staffId: 'Kabso04',
);
const waRana = WaStaffRef(userId: 's4', displayName: 'رنا', staffId: 'Kabso05');

WaConversation waConversation({
  String id = 'c1',
  String? name = 'سارة',
  bool open = true,
  WaStaffRef? assignedTo,
  bool assignedToMe = false,
  int unread = 2,
  bool windowOpen = true,
  String? preview = 'الإيصال',
  WaAccountCard? account,
  WaDepartment department = WaDepartment.general,
}) => WaConversation(
  id: id,
  phone: '+966500001001',
  name: name,
  open: open,
  assignedTo: assignedTo,
  assignedToMe: assignedToMe,
  unreadCount: unread,
  lastMessageAt: d355Now.subtract(const Duration(minutes: 4)),
  lastPreview: preview,
  windowOpen: windowOpen,
  windowClosesAt: windowOpen
      ? d355Now.add(const Duration(hours: 20))
      : d355Now.subtract(const Duration(hours: 3)),
  linkedAccount: account,
  department: department,
);

/// [reaction]: the golden font has no emoji, so the goldens leave it out.
List<WaMessage> waMessages({required bool ar, bool reaction = true}) => [
  WaMessage(
    id: 'm6',
    outbound: false,
    type: 'AUDIO',
    tick: WaTick.received,
    at: d355Now.subtract(const Duration(minutes: 4)),
    media: const WaMedia(
      state: WaMediaState.stored,
      voice: true,
      mime: 'audio/ogg',
    ),
  ),
  WaMessage(
    id: 'm5',
    outbound: false,
    type: 'DOCUMENT',
    tick: WaTick.received,
    at: d355Now.subtract(const Duration(minutes: 5)),
    media: const WaMedia(
      state: WaMediaState.typeRefused,
      voice: false,
      filename: 'a.exe',
    ),
  ),
  WaMessage(
    id: 'm4',
    outbound: true,
    type: 'TEXT',
    tick: WaTick.read,
    at: d355Now.subtract(const Duration(minutes: 10)),
    text: ar ? 'أرسلي صورة الإيصال من فضلك' : 'Please send the receipt',
    sentBy: waMe,
    reaction: reaction ? '👍' : null,
  ),
  WaMessage(
    id: 'm3',
    outbound: true,
    type: 'TEXT',
    tick: WaTick.failed,
    at: d355Now.subtract(const Duration(minutes: 12)),
    text: ar ? 'لحظة من فضلك' : 'One moment please',
    errorTitle: 'Message undeliverable',
    errorCode: 131026,
    sentBy: waMe,
  ),
  WaMessage(
    id: 'm2',
    outbound: false,
    type: 'TEXT',
    tick: WaTick.received,
    at: d355Now.subtract(const Duration(minutes: 14)),
    text: 'دفعت للوكيل ولم يصل الشحن',
  ),
  WaMessage(
    id: 'm1',
    outbound: false,
    type: 'TEXT',
    tick: WaTick.received,
    at: d355Now.subtract(const Duration(minutes: 15)),
    text: 'السلام عليكم',
  ),
  // D365: the day before — the chat's «أمس» separator.
  WaMessage(
    id: 'm0',
    outbound: false,
    type: 'TEXT',
    tick: WaTick.received,
    at: d355Now.subtract(const Duration(hours: 20)),
    text: ar ? 'مرحباً، عندي مشكلة في الشحن' : 'Hi, I have a top-up problem',
  ),
];

class FakeWaRepository implements WaRepository {
  new({
    this.enabled = true,
    List<WaConversation>? list,
    WaConversation? conversation,
    List<WaMessage>? messages,
    this.sendError,
  }) : list = list ?? [waConversation()],
       current = conversation ?? waConversation(),
       msgs = messages ?? waMessages(ar: true);

  bool enabled;
  List<WaConversation> list;
  WaConversation current;
  List<WaMessage> msgs;
  AppFailure? sendError;

  final List<WaFilter> filters = [];

  /// D366: the department of each list read (null: all).
  final List<WaDepartment?> departments = [];

  /// D366: each transfer (department, to, note).
  final List<(WaDepartment, String?, String?)> transfers = [];

  /// D366: what a transfer answers (default: [current] moved as asked).
  WaConversation Function(WaDepartment department, String? to)? afterTransfer;

  /// D366: the agents of each department (default: [waMona] in GENERAL,
  /// [waKhalid] and [waRana] in PAYMENTS).
  Map<WaDepartment, List<WaAgent>> agentsBy = {
    WaDepartment.general: const [WaAgent(ref: waMona, onShift: true)],
    WaDepartment.payments: const [
      WaAgent(
        ref: waKhalid,
        onShift: true,
        departments: [WaDepartment.payments],
        openCount: 1,
      ),
      WaAgent(
        ref: waRana,
        onShift: false,
        departments: [WaDepartment.payments, WaDepartment.technical],
        openCount: 3,
      ),
    ],
  };
  final List<String> sentTexts = [];
  final List<(String, List<String>)> sentTemplates = [];
  final List<String> actions = [];
  int reads = 0;

  WaMessage _out(String text) => WaMessage(
    id: 'n${sentTexts.length}',
    outbound: true,
    type: 'TEXT',
    tick: WaTick.sent,
    at: d355Now,
    text: text,
    sentBy: waMe,
  );

  @override
  Future<WaSummary> summary() async => enabled
      ? const WaSummary(enabled: true, badge: 3, mine: 1, unassigned: 2)
      : WaSummary.off;

  @override
  Future<List<WaConversation>> conversations(
    WaFilter filter, {
    String? q,
    WaDepartment? department,
  }) async {
    filters.add(filter);
    departments.add(department);
    return department == null
        ? list
        : [
            for (final c in list)
              if (c.department == department) c,
          ];
  }

  @override
  Future<WaConversation> conversation(String id) async => current;

  @override
  Future<List<WaMessage>> messages(String id) async => msgs;

  @override
  Future<List<WaNote>> notes(String id) async => const [];

  @override
  Future<WaMessage> sendText(String id, String text) async {
    final e = sendError;
    if (e != null) throw e;
    sentTexts.add(text);
    return _out(text);
  }

  @override
  Future<WaMessage> sendTemplate(
    String id,
    WaTemplate template,
    List<String> parameters,
  ) async {
    sentTemplates.add((template.name, parameters));
    return _out(template.body ?? template.name);
  }

  @override
  Future<WaMessage> sendMedia(
    String id,
    Uint8List bytes, {
    required String mime,
    required String filename,
  }) async => _out(filename);

  @override
  Future<Uint8List> media(String messageId) async => Uint8List(0);

  @override
  Future<WaConversation> markRead(String id) async {
    reads += 1;
    return current;
  }

  @override
  Future<WaConversation> act(String id, String action) async {
    actions.add(action);
    return current;
  }

  @override
  Future<WaConversation> transfer(
    String id, {
    required WaDepartment department,
    String? toUserId,
    String? note,
  }) async {
    actions.add('transfer:${toUserId ?? department.wire}');
    transfers.add((department, toUserId, note));
    final f = afterTransfer;
    if (f != null) return current = f(department, toUserId);
    final agent = [for (final l in agentsBy.values) ...l]
        .where((a) => a.ref.userId == toUserId)
        .firstOrNull;
    return current = WaConversation(
      id: current.id,
      phone: current.phone,
      name: current.name,
      open: current.open,
      assignedTo: agent?.ref,
      assignedToMe: false,
      unreadCount: current.unreadCount,
      lastMessageAt: current.lastMessageAt,
      lastPreview: current.lastPreview,
      windowOpen: current.windowOpen,
      windowClosesAt: current.windowClosesAt,
      linkedAccount: current.linkedAccount,
      department: department,
    );
  }

  @override
  Future<WaNote> addNote(String id, String body) async =>
      WaNote(id: 'note', body: body, at: d355Now, author: waMe);

  @override
  Future<WaConversation> link(String id, String username) async => current;

  @override
  Future<WaConversation> unlink(String id) async => current;

  @override
  Future<List<WaTemplate>> templates() async => const [
    WaTemplate(
      name: 'kabso_followup',
      language: 'ar',
      body: 'مرحباً {{1}}، هل ما زلت تحتاج المساعدة في طلبك {{2}}؟',
      parameterCount: 2,
    ),
  ];

  @override
  Future<List<WaQuickReply>> quickReplies() async => const [
    WaQuickReply(id: 'q1', title: 'ترحيب', body: 'أهلاً بك في دعم Kabso Live'),
  ];

  @override
  Future<List<WaAgent>> agents({WaDepartment? department}) async =>
      department == null
      ? [for (final l in agentsBy.values) ...l]
      : agentsBy[department] ?? const [];

  @override
  Future<bool> pushMuted() async => false;

  @override
  Future<bool> setPushMuted({required bool muted}) async => muted;
}
