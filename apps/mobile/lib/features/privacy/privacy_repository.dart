import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/interceptors.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// `LegalDocumentKind` (v1.66-social, D198).
enum LegalKind {
  terms('TERMS'),
  privacy('PRIVACY');

  new(this.wire);

  final String wire;

  static LegalKind? fromWire(Object? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// `LegalDocument`: one published version of the terms or the privacy
/// policy, with the summary of changes the consent screen shows.
@immutable
final class LegalDocument {
  const new({
    required this.kind,
    required this.version,
    required this.effectiveAt,
    required this.url,
    required this.summaryAr,
    required this.summaryEn,
  });

  final LegalKind kind;
  final String version;
  final DateTime effectiveAt;
  final String url;
  final String summaryAr;
  final String summaryEn;

  static LegalDocument? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final kind = LegalKind.fromWire(raw['kind']);
    if (kind == null) return null;
    return LegalDocument(
      kind: kind,
      version: raw['version']! as String,
      effectiveAt: DateTime.parse(raw['effectiveAt']! as String),
      url: raw['url']! as String,
      summaryAr: raw['summaryAr']! as String,
      summaryEn: raw['summaryEn']! as String,
    );
  }

  static List<LegalDocument> listFrom(Object? raw) => [
    for (final d in (raw as List<dynamic>?) ?? const <dynamic>[])
      ?LegalDocument.tryParse(d),
  ];
}

/// `ConsentStatus`: what the caller must accept now.
@immutable
final class ConsentStatus {
  const new({required this.required, required this.current});

  factory fromJson(Map<String, dynamic> json) => ConsentStatus(
    required: LegalDocument.listFrom(json['required']),
    current: LegalDocument.listFrom(json['current']),
  );

  final List<LegalDocument> required;
  final List<LegalDocument> current;
}

/// `DataExport.status`. RUNNING is shown as [pending] by the server.
enum DataExportStatus {
  pending('PENDING'),
  ready('READY'),
  downloaded('DOWNLOADED'),
  expired('EXPIRED'),
  failed('FAILED');

  new(this.wire);

  final String wire;

  static DataExportStatus fromWire(Object? value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => failed);
}

/// `DataExport` (v1.66-social, D198).
@immutable
final class DataExport {
  const new({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.expiresAt,
    this.downloadedAt,
    this.sizeBytes,
  });

  factory fromJson(Map<String, dynamic> json) => DataExport(
    id: json['id']! as String,
    status: DataExportStatus.fromWire(json['status']),
    requestedAt: DateTime.parse(json['requestedAt']! as String),
    expiresAt: _date(json['expiresAt']),
    downloadedAt: _date(json['downloadedAt']),
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  );

  final String id;
  final DataExportStatus status;
  final DateTime requestedAt;
  final DateTime? expiresAt;
  final DateTime? downloadedAt;
  final int? sizeBytes;
}

DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

/// `DataExportList`: the latest exports, newest first.
@immutable
final class DataExportList {
  const new({required this.items, this.nextAllowedAt});

  factory fromJson(Map<String, dynamic> json) => DataExportList(
    items: [
      for (final e in json['items']! as List<dynamic>)
        DataExport.fromJson(e as Map<String, dynamic>),
    ],
    nextAllowedAt: _date(json['nextAllowedAt']),
  );

  final List<DataExport> items;

  /// When a new export may be asked for; null = now.
  final DateTime? nextAllowedAt;

  DataExport? get latest => items.isEmpty ? null : items.first;
}

/// Privacy (openapi v1.66-social DRAFT, D198, CONVENTIONS §10.61): the legal
/// documents in force, the consent screen and «تنزيل بياناتي». Every method
/// throws an `AppFailure`.
abstract interface class PrivacyRepository {
  /// `GET /legal/documents` (public; the sign-up screen).
  Future<List<LegalDocument>> legalDocuments();

  /// `GET /me/consents` (works while consent is required).
  Future<ConsentStatus> consentStatus();

  /// `POST /me/consents`: accepts [docs] (the versions in force).
  Future<ConsentStatus> accept(List<LegalDocument> docs);

  /// `GET /me/data-exports`.
  Future<DataExportList> exports();

  /// `POST /me/data-exports` (the password again) → the PENDING job.
  Future<DataExport> requestExport(String password);

  /// `POST /me/data-exports/{id}/link` then `GET` the file (once).
  Future<Uint8List> download(String exportId);
}

class PrivacyRepositoryImpl implements PrivacyRepository {
  new(this._dio, this._bareDio);

  final Dio _dio;
  final Dio _bareDio;

  @override
  Future<List<LegalDocument>> legalDocuments() => guardApiCall(() async {
    final res = await _bareDio.get<Map<String, dynamic>>(
      '/legal/documents',
      options: publicEndpoint(),
    );
    return LegalDocument.listFrom(res.data!['documents']);
  });

  @override
  Future<ConsentStatus> consentStatus() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/consents');
    return ConsentStatus.fromJson(res.data!);
  });

  @override
  Future<ConsentStatus> accept(List<LegalDocument> docs) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/consents',
          data: {
            'accept': [
              for (final d in docs) {'kind': d.kind.wire, 'version': d.version},
            ],
          },
        );
        return ConsentStatus.fromJson(res.data!);
      });

  @override
  Future<DataExportList> exports() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/data-exports');
    return DataExportList.fromJson(res.data!);
  });

  @override
  Future<DataExport> requestExport(String password) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/data-exports',
      data: {'password': password},
    );
    return DataExport.fromJson(res.data!);
  });

  @override
  Future<Uint8List> download(String exportId) => guardApiCall(() async {
    final link = await _dio.post<Map<String, dynamic>>(
      '/me/data-exports/${Uri.encodeComponent(exportId)}/link',
    );
    // `path` starts with `/api/v1`; the client's base URL already ends there.
    final path = (link.data!['path']! as String).replaceFirst('/api/v1', '');
    final file = await _dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    return Uint8List.fromList(file.data!);
  });
}

final privacyRepositoryProvider = Provider<PrivacyRepository>(
  (ref) => PrivacyRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(bareDioProvider),
  ),
);

/// The caller's exports (the «تنزيل بياناتي» screen).
final FutureProvider<DataExportList> dataExportsProvider =
    FutureProvider.autoDispose<DataExportList>(
      (ref) => ref.watch(privacyRepositoryProvider).exports(),
    );

/// The legal documents in force (sign-up), or empty when the server has none
/// or cannot be reached (the 18+ statement is still sent).
final FutureProvider<List<LegalDocument>> legalDocumentsProvider =
    FutureProvider.autoDispose<List<LegalDocument>>((ref) async {
      try {
        return await ref.watch(privacyRepositoryProvider).legalDocuments();
      } on Object {
        return const [];
      }
    });

/// The consent screen's documents.
final FutureProvider<ConsentStatus> consentStatusProvider =
    FutureProvider.autoDispose<ConsentStatus>(
      (ref) => ref.watch(privacyRepositoryProvider).consentStatus(),
    );
