import { Injectable, Logger } from '@nestjs/common';
import { safeErrorLog } from '../../logging/redact-text.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';

export enum AuditAction {
  // Verify-first registration (contract v1.2 §6). Namespaced `auth.` like every other action.
  REGISTRATION_PENDING_CREATED = 'auth.registration.pending_created',
  REGISTRATION_REPLACED = 'auth.registration.replaced',
  REGISTRATION_VERIFIED = 'auth.registration.verified',
  REGISTRATION_VERIFY_FAILED = 'auth.registration.verify_failed',
  REGISTRATION_EXISTING_EMAIL_NOTICE = 'auth.registration.existing_email_notice',
  LOGIN_SUCCESS = 'auth.login.success',
  LOGIN_FAILURE = 'auth.login.failure',
  LOGIN_RATE_LIMITED = 'auth.login.rate_limited',
  LOGOUT = 'auth.logout',
  REFRESH_REUSE = 'auth.refresh.reuse',
  /** CONVENTIONS §6 `refresh.invalid_secret` (namespaced like every other auth action). */
  REFRESH_INVALID_SECRET = 'auth.refresh.invalid_secret',
  EMAIL_VERIFIED = 'auth.email.verified',
  PASSWORD_RESET_REQUESTED = 'auth.password.reset_requested',
  PASSWORD_RESET = 'auth.password.reset',
  SESSION_REVOKED = 'auth.session.revoke',
  /** v1.79-social (D226, §10.76): every other session signed out; `metadata.count`. */
  SESSIONS_REVOKED_OTHERS = 'auth.sessions.revoke_others',
  /** v1.79-social (D226): the password re-check of «sign out of all other devices» failed. */
  SESSIONS_REVOKE_OTHERS_REAUTH_FAILED = 'auth.sessions.revoke_others.reauth_failed',
  // Contract v1.3 (CONVENTIONS §10.3). Heartbeats are not audited.
  LIVE_ROOM_START = 'live.room.start',
  /** Host end or suspension; `metadata.reason` carries the end reason. */
  LIVE_ROOM_END = 'live.room.end',
  /** Ended for a stale heartbeat (sweeper or a read path). */
  LIVE_ROOM_TIMEOUT = 'live.room.timeout',
  // v1.6-live (DRAFT, CP-010): the hosting permission and the room's guests switch.
  LIVE_HOST_GRANT = 'live.host.grant',
  LIVE_HOST_REVOKE = 'live.host.revoke',
  LIVE_ROOM_GUESTS = 'live.room.guests',
  // v1.9-live (DRAFT, CP-013): the host turned the room chat off or on.
  LIVE_ROOM_CHAT = 'live.room.chat',
  /** v1.47-live (D212): a podcast's hands opened / closed or its question duration changed. */
  LIVE_ROOM_PODCAST = 'live.room.podcast',
  // v1.10-live (DRAFT, CP-014): the host edited the live's title, category or topic.
  LIVE_ROOM_EDIT = 'live.room.edit',
  // v1.11-live (DRAFT, CP-015): the host set or removed the live cover.
  LIVE_COVER_UPDATE = 'live.cover.update',
  // v1.12-live (DRAFT, CP-016 B): the host replaced their blocked words (the count is logged).
  LIVE_BLOCKED_WORDS_UPDATE = 'live.blocked_words.update',
  // v1.14-live (DRAFT, CP-016 C): the host announced or cancelled a scheduled live.
  LIVE_SCHEDULE_CREATE = 'live.schedule.create',
  LIVE_SCHEDULE_DELETE = 'live.schedule.delete',
  // v1.20-live (DRAFT, D105): the host or a moderator kicked someone out of a live, or undid it.
  LIVE_KICK = 'live.kick',
  LIVE_KICK_UNDO = 'live.kick.undo',
  // v1.4-levels (DRAFT, CP-005): every admin mutation of the level systems.
  LEVELS_CATEGORY_UPDATE = 'levels.category.update',
  LEVELS_VERSION_CREATE = 'levels.version.create',
  LEVELS_VERSION_UPDATE = 'levels.version.update',
  LEVELS_VERSION_PUBLISH = 'levels.version.publish',
  LEVELS_USER_RECALCULATE = 'levels.user.recalculate',
  LEVELS_USER_ADJUST = 'levels.user.adjust',
  LEVELS_RECONCILIATION_RUN = 'levels.reconciliation.run',
  LEVELS_EVENT_RETRY = 'levels.event.retry',
  LEVELS_PERMISSION_GRANT = 'levels.permission.grant',
  LEVELS_PERMISSION_REVOKE = 'levels.permission.revoke',
  // v1.5-social (CP-006 M1): moderation of reports (CONVENTIONS §11.7).
  MODERATION_REPORT_ACTION = 'moderation.report.action',
  // v1.19-live (DRAFT, CP-017): coins granted or taken back by an admin (`wallet-admin`).
  WALLET_GRANT = 'wallet.grant',
  WALLET_REVOKE = 'wallet.revoke',
  /** v1.21-live (CP-018): a family was created, handed over, disbanded, or a member removed. */
  FAMILY_CREATE = 'family.create',
  FAMILY_TRANSFER = 'family.transfer',
  FAMILY_DISBAND = 'family.disband',
  FAMILY_MEMBER_REMOVE = 'family.member.remove',
  /** v1.21-live (CP-018): `medals-admin backfill` ran. */
  MEDALS_BACKFILL = 'medals.backfill',
  /** v1.22-live (CP-019): a bag item granted or taken back by an admin (`bag-admin`). */
  BAG_GRANT = 'bag.grant',
  BAG_REVOKE = 'bag.revoke',
  /** v1.23-live (CP-020, D108): the gift catalogue and gift-bag grants (`gift-admin` CLI). */
  GIFT_ADD = 'gift.add',
  GIFT_UPDATE = 'gift.update',
  GIFT_DISABLE = 'gift.disable',
  GIFT_ENABLE = 'gift.enable',
  GIFT_GRANT = 'gift.grant',
  /** v1.46-live (D207, §10.66): the gift categories (panel tabs), changed in the panel or with `gift-admin category-*`. */
  GIFT_CATEGORY_ADD = 'gift.category.add',
  GIFT_CATEGORY_UPDATE = 'gift.category.update',
  GIFT_CATEGORY_ENABLE = 'gift.category.enable',
  GIFT_CATEGORY_DISABLE = 'gift.category.disable',
  GIFT_CATEGORY_DELETE = 'gift.category.delete',
  // D124 (v1.26-live): home banners, changed only by the banner-admin CLI.
  BANNER_ADD = 'banner.add',
  BANNER_ENABLE = 'banner.enable',
  BANNER_DISABLE = 'banner.disable',
  BANNER_REMOVE = 'banner.remove',
  /** v1.27-live (D132): the caller's one-time 18+ statement for lucky gifts. */
  LUCKY_AGE_CONFIRM = 'lucky.age_confirm',
  /** v1.27.1-live (D133): featured hosts, changed only by the feature-admin CLI. */
  LIVE_FEATURE_ADD = 'live.feature.add',
  LIVE_FEATURE_REMOVE = 'live.feature.remove',
  /** v1.33-live (D154b): traffic cards granted by the boost-admin CLI. */
  LIVE_BOOST_CARD_GRANT = 'live.boost_card.grant',
  // v1.43-live (D195, §10.58): PK 1 v 1 — a match starts, its battle ends (with the reason), a
  // moderator ends one (`pk-admin end`, with the reason), a host switches invitations.
  LIVE_PK_START = 'live.pk.start',
  LIVE_PK_END = 'live.pk.end',
  LIVE_PK_ADMIN_END = 'live.pk.admin_end',
  LIVE_PK_SETTINGS = 'live.pk.settings',
  /**
   * v1.50-live (D229, §10.80): «PK أحكام» — the server's draw {options, drawn, level}, the loser's answer (accepted /
   * refused, or the decision time ran out), the winner's verdict, an end without a verdict (timer, a host gone, a
   * moderator), the PK points written for a match {host, kind, points}, a dare reported by a viewer, and a dare
   * disabled automatically after enough reports.
   */
  LIVE_PK_DARE_DRAW = 'live.pk.dare.draw',
  LIVE_PK_DARE_ANSWER = 'live.pk.dare.answer',
  LIVE_PK_DARE_VERDICT = 'live.pk.dare.verdict',
  LIVE_PK_DARE_END = 'live.pk.dare.end',
  LIVE_PK_POINTS = 'live.pk.points',
  LIVE_PK_DARE_REPORT = 'live.pk.dare.report',
  PK_DARE_AUTO_DISABLE = 'pk_dare.auto_disable',
  /** v1.50-live (D229): the dare library from the panel or `pk-dares-admin` {before, after, reason, via}. */
  PK_DARE_CREATE = 'pk_dare.create',
  PK_DARE_UPDATE = 'pk_dare.update',
  PK_DARE_IMPORT = 'pk_dare.import',
  PK_DARE_REPORTS_CLEAR = 'pk_dare.reports_clear',
  PK_DARE_SETTINGS_UPDATE = 'pk_dare.settings.update',
  // v1.45-live (D201, §10.63): the host's live tools — a second-camera pairing code created, redeemed
  // (or refused, with the reason, never the code), the second camera ended, the main feed chosen; the
  // one-time music-rights notice accepted; a clip recording started or stopped (viewers are told).
  LIVE_SECOND_CAMERA_CODE = 'live.second_camera.code',
  LIVE_SECOND_CAMERA_REDEEM = 'live.second_camera.redeem',
  LIVE_SECOND_CAMERA_REFUSED = 'live.second_camera.refused',
  LIVE_SECOND_CAMERA_END = 'live.second_camera.end',
  LIVE_SECOND_CAMERA_MAIN = 'live.second_camera.main',
  LIVE_MUSIC_RIGHTS_ACCEPT = 'live.music.rights_accept',
  LIVE_RECORDING_START = 'live.recording.start',
  LIVE_RECORDING_STOP = 'live.recording.stop',
  /** v1.44-social (D166): events and tasks, changed only by the event-admin and task-admin CLIs. */
  EVENT_CREATE = 'event.create',
  EVENT_END = 'event.end',
  EVENT_HOLD = 'event.hold',
  EVENT_RELEASE = 'event.release',
  /** v1.50-social (D176): an event's calendar line, tone or «رائج» changed. */
  EVENT_STYLE = 'event.style',
  TASK_UPDATE = 'task.update',
  /** v1.52-social (D179): the cherry economy — agencies, complaints, withdrawals, reversals. */
  AGENCY_CREATE = 'agency.create',
  AGENCY_PARENT = 'agency.parent',
  AGENCY_JOIN = 'agency.join',
  AGENCY_LEAVE = 'agency.leave',
  AGENCY_COMPLAINT = 'agency.complaint',
  AGENCY_COMPLAINT_RESOLVE = 'agency.complaint.resolve',
  CHERRY_WITHDRAWAL_REQUEST = 'cherry.withdrawal.request',
  CHERRY_WITHDRAWAL_PAY = 'cherry.withdrawal.pay',
  CHERRY_WITHDRAWAL_REJECT = 'cherry.withdrawal.reject',
  CHERRY_GIFT_REVERSE = 'cherry.gift.reverse',
  // v1.54-social (DRAFT, D185): recharge agents (CONVENTIONS §10.48).
  RECHARGE_APPLICATION_SUBMIT = 'recharge.application.submit',
  RECHARGE_APPLICATION_VIEW = 'recharge.application.view',
  RECHARGE_APPLICATION_APPROVE = 'recharge.application.approve',
  RECHARGE_APPLICATION_REJECT = 'recharge.application.reject',
  RECHARGE_TOPUP = 'recharge.topup',
  RECHARGE_ACTIVATE = 'recharge.activate',
  RECHARGE_SUSPEND = 'recharge.suspend',
  RECHARGE_REINSTATE = 'recharge.reinstate',
  RECHARGE_CAP = 'recharge.cap',
  SPECIAL_USERNAME_GRANT = 'special_username.grant',
  SPECIAL_USERNAME_END = 'special_username.end',
  SPECIAL_USERNAME_VIEW = 'special_username.view',
  // v1.58-social (DRAFT, D189): host agents' perks (CONVENTIONS §10.52).
  HOST_AGENT_ACTIVATE = 'host_agent.activate',
  HOST_AGENT_SUSPEND = 'host_agent.suspend',
  HOST_AGENT_REINSTATE = 'host_agent.reinstate',
  RECHARGE_SALE = 'recharge.sale',
  RECHARGE_EMPLOYEE_ADD = 'recharge.employee.add',
  RECHARGE_EMPLOYEE_UPDATE = 'recharge.employee.update',
  RECHARGE_EMPLOYEE_REMOVE = 'recharge.employee.remove',
  RECHARGE_AVAILABILITY = 'recharge.availability',
  RECHARGE_CHERRY_REQUEST = 'recharge.cherry.request',
  RECHARGE_CHERRY_CONFIRM = 'recharge.cherry.confirm',
  RECHARGE_CHERRY_DECLINE = 'recharge.cherry.decline',
  RECHARGE_CHERRY_CANCEL = 'recharge.cherry.cancel',
  RECHARGE_PURGE = 'recharge.purge',
  // v1.55-social (DRAFT, D186): the active-host frame (CONVENTIONS §10.49). Grants, revokes and swaps are
  // the server's (actor null); a choice is the host's.
  HOST_FRAME_GRANT = 'host_frame.grant',
  HOST_FRAME_REVOKE = 'host_frame.revoke',
  HOST_FRAME_SWAP = 'host_frame.swap',
  HOST_FRAME_CHOICE = 'host_frame.choice',
  // v1.59-social (DRAFT, D190): card top-ups through Stripe (CONVENTIONS §10.53). Webhook actions have no actor.
  TOPUP_CHECKOUT_CREATE = 'topup.checkout.create',
  TOPUP_CREDIT = 'topup.credit',
  TOPUP_STATUS = 'topup.status',
  TOPUP_REVERSE = 'topup.reverse',
  TOPUP_RESTORE = 'topup.restore',
  TOPUP_FREEZE = 'topup.freeze',
  TOPUP_UNFREEZE = 'topup.unfreeze',
  TOPUP_AUTO_REFUND = 'topup.auto_refund',
  TOPUP_ADMIN_REFUND = 'topup.admin_refund',
  TOPUP_DISPUTE_EVIDENCE = 'topup.dispute.evidence',
  TOPUP_CASE_OPEN = 'topup.case.open',
  TOPUP_CASE_CLOSE = 'topup.case.close',
  TOPUP_EVENT_UNMATCHED = 'topup.event.unmatched',
  // v1.28-live (DRAFT, D146): premium usernames and the username change (CONVENTIONS §10.32).
  USERNAME_CHANGE = 'user.username.change',
  /** v1.45-social (D168): the caller changed their display name and/or bio (field names only). */
  PROFILE_UPDATE = 'user.profile.update',
  /** v1.45-social (D168): the caller set or removed their profile photo. */
  AVATAR_UPDATE = 'user.avatar.update',
  /** v1.47-social (D175): the user switched their account private or public. */
  PRIVACY_PRIVATE = 'user.privacy.private',
  /** v1.47-social (D175): an admin removed a user's profile photo (`profile-admin remove-avatar`). */
  ADMIN_AVATAR_REMOVE = 'admin.avatar.remove',
  /** v1.76-social (D218): the caller set or removed their profile cover. */
  COVER_UPDATE = 'user.cover.update',
  /** v1.76-social (D218): an admin removed a user's profile cover (panel or `profile-admin remove-cover`). */
  ADMIN_COVER_REMOVE = 'admin.cover.remove',
  PREMIUM_USERNAME_RENT = 'premium_username.rent',
  PREMIUM_USERNAME_RENEW = 'premium_username.renew',
  PREMIUM_USERNAME_GRANT = 'premium_username.grant',
  PREMIUM_USERNAME_REVOKE = 'premium_username.revoke',
  PREMIUM_USERNAME_RELEASE = 'premium_username.release',
  PREMIUM_USERNAME_EXPIRE = 'premium_username.expire',
  PREMIUM_USERNAME_GRACE_END = 'premium_username.grace_end',
  PREMIUM_USERNAME_PRICE = 'premium_username.price',
  PREMIUM_USERNAME_RESERVE = 'premium_username.reserve',
  // v1.62-social (DRAFT, D193): account deletion (CONVENTIONS §10.56). `requested`/`cancelled` by the person (or an
  // admin, `via: 'cli'`), `purged` by the sweeper or `account-admin purge-now`; `blocked` = a refused request.
  ACCOUNT_DELETION_REQUESTED = 'account.deletion.requested',
  ACCOUNT_DELETION_BLOCKED = 'account.deletion.blocked',
  ACCOUNT_DELETION_REAUTH_FAILED = 'account.deletion.reauth_failed',
  ACCOUNT_DELETION_CANCELLED = 'account.deletion.cancelled',
  ACCOUNT_DELETION_PURGED = 'account.deletion.purged',
  // D193 (owner 2026-10-31): a legal hold (reported content of a purged account) read with `account-admin` (each view),
  // deleted by the sweeper after REPORT_LEGAL_HOLD_DAYS; `retention_ended`: tombstones whose ledgers and audit rows
  // reached DELETED_LEDGER_RETENTION_DAYS (one row per sweep, a count only).
  ACCOUNT_DELETION_HOLD_VIEWED = 'account.deletion.hold_viewed',
  ACCOUNT_DELETION_HOLD_EXPIRED = 'account.deletion.hold_expired',
  ACCOUNT_DELETION_RETENTION_ENDED = 'account.deletion.retention_ended',
  // v1.66-social (DRAFT, D198): privacy (CONVENTIONS §10.61). Legal documents published with `legal-admin`, consents
  // accepted in the app or at sign-up, and the personal-data export «تنزيل بياناتي» (requested, built, downloaded,
  // expired, failed, refused for a wrong password or the 24-hour limit; `privacy-admin` views and admin requests).
  LEGAL_DOCUMENT_PUBLISH = 'legal.document.publish',
  CONSENT_ACCEPT = 'privacy.consent.accept',
  DATA_EXPORT_REQUESTED = 'privacy.export.requested',
  DATA_EXPORT_REAUTH_FAILED = 'privacy.export.reauth_failed',
  DATA_EXPORT_LIMITED = 'privacy.export.limited',
  DATA_EXPORT_READY = 'privacy.export.ready',
  DATA_EXPORT_FAILED = 'privacy.export.failed',
  DATA_EXPORT_DOWNLOADED = 'privacy.export.downloaded',
  DATA_EXPORT_DOWNLOAD_REFUSED = 'privacy.export.download_refused',
  DATA_EXPORT_EXPIRED = 'privacy.export.expired',
  DATA_EXPORT_ADMIN_VIEW = 'privacy.export.admin_view',
  // v1.29-live (DRAFT, D147): search trends, changed only by the search-admin CLI (§11.11).
  SEARCH_TERM_HIDE = 'search.term.hide',
  SEARCH_BLOCKED_WORD = 'search.blocked_word',
  // v1.60-social (DRAFT, D191): the admin panel (CONVENTIONS §10.54). Sign-in and its second factor …
  ADMIN_LOGIN_PASSWORD = 'admin.login.password',
  ADMIN_LOGIN_FAILURE = 'admin.login.failure',
  ADMIN_LOGIN_SUCCESS = 'admin.login.success',
  ADMIN_LOCKED = 'admin.login.locked',
  ADMIN_TOTP_ENROL = 'admin.totp.enrol',
  ADMIN_TOTP_FAILURE = 'admin.totp.failure',
  ADMIN_RECOVERY_CODE_USED = 'admin.recovery_code.used',
  ADMIN_LOGOUT = 'admin.logout',
  /** … the roles (`admin-admin grant|revoke|reset-2fa`) … */
  ADMIN_ROLE_GRANT = 'admin.role.grant',
  ADMIN_ROLE_REVOKE = 'admin.role.revoke',
  ADMIN_TOTP_RESET = 'admin.totp.reset',
  /** … and what the panel does that has no older action name. */
  ADMIN_USER_VIEW = 'admin.user.view',
  ADMIN_USER_BAN = 'admin.user.ban',
  ADMIN_USER_UNBAN = 'admin.user.unban',
  ADMIN_USER_WARN = 'admin.user.warn',
  RECHARGE_PHOTO_VIEW = 'recharge.application.photo_view',
  /** v1.60-social (D191/D192): the OWNER changed the public website's settings from the panel (before and after). */
  SITE_SETTINGS_UPDATE = 'site.settings.update',
  // v1.64-social (DRAFT, D196): the OWNER's «الدفع (Stripe)» section — a change (masked before/after, reason), the
  // removal of the panel's keys (back to the env keys or off) and a «اختبار الاتصال» (the key's fingerprint only).
  PAYMENT_SETTINGS_UPDATE = 'payment.settings.update',
  PAYMENT_SETTINGS_CLEAR = 'payment.settings.clear',
  PAYMENT_SETTINGS_TEST = 'payment.settings.test',
  // v1.75-social (DRAFT, D222): the OWNER's «التخزين (R2 / S3)» section — a change (before/after with the keys' last 4
  // only, reason, the connection test's outcome), the removal of the panel's settings and a «اختبار الاتصال».
  STORAGE_SETTINGS_UPDATE = 'storage.settings.update',
  STORAGE_SETTINGS_CLEAR = 'storage.settings.clear',
  STORAGE_SETTINGS_TEST = 'storage.settings.test',
  // v1.61-social (DRAFT, D192): each read of the website waitlist's e-mails by the `waitlist-admin` CLI (`op`:
  // list|export, the count).
  WAITLIST_VIEW = 'waitlist.view',
  // v1.65-social (DRAFT, D197, CONVENTIONS §10.60): the admin panel v2.
  /** A table exported as CSV from the panel {table, count, total, filters} (never the rows). */
  ADMIN_EXPORT_CSV = 'admin.export.csv',
  /** The agency rank evaluation run from the panel (what `economy-admin agency-evaluate` does). */
  AGENCY_EVALUATE = 'agency.evaluate',
  /** v1.70-social (D206, §10.65): «افتح وكالة» — the opening, the probation and the closing / reopening. */
  AGENCY_OPEN = 'agency.open',
  AGENCY_PROBATION_PASS = 'agency.probation.pass',
  AGENCY_PROBATION_EXTEND = 'agency.probation.extend',
  AGENCY_CLOSE = 'agency.close',
  AGENCY_REOPEN = 'agency.reopen',
  AGENCY_APPLICATION_VIEW = 'agency.application.view',
  AGENCY_PHOTO_VIEW = 'agency.application.photo.view',
  /** v1.73-social (D209, §10.68): «كن مضيفاً مع الإدارة» — submitted, cancelled, decided, and every panel view. */
  HOST_APPLICATION_SUBMIT = 'host.application.submit',
  HOST_APPLICATION_CANCEL = 'host.application.cancel',
  HOST_APPLICATION_APPROVE = 'host.application.approve',
  HOST_APPLICATION_REJECT = 'host.application.reject',
  HOST_APPLICATION_VIEW = 'host.application.view',
  HOST_APPLICATION_PHOTO_VIEW = 'host.application.photo.view',
  /**
   * v1.74-social (D217, §10.71): «دعوة الأصدقاء» — a code applied (at sign-up or later; refused by a fraud rule too),
   * a referral qualified or voided after its hold, a reward made / credited / voided, the team's approve and void
   * (via panel or cli), every panel view of a referral, and the settings changed.
   */
  REFERRAL_ATTACH = 'referral.attach',
  REFERRAL_QUALIFY = 'referral.qualify',
  REFERRAL_VOID = 'referral.void',
  REFERRAL_APPROVE = 'referral.approve',
  REFERRAL_REWARD_CREATE = 'referral.reward.create',
  REFERRAL_REWARD_CREDIT = 'referral.reward.credit',
  REFERRAL_REWARD_VOID = 'referral.reward.void',
  /** A credited reward taken back when the team voided its referral {user, cherries, shortfall, balanceAfter}. */
  REFERRAL_REWARD_REVERSE = 'referral.reward.reverse',
  REFERRAL_VIEW = 'referral.view',
  REFERRAL_SETTINGS_UPDATE = 'referral.settings.update',
  /**
   * v1.78-social (D223, §10.75): a sign-up refused because its device created its accounts {stage, count, max}; the
   * panel's view of the accounts made on a user's device, and an OWNER's device exception granted / removed
   * {maxAccounts, before, reason, via}.
   */
  REGISTRATION_DEVICE_LIMIT = 'auth.registration.device_limit',
  DEVICE_SIGNUPS_VIEW = 'admin.device_signups.view',
  DEVICE_EXCEPTION_GRANT = 'admin.device_exception.grant',
  DEVICE_EXCEPTION_REMOVE = 'admin.device_exception.remove',
  /** A live ended by the team from the panel {reason, hostUserId} (end reason ADMIN). */
  ADMIN_LIVE_END = 'admin.live.end',
  /** A user's app sessions signed out by the team {sessions, reason}. */
  ADMIN_USER_SESSIONS_REVOKE = 'admin.user.sessions_revoke',
  // v1.69-social (DRAFT, D204): recharge orders with escrow — each state change (before/after, the coins moved), an
  // admin's view of a disputed order and of its pictures, an admin's message «الإدارة», a dispute's decision, and an
  // exchange rate set or cleared (OWNER / FINANCE, panel or CLI).
  RECHARGE_ORDER_CREATE = 'recharge.order.create',
  RECHARGE_ORDER_DETAILS = 'recharge.order.details',
  RECHARGE_ORDER_NOTICE_ACK = 'recharge.order.notice_ack',
  RECHARGE_ORDER_PAID = 'recharge.order.paid',
  RECHARGE_ORDER_CONFIRM = 'recharge.order.confirm',
  RECHARGE_ORDER_DISPUTE = 'recharge.order.dispute',
  RECHARGE_ORDER_CANCEL = 'recharge.order.cancel',
  RECHARGE_ORDER_EXPIRE = 'recharge.order.expire',
  RECHARGE_ORDER_RESOLVE = 'recharge.order.resolve',
  RECHARGE_ORDER_ADMIN_VIEW = 'recharge.order.admin_view',
  RECHARGE_ORDER_IMAGE_VIEW = 'recharge.order.image_view',
  RECHARGE_ORDER_ADMIN_MESSAGE = 'recharge.order.admin_message',
  RECHARGE_RATE_SET = 'recharge.rate.set',
  RECHARGE_RATE_CLEAR = 'recharge.rate.clear',
  // v1.72-social (DRAFT, D208, CONVENTIONS §10.67): the account controls «تحكم كامل» (panel and `control-admin`).
  // Every row has the reason, `via` and `before` / `after`; never a password, token or full email in the clear.
  /** A temporary lock «قفل الحساب» {kind: LOCK, endsAt, sessions} and its early end. */
  ADMIN_USER_LOCK = 'admin.user.lock',
  ADMIN_USER_UNLOCK = 'admin.user.unlock',
  /** A restriction (CHAT_MUTE, NO_LIVE, NO_GIFTS, NO_POSTING) {kind, endsAt} and its early end. */
  ADMIN_USER_RESTRICT = 'admin.user.restrict',
  ADMIN_USER_RESTRICTION_LIFT = 'admin.user.restriction_lift',
  /** The password-reset email sent by the team (the existing flow). */
  ADMIN_PASSWORD_RESET_LINK = 'admin.user.password_reset_link',
  /** A temporary password set by the team {sessions} (the password itself is never recorded). */
  ADMIN_PASSWORD_TEMPORARY = 'admin.user.password_temporary',
  /** «فرض تغيير كلمة المرور في الدخول القادم» {sessions}. */
  ADMIN_PASSWORD_REQUIRE_CHANGE = 'admin.user.password_require_change',
  /** The person chose a new password at sign-in because the team required it. */
  PASSWORD_CHANGED_AT_SIGN_IN = 'auth.password.changed_at_sign_in',
  /** The profile edited by the team {fields, before, after}. */
  ADMIN_PROFILE_EDIT = 'admin.user.profile_edit',
  /** The email changed by the team {before, after (masked), verified}; a verification email resent. */
  ADMIN_EMAIL_CHANGE = 'admin.user.email_change',
  ADMIN_EMAIL_VERIFICATION_RESEND = 'admin.user.email_verification_resend',
  /** A post, reel, story or comment hidden, restored or deleted by the team {contentType, contentId}. */
  ADMIN_CONTENT_HIDE = 'admin.content.hide',
  ADMIN_CONTENT_RESTORE = 'admin.content.restore',
  ADMIN_CONTENT_DELETE = 'admin.content.delete',
  /** A coin or cherry adjustment {currency, delta, before, after, adjustmentId}. */
  ADMIN_BALANCE_ADJUST = 'admin.balance.adjust',
}

export interface AuditEntry {
  readonly action: AuditAction;
  readonly actorUserId?: string | null;
  readonly targetType?: string;
  readonly targetId?: string;
  /** Never put secrets (passwords, tokens) or raw identifiers here. */
  readonly metadata?: Prisma.InputJsonObject;
  readonly ip?: string | null;
  readonly requestId?: string | null;
}

function toRow(entry: AuditEntry): Prisma.AuditLogUncheckedCreateInput {
  return {
    action: entry.action,
    actorUserId: entry.actorUserId ?? null,
    targetType: entry.targetType ?? null,
    targetId: entry.targetId ?? null,
    ...(entry.metadata ? { metadata: entry.metadata } : {}),
    ip: entry.ip?.slice(0, 64) ?? null,
    requestId: entry.requestId ?? null,
  };
}

/** Append-only security audit trail. Failures to write are logged, never surfaced. */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({ data: toRow(entry) });
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), action: entry.action }, 'Audit write failed');
    }
  }

  /** Writes inside the caller's transaction (a failure aborts the transaction). */
  async recordIn(tx: Prisma.TransactionClient, entry: AuditEntry): Promise<void> {
    await tx.auditLog.create({ data: toRow(entry) });
  }

  /** Writes several entries inside the caller's transaction. */
  async recordManyIn(tx: Prisma.TransactionClient, entries: readonly AuditEntry[]): Promise<void> {
    if (entries.length === 0) return;
    await tx.auditLog.createMany({ data: entries.map(toRow) });
  }
}
