import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The unread messages count behind the Messages tab's badge (D130).
///
/// There is no messaging API yet (D86: the contract has no conversations
/// endpoint), so nothing can be unread and the badge stays hidden; no count
/// is made up. When conversations exist this provider reads their unread
/// count and the bar shows it ("99+" above 99) with no other change.
final Provider<int> unreadMessagesProvider = Provider<int>((ref) => 0);
