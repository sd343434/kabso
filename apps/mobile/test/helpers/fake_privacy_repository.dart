import 'dart:typed_data';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/privacy/privacy_repository.dart';

/// D198: the privacy API in memory — no document published by default (so no
/// consent is required), no export yet.
class FakePrivacyRepository implements PrivacyRepository {
  new({this.documents = const [], List<LegalDocument>? required})
    : required = required ?? [];

  List<LegalDocument> documents;
  List<LegalDocument> required;
  DataExportList list = const DataExportList(items: []);
  AppFailure? requestFailure;
  AppFailure? acceptFailure;
  AppFailure? downloadFailure;
  final List<String> requests = [];
  final List<List<String>> accepted = [];
  final List<String> downloads = [];

  @override
  Future<List<LegalDocument>> legalDocuments() async => documents;

  @override
  Future<ConsentStatus> consentStatus() async =>
      ConsentStatus(required: required, current: documents);

  @override
  Future<ConsentStatus> accept(List<LegalDocument> docs) async {
    final failure = acceptFailure;
    if (failure != null) throw failure;
    accepted.add([for (final d in docs) '${d.kind.wire}@${d.version}']);
    required = [];
    return ConsentStatus(required: required, current: documents);
  }

  @override
  Future<DataExportList> exports() async => list;

  @override
  Future<DataExport> requestExport(String password) async {
    requests.add(password);
    final failure = requestFailure;
    if (failure != null) throw failure;
    final job = DataExport(
      id: '0192f1c2-0000-7000-8000-000000000198',
      status: DataExportStatus.pending,
      requestedAt: DateTime.utc(2026, 11, 1, 9),
    );
    list = DataExportList(
      items: [job],
      nextAllowedAt: DateTime.utc(2026, 11, 2, 9),
    );
    return job;
  }

  @override
  Future<Uint8List> download(String exportId) async {
    downloads.add(exportId);
    final failure = downloadFailure;
    if (failure != null) throw failure;
    return Uint8List.fromList(const [0x50, 0x4b, 0x05, 0x06]);
  }
}
