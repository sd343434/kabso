import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// v1.109-social (D344, CONVENTIONS §10.143; owner: «اريد جعل الشحن من
/// الموقع يفتح من نفس التطبيق ويدخل اليوزر والباسورد تلقائي»): the website
/// top-up page opened already signed in. The server mints a one-time code
/// (60 s, single use) and answers the page address with the code in its
/// fragment (`…/topup?lang=ar#h=…`); the page exchanges it for its own
/// session. The app never sends or stores the password, and never keeps the
/// address.
abstract interface class TopupWebsiteRepository {
  /// `POST /wallet/topup-session` — the address to open once. Throws an
  /// `AppFailure` (e.g. 503 when the link is off for this platform).
  Future<Uri> websiteSession();
}

class TopupWebsiteRepositoryImpl implements TopupWebsiteRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<Uri> websiteSession() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('/wallet/topup-session');
    final uri = Uri.tryParse(res.data?['websiteUrl'] as String? ?? '');
    // Only an https address with the code in the fragment is opened.
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.fragment.startsWith('h=')) {
      throw const FormatException('websiteUrl');
    }
    return uri;
  });
}

final topupWebsiteRepositoryProvider = Provider<TopupWebsiteRepository>(
  (ref) => TopupWebsiteRepositoryImpl(ref.watch(apiDioProvider)),
);
