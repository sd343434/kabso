// v1.82-live (D295, owner, CONVENTIONS §10.108.6): the agency owner activates
// a member as «مضيف» or «صانع محتوى» — the two choices, the creator form, the
// note «نسبة صانع المحتوى 72%», the warning and its required tick, the
// server's refusals; the agency list's «تفعيل» and the member tags.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/presentation/agency_activation_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/creator_live_badge.dart';
import 'package:kabso_live/features/recruits/data/recruits_repository.dart'
    show CreatorCategory;
import 'package:kabso_live/l10n/gen/app_localizations_ar.dart';
import 'package:kabso_live/l10n/gen/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart';
import '../../helpers/pump_app.dart';

final _ar = AppLocalizationsAr();
final _en = AppLocalizationsEn();

/// A button that opens the sheet and keeps what it returns.
class _Opener extends StatefulWidget {
  const new({required this.member, required this.onResult});

  final AgencyHostRow member;
  final void Function(AgencyHostRow?) onResult;

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () async => widget.onResult(
          await showAgencyActivationSheet(context, widget.member),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

Future<(FakeAgencyRepository, List<AgencyHostRow?>)> _open(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.ar,
  AppFailure? failure,
}) async {
  final repo = FakeAgencyRepository(activateFailure: failure);
  final results = <AgencyHostRow?>[];
  final member = testHosts()[1];
  tester.view
    ..physicalSize = const Size(393 * 3, 1400 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    _Opener(member: member, onResult: results.add),
    language: language,
    overrides: [agencyRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return (repo, results);
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the two choices; nothing is sent before one is chosen', (
    tester,
  ) async {
    final (repo, _) = await _open(tester);
    expect(find.text(_ar.agencyActivateAsHost), findsOneWidget);
    // The choice's title and its purple badge read the same in Arabic.
    expect(find.text(_ar.agencyActivateAsCreator), findsNWidgets(2));
    expect(find.text(_ar.agencyActivateTitle('Mona')), findsOneWidget);
    // The creator choice carries the purple badge.
    expect(find.byType(CreatorLiveBadge), findsOneWidget);
    // No note, no warning before «صانع محتوى».
    expect(find.byKey(AgencyActivationSheet.noteKey), findsNothing);
    expect(find.byKey(AgencyActivationSheet.warningKey), findsNothing);
    final submit = find.byKey(AgencyActivationSheet.submitKey);
    await tester.ensureVisible(submit);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.activations, isEmpty);
  });

  testWidgets('«مضيف»: one tap activates the member as a host', (tester) async {
    final (repo, results) = await _open(tester);
    await _tapVisible(tester, find.byKey(AgencyActivationSheet.hostChoiceKey));
    expect(find.byKey(AgencyActivationSheet.warningKey), findsNothing);
    expect(find.text(_ar.agencyActivateHostButton), findsOneWidget);
    await _tapVisible(tester, find.byKey(AgencyActivationSheet.submitKey));
    expect(repo.activations, hasLength(1));
    expect(repo.activations.single.$1, 'u-h2');
    expect(repo.activations.single.$2.toJson(), {'as': 'HOST'});
    expect(results.single?.hosting, AgencyMemberHosting.host);
  });

  testWidgets('«صانع محتوى»: the note, the warning, the fields and the tick '
      'are required', (tester) async {
    final (repo, results) = await _open(tester);
    await _tapVisible(
      tester,
      find.byKey(AgencyActivationSheet.creatorChoiceKey),
    );
    expect(find.text(_ar.agencyCreatorShareNote), findsOneWidget);
    expect(_ar.agencyCreatorShareNote, 'نسبة صانع المحتوى 72%');
    expect(find.text(_ar.agencyCreatorWarning), findsOneWidget);
    expect(
      _ar.agencyCreatorWarning,
      'إن قمت بتفعيل شخص على أنه صانع محتوى ولم يكن كذلك، سيتم حظر الوكالة '
      'وخسارة أرباحك.',
    );
    // Without the tick the button is off.
    final submit = find.byKey(AgencyActivationSheet.submitKey);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.activations, isEmpty);
    // The tick alone is not enough: the fields are required.
    await _tapVisible(tester, find.byKey(AgencyActivationSheet.confirmKey));
    await _tapVisible(tester, submit);
    expect(repo.activations, isEmpty);
    expect(find.text(_ar.hostApplyCountryError), findsOneWidget);
    expect(find.text(_ar.creatorProgrammeLinkError), findsOneWidget);
    // Fill them in.
    await _tapVisible(tester, find.byKey(AgencyActivationSheet.countryKey));
    await tester.tap(find.text('مصر').last);
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(AgencyActivationSheet.categoryKey(CreatorCategory.comedy)),
    );
    await tester.enterText(
      find.byKey(AgencyActivationSheet.linkKey(0)),
      'https://www.tiktok.com/@mona',
    );
    await _tapVisible(tester, submit);
    expect(repo.activations, hasLength(1));
    expect(repo.activations.single.$2.toJson(), {
      'as': 'CREATOR',
      'country': 'EG',
      'category': 'COMEDY',
      'links': ['https://www.tiktok.com/@mona'],
      'confirmCreator': true,
    });
    expect(results.single?.hosting, AgencyMemberHosting.creator);
  });

  testWidgets('a refusal stays in the sheet with the reason', (tester) async {
    final (repo, results) = await _open(
      tester,
      failure: const ServerFailure(
        code: ErrorCode.agencyActivationNotAllowed,
        rawCode: 'AGENCY_ACTIVATION_NOT_ALLOWED',
        debugMessage: 'refused',
        statusCode: 409,
        details: [FieldIssue(field: 'member', issue: 'CREATOR')],
      ),
    );
    await _tapVisible(tester, find.byKey(AgencyActivationSheet.hostChoiceKey));
    await _tapVisible(tester, find.byKey(AgencyActivationSheet.submitKey));
    expect(repo.activations, hasLength(1));
    expect(results, isEmpty);
    expect(find.text(_ar.agencyActivationRefusedCreator), findsOneWidget);
  });

  testWidgets('English: the same sheet', (tester) async {
    await _open(tester, language: AppLanguage.en);
    await _tapVisible(
      tester,
      find.byKey(AgencyActivationSheet.creatorChoiceKey),
    );
    expect(find.text(_en.agencyCreatorShareNote), findsOneWidget);
    expect(find.text(_en.agencyCreatorWarning), findsOneWidget);
    expect(find.text(_en.agencyCreatorConfirm), findsOneWidget);
    expect(find.text(_en.agencyActivateCreatorButton), findsOneWidget);
  });

  test('AgencyHostRow reads hosting; unknown and older servers → none', () {
    Map<String, dynamic> row(Object? hosting) => {
      'user': {
        'id': 'u1',
        'username': 'a',
        'displayName': 'A',
        'avatarUrl': null,
      },
      'joinedAt': '2027-03-29T09:00:00.000Z',
      'liveDays': 0,
      'liveSeconds': 0,
      'active': false,
      'monthCherries': 0,
      'commissionEligible': true,
      'hosting': ?hosting,
      'activatedByAgency': hosting != null,
    };
    expect(
      AgencyHostRow.fromJson(row('CREATOR')).hosting,
      AgencyMemberHosting.creator,
    );
    expect(
      AgencyHostRow.fromJson(row('HOST')).hosting,
      AgencyMemberHosting.host,
    );
    expect(
      AgencyHostRow.fromJson(row('SOMETHING')).hosting,
      AgencyMemberHosting.none,
    );
    expect(AgencyHostRow.fromJson(row(null)).hosting, AgencyMemberHosting.none);
    expect(AgencyHostRow.fromJson(row('CREATOR')).activatedByAgency, isTrue);
  });
}
