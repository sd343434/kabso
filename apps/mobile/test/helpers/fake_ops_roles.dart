import 'package:kabso_live/features/settings/social/official_accounts.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';

// v1.139-social (D387): fakes of the official accounts and a fixed staff
// status (tests only).

class FakeOfficialAccounts implements OfficialAccountsRepository {
  new(this.accounts);

  final List<OfficialSocialAccount> accounts;
  int calls = 0;

  @override
  Future<List<OfficialSocialAccount>> list() async {
    calls++;
    return accounts;
  }
}

class FixedStaff extends StaffStatusController {
  new(this.status);

  final StaffStatus status;

  @override
  Future<StaffStatus> build() async => status;
}

List<OfficialSocialAccount> d387Accounts() => [
  for (final a in [
    {
      'platform': 'INSTAGRAM',
      'handle': '@kabso.live',
      'url': 'https://instagram.com/kabso.live',
    },
    {
      'platform': 'TIKTOK',
      'handle': '@kabso',
      'url': 'https://www.tiktok.com/@kabso',
    },
    {'platform': 'X', 'handle': '@kabsolive', 'url': 'https://x.com/kabsolive'},
    {
      'platform': 'YOUTUBE',
      'handle': 'Kabso Live',
      'url': 'https://youtube.com/@kabsolive',
    },
  ])
    ?OfficialSocialAccount.fromJson(a),
];

StaffStatus d387Status({
  required List<String> roles,
  bool scheduled = true,
  bool watch = false,
}) => StaffStatus(
  isStaff: watch,
  roles: roles,
  capabilities: [if (watch) StaffCapability.watch],
  authenticatorEnrolled: true,
  onShift: false,
  scheduledShift: scheduled,
);
