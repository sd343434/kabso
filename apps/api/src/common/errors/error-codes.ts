/**
 * Stable error codes — CONVENTIONS.md §4. Adding a code is a contract change.
 * `NETWORK_OFFLINE` / `NETWORK_TIMEOUT` are client-only and intentionally absent.
 */
export enum ErrorCode {
  VALIDATION_FAILED = 'VALIDATION_FAILED',
  AUTH_UNAUTHENTICATED = 'AUTH_UNAUTHENTICATED',
  AUTH_INVALID_CREDENTIALS = 'AUTH_INVALID_CREDENTIALS',
  AUTH_REFRESH_INVALID = 'AUTH_REFRESH_INVALID',
  AUTH_FORBIDDEN = 'AUTH_FORBIDDEN',
  ACCOUNT_SUSPENDED = 'ACCOUNT_SUSPENDED',
  NOT_FOUND = 'NOT_FOUND',
  EMAIL_TAKEN = 'EMAIL_TAKEN',
  USERNAME_TAKEN = 'USERNAME_TAKEN',
  IDEMPOTENCY_CONFLICT = 'IDEMPOTENCY_CONFLICT',
  /** v1.3: go-live refused, the caller already has a LIVE room with a fresh heartbeat. */
  LIVE_ROOM_ALREADY_ACTIVE = 'LIVE_ROOM_ALREADY_ACTIVE',
  /** v1.3: heartbeat for a room that is no longer LIVE. */
  LIVE_ROOM_ENDED = 'LIVE_ROOM_ENDED',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  TOKEN_INVALID = 'TOKEN_INVALID',
  RATE_LIMITED = 'RATE_LIMITED',
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE',
  /** v1.3: going live / heartbeating disabled by LIVE_HOSTING_ENABLED=false (no Retry-After). */
  LIVE_HOSTING_UNAVAILABLE = 'LIVE_HOSTING_UNAVAILABLE',
  /** CP-010: going live needs the hosting permission. */
  LIVE_HOSTING_NOT_ALLOWED = 'LIVE_HOSTING_NOT_ALLOWED',
  /** CP-010: the host switched guests off. */
  LIVE_GUESTS_NOT_ALLOWED = 'LIVE_GUESTS_NOT_ALLOWED',
  /** v1.4-levels (DRAFT, CP-005): a level configuration breaks the publication rules. */
  LEVEL_CONFIG_INVALID = 'LEVEL_CONFIG_INVALID',
  /** v1.4-levels (DRAFT, CP-005): only DRAFT versions change. */
  LEVEL_VERSION_NOT_DRAFT = 'LEVEL_VERSION_NOT_DRAFT',
  /** v1.5-social (DRAFT, CP-006): uploads disabled by MEDIA_UPLOADS_ENABLED=false (no Retry-After). */
  MEDIA_UPLOADS_UNAVAILABLE = 'MEDIA_UPLOADS_UNAVAILABLE',
  /** v1.5-social (DRAFT): the uploaded object is missing, mismatched or not a valid image. */
  MEDIA_INVALID = 'MEDIA_INVALID',
  /** v1.5-social (DRAFT): the caller already has 3 pinned posts. */
  PIN_LIMIT_REACHED = 'PIN_LIMIT_REACHED',
  /** v1.5-social (DRAFT): an admin acted on a report that is no longer OPEN. */
  REPORT_ALREADY_RESOLVED = 'REPORT_ALREADY_RESOLVED',
  /** v1.14-live (CP-016 C): the host already has 10 upcoming scheduled lives. */
  LIVE_SCHEDULE_FULL = 'LIVE_SCHEDULE_FULL',
  /** v1.7-live (DRAFT, CP-011): the seat or seats asked for cannot be used. */
  LIVE_SEAT_UNAVAILABLE = 'LIVE_SEAT_UNAVAILABLE',
  /** v1.7-live (DRAFT, CP-011): the seat request or invitation is no longer pending. */
  LIVE_REQUEST_NOT_PENDING = 'LIVE_REQUEST_NOT_PENDING',
  /** v1.47-live (D212): the podcast's host closed the hands. */
  LIVE_QUESTIONS_CLOSED = 'LIVE_QUESTIONS_CLOSED',
  /** v1.56-live (D213, §10.86): a streamer-only control on a live of another mode. */
  LIVE_NOT_STREAMER = 'LIVE_NOT_STREAMER',
  /** v1.9-live (DRAFT, CP-013): a chat message from someone who is not in the room now. */
  LIVE_CHAT_NOT_IN_ROOM = 'LIVE_CHAT_NOT_IN_ROOM',
  /** v1.9-live (DRAFT, CP-013): the host or a moderator muted the caller in this live's chat. */
  LIVE_CHAT_MUTED = 'LIVE_CHAT_MUTED',
  /** v1.9-live (DRAFT, CP-013): the host turned the chat off. */
  LIVE_CHAT_CLOSED = 'LIVE_CHAT_CLOSED',
  /** v1.19-live (DRAFT, CP-017): the caller's coin balance does not cover the price. */
  INSUFFICIENT_COINS = 'INSUFFICIENT_COINS',
  /** v1.20-live (DRAFT, D105): the host or a moderator kicked the caller out of this live. */
  LIVE_KICKED = 'LIVE_KICKED',
  /** v1.21-live (DRAFT, CP-018): the caller (or the person asked) already belongs to a family. */
  ALREADY_IN_FAMILY = 'ALREADY_IN_FAMILY',
  /** v1.21-live (DRAFT, CP-018): the family has 500 members. */
  FAMILY_FULL = 'FAMILY_FULL',
  /** v1.21-live (DRAFT, CP-018): another family has this name. */
  FAMILY_NAME_TAKEN = 'FAMILY_NAME_TAKEN',
  /** v1.21-live (DRAFT, CP-018): the caller already has a pending join request to another family. */
  FAMILY_REQUEST_PENDING = 'FAMILY_REQUEST_PENDING',
  /** v1.21-live (DRAFT, CP-018): the join request was already handled, cancelled or expired. */
  FAMILY_REQUEST_NOT_PENDING = 'FAMILY_REQUEST_NOT_PENDING',
  /** v1.21-live (DRAFT, CP-018): only a family with the leader alone can be disbanded. */
  FAMILY_NOT_EMPTY = 'FAMILY_NOT_EMPTY',
  /** v1.21-live (DRAFT, CP-018): the leader hands the family over (or disbands it) instead of leaving. */
  FAMILY_LEADER_CANNOT_LEAVE = 'FAMILY_LEADER_CANNOT_LEAVE',
  /** v1.25-live (CP-022): the leader or a deputy muted the caller in the family chat. */
  FAMILY_CHAT_MUTED = 'FAMILY_CHAT_MUTED',
  // v1.27-live (DRAFT, D132): lucky gifts (CONVENTIONS §10.27).
  LUCKY_GIFT_AGE_UNCONFIRMED = 'LUCKY_GIFT_AGE_UNCONFIRMED',
  LUCKY_GIFT_REGION_UNAVAILABLE = 'LUCKY_GIFT_REGION_UNAVAILABLE',
  // v1.28-live (DRAFT, D146): premium usernames (CONVENTIONS §10.32).
  PREMIUM_USERNAME_UNAVAILABLE = 'PREMIUM_USERNAME_UNAVAILABLE',
  PREMIUM_USERNAME_PRICE_CHANGED = 'PREMIUM_USERNAME_PRICE_CHANGED',
  PREMIUM_USERNAME_ACTIVE = 'PREMIUM_USERNAME_ACTIVE',
  // v1.40-social (DRAFT, D155): direct messages (CONVENTIONS §11.13).
  DM_NOT_ALLOWED = 'DM_NOT_ALLOWED',
  DM_REQUEST_LIMIT = 'DM_REQUEST_LIMIT',
  DM_REQUEST_TEXT_ONLY = 'DM_REQUEST_TEXT_ONLY',
  DM_DELETE_WINDOW_PASSED = 'DM_DELETE_WINDOW_PASSED',
  /** v1.21-live (DRAFT, CP-018): the caller or the other person already has a CP partner. */
  CP_ALREADY_PAIRED = 'CP_ALREADY_PAIRED',
  /** v1.21-live (DRAFT, CP-018): the caller already has a pending CP request. */
  CP_REQUEST_PENDING = 'CP_REQUEST_PENDING',
  /** v1.21-live (DRAFT, CP-018): the CP request was already accepted, declined, cancelled or expired. */
  CP_REQUEST_NOT_PENDING = 'CP_REQUEST_NOT_PENDING',
  /** v1.21-live (DRAFT, CP-018): the caller has no CP partner. */
  CP_NOT_PAIRED = 'CP_NOT_PAIRED',
  /** v1.21-live (DRAFT, CP-018): a medal the caller has not unlocked cannot be shown on the profile. */
  MEDAL_NOT_UNLOCKED = 'MEDAL_NOT_UNLOCKED',
  /** v1.22-live (DRAFT, CP-019): the caller does not own that bag item (or it does not exist). */
  BAG_ITEM_NOT_OWNED = 'BAG_ITEM_NOT_OWNED',
  /** v1.48-social (D171, §10.45): sending bag items. */
  BAG_ITEM_NOT_TRANSFERABLE = 'BAG_ITEM_NOT_TRANSFERABLE',
  BAG_SEND_PERMANENT_WHOLE_ONLY = 'BAG_SEND_PERMANENT_WHOLE_ONLY',
  BAG_SEND_EXCEEDS_REMAINING = 'BAG_SEND_EXCEEDS_REMAINING',
  BAG_RECIPIENT_HAS_PERMANENT = 'BAG_RECIPIENT_HAS_PERMANENT',
  /** v1.23-live (DRAFT, CP-020): the gift is not in the catalogue or is disabled. */
  GIFT_UNAVAILABLE = 'GIFT_UNAVAILABLE',
  /** v1.23-live (DRAFT, CP-020): the caller's gift bag holds fewer of that gift than the send needs. */
  GIFT_BAG_INSUFFICIENT = 'GIFT_BAG_INSUFFICIENT',
  /** v1.23-live (DRAFT, CP-020): a recipient is not the host or seated in the live now (or cannot get gifts from the caller). */
  LIVE_GIFT_RECIPIENT_UNAVAILABLE = 'LIVE_GIFT_RECIPIENT_UNAVAILABLE',
  /** v1.24-live (DRAFT, CP-021): the daily CP task is not completed yet today (nothing claimed). */
  CP_TASK_NOT_COMPLETED = 'CP_TASK_NOT_COMPLETED',
  /** v1.24-live (DRAFT, CP-021): the couple has not unlocked the CP privilege this needs. */
  CP_PRIVILEGE_LOCKED = 'CP_PRIVILEGE_LOCKED',
  /** v1.32-live (DRAFT, D154): the caller already sent their one free quip in this live. */
  QUIP_FREE_USED = 'QUIP_FREE_USED',
  /** v1.32-live (DRAFT, D154): the room's quip queue is full (the quip would wait too long). */
  QUIP_QUEUE_FULL = 'QUIP_QUEUE_FULL',
  /** v1.33-live (DRAFT, D154b): the traffic card would wait longer than the limit for a slot. */
  BOOST_QUEUE_FULL = 'BOOST_QUEUE_FULL',
  /** v1.33-live (DRAFT, D154b): the caller holds no traffic card of that length. */
  BOOST_CARD_INSUFFICIENT = 'BOOST_CARD_INSUFFICIENT',
  /** v1.33-live (DRAFT, D154b): this live already has a traffic card running or waiting. */
  BOOST_ROOM_BUSY = 'BOOST_ROOM_BUSY',
  /** v1.38-live (DRAFT, D154i): the YouTube video does not exist or may not be played in other apps. */
  YOUTUBE_VIDEO_UNAVAILABLE = 'YOUTUBE_VIDEO_UNAVAILABLE',
  /** v1.38-live (DRAFT, D154i): YouTube search is not set up on this server (or YouTube is unreachable). */
  YOUTUBE_SEARCH_UNAVAILABLE = 'YOUTUBE_SEARCH_UNAVAILABLE',
  /** v1.44-social (DRAFT, D166): the task is not completed yet in this period (nothing paid). */
  TASK_NOT_COMPLETED = 'TASK_NOT_COMPLETED',
  /** v1.44-social (DRAFT, D166): the caller already got the day's task and check-in coins cap. */
  TASK_DAILY_CAP_REACHED = 'TASK_DAILY_CAP_REACHED',
  /** v1.47-social (DRAFT, D175): there is no pending follow request from that account. */
  FOLLOW_REQUEST_NOT_PENDING = 'FOLLOW_REQUEST_NOT_PENDING',
  /** v1.52-social (DRAFT, D179): the caller is already a host of another agency. */
  AGENCY_ALREADY_MEMBER = 'AGENCY_ALREADY_MEMBER',
  /** v1.52-social (DRAFT, D179): an agency's owner cannot join an agency as a host. */
  AGENCY_JOIN_NOT_ALLOWED = 'AGENCY_JOIN_NOT_ALLOWED',
  /** v1.52-social (DRAFT, D179): the leave window is over; only a complaint to the admin remains. */
  AGENCY_LEAVE_WINDOW_CLOSED = 'AGENCY_LEAVE_WINDOW_CLOSED',
  /** v1.70-social (D206): «افتح وكالة» refused — `details[0].issue` says why (§10.65). */
  AGENCY_OPEN_NOT_ALLOWED = 'AGENCY_OPEN_NOT_ALLOWED',
  /** v1.73-social (D209): «كن مضيفاً مع الإدارة» refused — `details[0].issue` says why (§10.68). */
  HOST_APPLICATION_NOT_ALLOWED = 'HOST_APPLICATION_NOT_ALLOWED',
  /** v1.75-live (D285): the creator programme application «انضم كصانع محتوى» is not possible now (`details[0].issue`). */
  CREATOR_APPLICATION_NOT_ALLOWED = 'CREATOR_APPLICATION_NOT_ALLOWED',
  /** v1.82-live (D295, §10.108): an agency owner's activation of a member refused (`details[0].issue`). */
  AGENCY_ACTIVATION_NOT_ALLOWED = 'AGENCY_ACTIVATION_NOT_ALLOWED',
  /**
   * v1.89-social (D290, §10.103.2): a level-raise request for a source account (canonical app + account ID) that is
   * already PENDING or APPROVED — `details`: `status`, `createdAt`, `requestedBy` (the staff member's display name).
   */
  LEVEL_RAISE_DUPLICATE = 'LEVEL_RAISE_DUPLICATE',
  /** v1.80-kyc (D227): an identity check cannot be started now (`details[0].issue`, CONVENTIONS §10.77). */
  KYC_NOT_ALLOWED = 'KYC_NOT_ALLOWED',
  /** v1.80-kyc (D227): identity verification (Didit) is off or not configured. */
  KYC_UNAVAILABLE = 'KYC_UNAVAILABLE',
  /** v1.52-social (DRAFT, D179): the cherry balance does not cover the withdrawal. */
  INSUFFICIENT_CHERRIES = 'INSUFFICIENT_CHERRIES',
  /** v1.52-social (DRAFT, D179): the caller already has a withdrawal waiting to be paid. */
  WITHDRAWAL_PENDING = 'WITHDRAWAL_PENDING',
  /** v1.54-social (DRAFT, D185): A pending application, already an agent, or an employee of an agent. */
  RECHARGE_APPLICATION_NOT_ALLOWED = 'RECHARGE_APPLICATION_NOT_ALLOWED',
  /** v1.54-social (DRAFT, D185): The recharge agent is not ACTIVE (waiting for the first top-up, or suspended). */
  RECHARGE_AGENT_NOT_ACTIVE = 'RECHARGE_AGENT_NOT_ACTIVE',
  /** v1.54-social (DRAFT, D185): An employee tried to sell (v1.87-social, D287: or act for the agent) outside their hours. */
  RECHARGE_OFF_SHIFT = 'RECHARGE_OFF_SHIFT',
  /** v1.54-social (DRAFT, D185): The agent's coin stock does not cover the sale. */
  RECHARGE_STOCK_INSUFFICIENT = 'RECHARGE_STOCK_INSUFFICIENT',
  /** v1.54-social (DRAFT, D185): The person cannot be added as an employee. */
  RECHARGE_EMPLOYEE_NOT_ALLOWED = 'RECHARGE_EMPLOYEE_NOT_ALLOWED',
  /** v1.54-social (DRAFT, D185): An open cherry request between the same host and agent already exists. */
  RECHARGE_CHERRY_REQUEST_PENDING = 'RECHARGE_CHERRY_REQUEST_PENDING',
  /** v1.54-social (DRAFT, D185): The cherry request is no longer pending or has expired. */
  RECHARGE_CHERRY_REQUEST_CLOSED = 'RECHARGE_CHERRY_REQUEST_CLOSED',
  /** v1.54-social (DRAFT, D185): The agent's daily cherry cap would be exceeded. */
  RECHARGE_CHERRY_CAP_REACHED = 'RECHARGE_CHERRY_CAP_REACHED',
  /** v1.54-social (DRAFT, D185): A special username is active and locked; the username cannot change. */
  USERNAME_LOCKED = 'USERNAME_LOCKED',
  /** v1.55-social (DRAFT, D186): the host's gender sets the frame style (male blue, female pink). */
  HOST_FRAME_STYLE_FROM_GENDER = 'HOST_FRAME_STYLE_FROM_GENDER',
  /** v1.57-social (DRAFT, D188): the caller already got the month's maximum of task cherries. */
  TASK_MONTHLY_CAP_REACHED = 'TASK_MONTHLY_CAP_REACHED',
  /** v1.59-social (DRAFT, D190): card top-ups are not configured on this server (no Stripe keys); no Retry-After. */
  TOPUP_UNAVAILABLE = 'TOPUP_UNAVAILABLE',
  /** v1.59-social (DRAFT, D190): the account is frozen from card purchases after a refund, a fraud warning or a dispute. */
  TOPUP_ACCOUNT_FROZEN = 'TOPUP_ACCOUNT_FROZEN',
  /** v1.60-social (DRAFT, D191): the admin panel is off (ADMIN_TOTP_KEY is not set on the server). */
  ADMIN_PANEL_UNAVAILABLE = 'ADMIN_PANEL_UNAVAILABLE',
  /** v1.60-social (DRAFT, D191): too many failed sign-in or code attempts; the admin account is locked a while. */
  ADMIN_LOCKED = 'ADMIN_LOCKED',
  /** v1.60-social (DRAFT, D191): the authenticator code (or recovery code) is wrong, expired or already used. */
  ADMIN_TOTP_INVALID = 'ADMIN_TOTP_INVALID',
  /** v1.60-social (DRAFT, D191): a panel change without the session's `X-CSRF-Token`. */
  ADMIN_CSRF_INVALID = 'ADMIN_CSRF_INVALID',
  /** v1.60-social (DRAFT, D191): the shared admin rule refused the action (the message says why; nothing changed). */
  ADMIN_ACTION_REFUSED = 'ADMIN_ACTION_REFUSED',
  /** v1.62-social (DRAFT, D193): the password given to confirm a sensitive action is not the account's. */
  REAUTH_FAILED = 'REAUTH_FAILED',
  /**
   * v1.62-social (DRAFT, D193): the account cannot be deleted yet; `details[].issue` names each thing to settle first
   * (`recharge_agent`, `host_agency`, `pending_withdrawal`, `pending_cherry_sale`, `negative_balance`).
   */
  ACCOUNT_DELETION_BLOCKED = 'ACCOUNT_DELETION_BLOCKED',
  /**
   * v1.62-social (DRAFT, D193): sign-in to an account in its deletion grace period (only after the right password);
   * `details: [{field: 'purgeAfter', issue: <ISO time>}]`. Signing in with `cancelDeletion: true` cancels it.
   */
  ACCOUNT_DELETION_PENDING = 'ACCOUNT_DELETION_PENDING',
  /**
   * v1.66-social (DRAFT, D198): a new version of the terms or the privacy policy is in force and the caller has not
   * accepted it; `details: [{field: 'terms'|'privacy', issue: <version>}]`. Only accepting, signing out, deleting the
   * account and the data export work until then.
   */
  CONSENT_REQUIRED = 'CONSENT_REQUIRED',
  /** v1.66-social (DRAFT, D198): `acceptConsents` named a version that is not the one in force. */
  CONSENT_VERSION_MISMATCH = 'CONSENT_VERSION_MISMATCH',
  /** v1.66-social (DRAFT, D198): one data export per 24 hours (or one is still being prepared); `Retry-After`. */
  DATA_EXPORT_LIMIT = 'DATA_EXPORT_LIMIT',
  /** v1.66-social (DRAFT, D198): the download link is wrong, already used or expired. */
  DATA_EXPORT_LINK_INVALID = 'DATA_EXPORT_LINK_INVALID',
  /** v1.43-live (DRAFT, D195): the room cannot take part in a PK now (not a LIVE SOLO video live of the caller, the host away, or PK switched off). */
  PK_UNAVAILABLE = 'PK_UNAVAILABLE',
  /** v1.43-live (DRAFT, D195): the caller or the other host is already in a PK, an open invitation or the random queue. */
  PK_HOST_BUSY = 'PK_HOST_BUSY',
  /** v1.43-live (DRAFT, D195): the invited host switched PK invitations off. */
  PK_INVITES_OFF = 'PK_INVITES_OFF',
  /** v1.43-live (DRAFT, D195): an invitation sooner than PK_INVITE_COOLDOWN_SECONDS after the previous one (Retry-After). */
  PK_INVITE_COOLDOWN = 'PK_INVITE_COOLDOWN',
  /** v1.43-live (DRAFT, D195): the invitation was answered, cancelled or expired. */
  PK_INVITE_CLOSED = 'PK_INVITE_CLOSED',
  /** v1.43-live (DRAFT, D195): no BATTLE or RESULT match in the room. */
  PK_NOT_ACTIVE = 'PK_NOT_ACTIVE',
  /** v1.43-live (DRAFT, D195): a booster gift outside a battle, outside its window, over its per-match limit or not higher than the active one (detail issue). */
  PK_BOOSTER_UNAVAILABLE = 'PK_BOOSTER_UNAVAILABLE',
  /** v1.50-live (DRAFT, D229): «PK أحكام» — the dare is no longer at that step (already answered, judged or over). */
  PK_DARE_CLOSED = 'PK_DARE_CLOSED',
  /** v1.50-live (DRAFT, D229): only the losing host may accept or refuse, only the winning host may judge. */
  PK_DARE_FORBIDDEN = 'PK_DARE_FORBIDDEN',
  /** v1.55-live (DRAFT, D242): «جولة أخرى» cannot be offered now (a dare running, a host gone, away, banned or blocked, the limit in a row). */
  PK_REMATCH_UNAVAILABLE = 'PK_REMATCH_UNAVAILABLE',
  /** v1.55-live (DRAFT, D242): no open rematch offer to answer or withdraw (answered, withdrawn or lapsed). */
  PK_REMATCH_CLOSED = 'PK_REMATCH_CLOSED',
  /** v1.45-live (DRAFT, D201): the pairing code is unknown, expired, used, revoked or of another account (one answer for all). */
  SECOND_CAMERA_CODE_INVALID = 'SECOND_CAMERA_CODE_INVALID',
  /** v1.45-live (DRAFT, D201): the live cannot take a second camera now (not the caller's LIVE SOLO video live, or in a PK). */
  SECOND_CAMERA_UNAVAILABLE = 'SECOND_CAMERA_UNAVAILABLE',
  /** v1.45-live (DRAFT, D201): the live already has a second camera (one at a time). */
  SECOND_CAMERA_BUSY = 'SECOND_CAMERA_BUSY',
  /** v1.69-social (DRAFT, D204): recharge orders are switched off on this server (RECHARGE_ORDERS_ENABLED). */
  RECHARGE_ORDERS_UNAVAILABLE = 'RECHARGE_ORDERS_UNAVAILABLE',
  /** v1.69-social (DRAFT, D204): the buyer already has an open order with this agent. */
  RECHARGE_ORDER_OPEN_EXISTS = 'RECHARGE_ORDER_OPEN_EXISTS',
  /** v1.69-social (DRAFT, D204): the order's status no longer allows this action (it changed or ended). */
  RECHARGE_ORDER_STATE_CHANGED = 'RECHARGE_ORDER_STATE_CHANGED',
  /** v1.69-social (DRAFT, D204): the buyer must acknowledge the protection notice first. */
  RECHARGE_ORDER_NOTICE_REQUIRED = 'RECHARGE_ORDER_NOTICE_REQUIRED',
  /** v1.69-social (DRAFT, D204): the buyer can open a dispute only after the wait (15 minutes after «قمت بالإرسال»). */
  RECHARGE_ORDER_DISPUTE_TOO_EARLY = 'RECHARGE_ORDER_DISPUTE_TOO_EARLY',
  /** v1.87-social (DRAFT, D287): the agent switched this permission off for the employee (buy cherries / orders). */
  RECHARGE_EMPLOYEE_NOT_PERMITTED = 'RECHARGE_EMPLOYEE_NOT_PERMITTED',
  /** v1.87-social (DRAFT, D287): another person of the agent's side already took the order. */
  RECHARGE_ORDER_CLAIMED = 'RECHARGE_ORDER_CLAIMED',
  /** v1.87-social (D287, owner): the account to add as a recharge agent's employee is a Kabso Team account (D283). */
  RECHARGE_EMPLOYEE_IS_STAFF = 'RECHARGE_EMPLOYEE_IS_STAFF',
  /**
   * v1.72-social (DRAFT, D208): sign-in to an account the team locked for a while (only after the right password);
   * `details: [{field: 'lockedUntil', issue: <ISO time>}, {field: 'reason', issue: <the team's reason>}]`.
   */
  ACCOUNT_LOCKED = 'ACCOUNT_LOCKED',
  /**
   * v1.72-social (DRAFT, D208): the team switched this off for the caller for a while;
   * `details: [{field: 'restriction', issue: CHAT_MUTE|NO_LIVE|NO_GIFTS|NO_POSTING}, {field: 'until', issue: <ISO>}]`;
   * v1.60-live (D250) adds `{field: 'reason', issue: <the team's reason>}` (additive).
   */
  ACCOUNT_RESTRICTED = 'ACCOUNT_RESTRICTED',
  /**
   * v1.72-social (DRAFT, D208): the right password, but the team requires a new one first — sign in again with
   * `newPassword` (the old one stays until then).
   */
  PASSWORD_CHANGE_REQUIRED = 'PASSWORD_CHANGE_REQUIRED',
  /** v1.74-social (DRAFT, D217): «دعوة الأصدقاء» is switched off (`referral_settings.enabled`). */
  REFERRAL_UNAVAILABLE = 'REFERRAL_UNAVAILABLE',
  /** v1.74-social (DRAFT, D217): no such invite code (or it is the caller's own, or its owner cannot invite now). */
  REFERRAL_CODE_INVALID = 'REFERRAL_CODE_INVALID',
  /**
   * v1.74-social (DRAFT, D217): the caller may not enter a code now —
   * `details: [{field: 'referral', issue: ALREADY_REFERRED|WINDOW_CLOSED}]`.
   */
  REFERRAL_NOT_ALLOWED = 'REFERRAL_NOT_ALLOWED',
  /**
   * v1.78-social (DRAFT, D223, §10.75): this device already created its accounts (`SIGNUP_MAX_ACCOUNTS_PER_DEVICE`,
   * deleted ones included) — `details: [{field: 'device', issue: '<the limit, decimal>'}]`. Signing in is not limited.
   */
  DEVICE_ACCOUNT_LIMIT = 'DEVICE_ACCOUNT_LIMIT',
  /**
   * v1.60-live (DRAFT, D250): the team banned this device «حظر جهاز» — sign-up, sign-in and going live from it are
   * refused for every account — `details: [{field: 'until', issue: <ISO> | 'permanent'}, {field: 'reason', issue}]`.
   */
  DEVICE_BANNED = 'DEVICE_BANNED',
  /**
   * v1.82-social (DRAFT, D252, §10.93): this VIP tier cannot be bought by the caller now — `details: [{field: 'tier',
   * issue: 'tier_off' | 'downgrade' | 'renewal_limit'}]`. Nothing was charged.
   */
  VIP_UNAVAILABLE = 'VIP_UNAVAILABLE',
  /** v1.82-social (DRAFT, D252, §10.93): the tier's price changed since the app showed it. Nothing was charged. */
  VIP_PRICE_CHANGED = 'VIP_PRICE_CHANGED',
  /**
   * D270 (DRAFT, §10.98): this store item cannot be bought now — `details: [{field: 'item' | 'days' | 'currency',
   * issue: 'item_off' | 'not_priced' | 'owned_permanent' | 'too_far'}]`. Nothing was charged.
   */
  STORE_UNAVAILABLE = 'STORE_UNAVAILABLE',
  /** D270 (DRAFT, §10.98): the item's price changed since the app showed it. Nothing was charged. */
  STORE_PRICE_CHANGED = 'STORE_PRICE_CHANGED',
  /**
   * v1.68-live (DRAFT, D273, §10.96.7): the target holds a panel role (OWNER, MODERATION, SUPPORT, FINANCE) — nobody acts
   * on «فريق كابسو» from the app (kick, chat mute, a message removed, a seat, a family kick or mute). Nothing changed.
   */
  STAFF_PROTECTED = 'STAFF_PROTECTED',
  /**
   * v1.68-live (DRAFT, D273, §10.96.6): a Kabso staff member (a watch role) in a live does not send gifts, tap, send
   * bullets or take a seat — `details: [{field: 'staff', issue: 'gifts' | 'taps' | 'bullets' | 'seat' | 'hidden_chat'}]`.
   */
  LIVE_STAFF_REFUSED = 'LIVE_STAFF_REFUSED',
  /**
   * v1.68-live (DRAFT, D273, §10.96.6): a staff tool needs the step-up — the panel authenticator code in the app
   * (`createStaffStepUp`); none, expired or ended (sign-out, a role revoked, a lockout, a reset authenticator).
   */
  STAFF_STEP_UP_REQUIRED = 'STAFF_STEP_UP_REQUIRED',
  /** v1.68-live (DRAFT, D273): the staff member has not set up the panel authenticator yet (admin.<domain>). */
  STAFF_TOTP_NOT_ENROLLED = 'STAFF_TOTP_NOT_ENROLLED',
  /**
   * v1.72-live (DRAFT, D283, §10.96.10): a Kabso Team account (MODERATION, SUPPORT or FINANCE, not OWNER) cannot do
   * this — `details: [{field: 'staff', issue: 'live' | 'post_kind' | 'story' | 'repost' | 'family' | 'vip' | 'tasks' |
   * 'avatar' | 'cover' | 'bio' | 'frame' | 'store'}]`;
   * `announcement` when an account outside the team asks for an announcement post or reel.
   */
  STAFF_ACCOUNT_LIMITED = 'STAFF_ACCOUNT_LIMITED',
  /**
   * v1.79-live (DRAFT, D289, §10.102): the badges of a gift or a store item in the panel break a rule — `details:
   * [{field: 'badges', issue: 'sound_exclusive' | 'duplicate_value'}]` or `[{field: 'badges[i].until', issue:
   * 'until_required' | 'until_not_allowed' | 'until_past' | 'until_too_far' | 'invalid_format'}]`. Nothing changed.
   */
  ITEM_BADGES_INVALID = 'ITEM_BADGES_INVALID',
}

/** HTTP status for every code (CONVENTIONS.md §4 table). */
export const ERROR_HTTP_STATUS: Readonly<Record<ErrorCode, number>> = {
  [ErrorCode.VALIDATION_FAILED]: 400,
  [ErrorCode.AUTH_UNAUTHENTICATED]: 401,
  [ErrorCode.AUTH_INVALID_CREDENTIALS]: 401,
  [ErrorCode.AUTH_REFRESH_INVALID]: 401,
  [ErrorCode.AUTH_FORBIDDEN]: 403,
  [ErrorCode.ACCOUNT_SUSPENDED]: 403,
  [ErrorCode.NOT_FOUND]: 404,
  [ErrorCode.EMAIL_TAKEN]: 409,
  [ErrorCode.USERNAME_TAKEN]: 409,
  [ErrorCode.IDEMPOTENCY_CONFLICT]: 409,
  [ErrorCode.LIVE_ROOM_ALREADY_ACTIVE]: 409,
  [ErrorCode.LIVE_ROOM_ENDED]: 409,
  [ErrorCode.TOKEN_EXPIRED]: 410,
  [ErrorCode.TOKEN_INVALID]: 422,
  [ErrorCode.RATE_LIMITED]: 429,
  [ErrorCode.INTERNAL_ERROR]: 500,
  [ErrorCode.SERVICE_UNAVAILABLE]: 503,
  [ErrorCode.LIVE_HOSTING_UNAVAILABLE]: 503,
  [ErrorCode.LIVE_HOSTING_NOT_ALLOWED]: 403,
  [ErrorCode.LIVE_GUESTS_NOT_ALLOWED]: 403,
  [ErrorCode.LEVEL_CONFIG_INVALID]: 422,
  [ErrorCode.LEVEL_VERSION_NOT_DRAFT]: 409,
  [ErrorCode.MEDIA_UPLOADS_UNAVAILABLE]: 503,
  [ErrorCode.MEDIA_INVALID]: 422,
  [ErrorCode.PIN_LIMIT_REACHED]: 409,
  [ErrorCode.REPORT_ALREADY_RESOLVED]: 409,
  [ErrorCode.LIVE_SCHEDULE_FULL]: 409,
  [ErrorCode.LIVE_SEAT_UNAVAILABLE]: 409,
  [ErrorCode.LIVE_REQUEST_NOT_PENDING]: 409,
  [ErrorCode.LIVE_QUESTIONS_CLOSED]: 409,
  [ErrorCode.LIVE_NOT_STREAMER]: 409,
  [ErrorCode.LIVE_CHAT_NOT_IN_ROOM]: 403,
  [ErrorCode.LIVE_CHAT_MUTED]: 403,
  [ErrorCode.LIVE_CHAT_CLOSED]: 409,
  [ErrorCode.INSUFFICIENT_COINS]: 409,
  [ErrorCode.LIVE_KICKED]: 403,
  [ErrorCode.ALREADY_IN_FAMILY]: 409,
  [ErrorCode.FAMILY_FULL]: 409,
  [ErrorCode.FAMILY_NAME_TAKEN]: 409,
  [ErrorCode.FAMILY_REQUEST_PENDING]: 409,
  [ErrorCode.FAMILY_REQUEST_NOT_PENDING]: 409,
  [ErrorCode.FAMILY_NOT_EMPTY]: 409,
  [ErrorCode.FAMILY_LEADER_CANNOT_LEAVE]: 409,
  [ErrorCode.FAMILY_CHAT_MUTED]: 403,
  [ErrorCode.LUCKY_GIFT_AGE_UNCONFIRMED]: 403,
  [ErrorCode.LUCKY_GIFT_REGION_UNAVAILABLE]: 403,
  [ErrorCode.PREMIUM_USERNAME_UNAVAILABLE]: 409,
  [ErrorCode.PREMIUM_USERNAME_PRICE_CHANGED]: 409,
  [ErrorCode.PREMIUM_USERNAME_ACTIVE]: 409,
  [ErrorCode.DM_NOT_ALLOWED]: 403,
  [ErrorCode.DM_REQUEST_LIMIT]: 403,
  [ErrorCode.DM_REQUEST_TEXT_ONLY]: 403,
  [ErrorCode.DM_DELETE_WINDOW_PASSED]: 409,
  [ErrorCode.CP_ALREADY_PAIRED]: 409,
  [ErrorCode.CP_REQUEST_PENDING]: 409,
  [ErrorCode.CP_REQUEST_NOT_PENDING]: 409,
  [ErrorCode.CP_NOT_PAIRED]: 409,
  [ErrorCode.MEDAL_NOT_UNLOCKED]: 409,
  [ErrorCode.BAG_ITEM_NOT_OWNED]: 409,
  [ErrorCode.BAG_ITEM_NOT_TRANSFERABLE]: 409,
  [ErrorCode.BAG_SEND_PERMANENT_WHOLE_ONLY]: 409,
  [ErrorCode.BAG_SEND_EXCEEDS_REMAINING]: 409,
  [ErrorCode.BAG_RECIPIENT_HAS_PERMANENT]: 409,
  [ErrorCode.GIFT_UNAVAILABLE]: 409,
  [ErrorCode.GIFT_BAG_INSUFFICIENT]: 409,
  [ErrorCode.LIVE_GIFT_RECIPIENT_UNAVAILABLE]: 409,
  [ErrorCode.QUIP_FREE_USED]: 409,
  [ErrorCode.QUIP_QUEUE_FULL]: 409,
  [ErrorCode.BOOST_QUEUE_FULL]: 409,
  [ErrorCode.BOOST_CARD_INSUFFICIENT]: 409,
  [ErrorCode.BOOST_ROOM_BUSY]: 409,
  [ErrorCode.YOUTUBE_VIDEO_UNAVAILABLE]: 422,
  [ErrorCode.YOUTUBE_SEARCH_UNAVAILABLE]: 503,
  [ErrorCode.CP_TASK_NOT_COMPLETED]: 409,
  [ErrorCode.CP_PRIVILEGE_LOCKED]: 403,
  [ErrorCode.TASK_NOT_COMPLETED]: 409,
  [ErrorCode.TASK_DAILY_CAP_REACHED]: 409,
  [ErrorCode.FOLLOW_REQUEST_NOT_PENDING]: 409,
  [ErrorCode.AGENCY_ALREADY_MEMBER]: 409,
  [ErrorCode.AGENCY_JOIN_NOT_ALLOWED]: 409,
  [ErrorCode.AGENCY_LEAVE_WINDOW_CLOSED]: 409,
  [ErrorCode.AGENCY_OPEN_NOT_ALLOWED]: 409,
  [ErrorCode.HOST_APPLICATION_NOT_ALLOWED]: 409,
  [ErrorCode.CREATOR_APPLICATION_NOT_ALLOWED]: 409,
  [ErrorCode.AGENCY_ACTIVATION_NOT_ALLOWED]: 409,
  [ErrorCode.LEVEL_RAISE_DUPLICATE]: 409,
  [ErrorCode.KYC_NOT_ALLOWED]: 409,
  [ErrorCode.KYC_UNAVAILABLE]: 503,
  [ErrorCode.INSUFFICIENT_CHERRIES]: 409,
  [ErrorCode.WITHDRAWAL_PENDING]: 409,
  [ErrorCode.RECHARGE_APPLICATION_NOT_ALLOWED]: 409,
  [ErrorCode.RECHARGE_AGENT_NOT_ACTIVE]: 409,
  [ErrorCode.RECHARGE_OFF_SHIFT]: 409,
  [ErrorCode.RECHARGE_STOCK_INSUFFICIENT]: 409,
  [ErrorCode.RECHARGE_EMPLOYEE_NOT_ALLOWED]: 409,
  [ErrorCode.RECHARGE_CHERRY_REQUEST_PENDING]: 409,
  [ErrorCode.RECHARGE_CHERRY_REQUEST_CLOSED]: 409,
  [ErrorCode.RECHARGE_CHERRY_CAP_REACHED]: 409,
  [ErrorCode.USERNAME_LOCKED]: 409,
  [ErrorCode.HOST_FRAME_STYLE_FROM_GENDER]: 409,
  [ErrorCode.TASK_MONTHLY_CAP_REACHED]: 409,
  [ErrorCode.TOPUP_UNAVAILABLE]: 503,
  [ErrorCode.TOPUP_ACCOUNT_FROZEN]: 403,
  [ErrorCode.ADMIN_PANEL_UNAVAILABLE]: 503,
  [ErrorCode.ADMIN_LOCKED]: 429,
  [ErrorCode.ADMIN_TOTP_INVALID]: 403,
  [ErrorCode.ADMIN_CSRF_INVALID]: 403,
  [ErrorCode.ADMIN_ACTION_REFUSED]: 409,
  [ErrorCode.REAUTH_FAILED]: 403,
  [ErrorCode.ACCOUNT_DELETION_BLOCKED]: 409,
  [ErrorCode.ACCOUNT_DELETION_PENDING]: 409,
  [ErrorCode.CONSENT_REQUIRED]: 428,
  [ErrorCode.CONSENT_VERSION_MISMATCH]: 409,
  [ErrorCode.DATA_EXPORT_LIMIT]: 429,
  [ErrorCode.DATA_EXPORT_LINK_INVALID]: 410,
  [ErrorCode.PK_UNAVAILABLE]: 409,
  [ErrorCode.PK_HOST_BUSY]: 409,
  [ErrorCode.PK_INVITES_OFF]: 409,
  [ErrorCode.PK_INVITE_COOLDOWN]: 409,
  [ErrorCode.PK_INVITE_CLOSED]: 409,
  [ErrorCode.PK_NOT_ACTIVE]: 409,
  [ErrorCode.PK_BOOSTER_UNAVAILABLE]: 409,
  [ErrorCode.PK_DARE_CLOSED]: 409,
  [ErrorCode.PK_DARE_FORBIDDEN]: 403,
  [ErrorCode.PK_REMATCH_UNAVAILABLE]: 409,
  [ErrorCode.PK_REMATCH_CLOSED]: 409,
  [ErrorCode.SECOND_CAMERA_CODE_INVALID]: 422,
  [ErrorCode.SECOND_CAMERA_UNAVAILABLE]: 409,
  [ErrorCode.SECOND_CAMERA_BUSY]: 409,
  [ErrorCode.RECHARGE_ORDERS_UNAVAILABLE]: 503,
  [ErrorCode.RECHARGE_ORDER_OPEN_EXISTS]: 409,
  [ErrorCode.RECHARGE_ORDER_STATE_CHANGED]: 409,
  [ErrorCode.RECHARGE_ORDER_NOTICE_REQUIRED]: 409,
  [ErrorCode.RECHARGE_ORDER_DISPUTE_TOO_EARLY]: 409,
  [ErrorCode.RECHARGE_EMPLOYEE_NOT_PERMITTED]: 403,
  [ErrorCode.RECHARGE_ORDER_CLAIMED]: 409,
  [ErrorCode.RECHARGE_EMPLOYEE_IS_STAFF]: 403,
  [ErrorCode.ACCOUNT_LOCKED]: 403,
  [ErrorCode.ACCOUNT_RESTRICTED]: 403,
  [ErrorCode.PASSWORD_CHANGE_REQUIRED]: 403,
  [ErrorCode.REFERRAL_UNAVAILABLE]: 503,
  [ErrorCode.REFERRAL_CODE_INVALID]: 422,
  [ErrorCode.REFERRAL_NOT_ALLOWED]: 409,
  [ErrorCode.DEVICE_ACCOUNT_LIMIT]: 409,
  [ErrorCode.DEVICE_BANNED]: 403,
  [ErrorCode.VIP_UNAVAILABLE]: 409,
  [ErrorCode.VIP_PRICE_CHANGED]: 409,
  [ErrorCode.STORE_UNAVAILABLE]: 409,
  [ErrorCode.STORE_PRICE_CHANGED]: 409,
  [ErrorCode.STAFF_PROTECTED]: 403,
  [ErrorCode.LIVE_STAFF_REFUSED]: 403,
  [ErrorCode.STAFF_STEP_UP_REQUIRED]: 403,
  [ErrorCode.STAFF_TOTP_NOT_ENROLLED]: 409,
  [ErrorCode.STAFF_ACCOUNT_LIMITED]: 403,
  [ErrorCode.ITEM_BADGES_INVALID]: 400,
};

/** Default developer-facing messages (clients localize by `code`, not by message). */
export const DEFAULT_ERROR_MESSAGE: Readonly<Record<ErrorCode, string>> = {
  [ErrorCode.VALIDATION_FAILED]: 'Request validation failed.',
  [ErrorCode.AUTH_UNAUTHENTICATED]: 'Authentication required.',
  [ErrorCode.AUTH_INVALID_CREDENTIALS]: 'Invalid email/username or password.',
  [ErrorCode.AUTH_REFRESH_INVALID]: 'Refresh token is invalid.',
  [ErrorCode.AUTH_FORBIDDEN]: 'Not allowed.',
  [ErrorCode.ACCOUNT_SUSPENDED]: 'Account is suspended.',
  [ErrorCode.NOT_FOUND]: 'Resource not found.',
  [ErrorCode.EMAIL_TAKEN]: 'Email is already in use.',
  [ErrorCode.USERNAME_TAKEN]: 'Username is already in use.',
  [ErrorCode.IDEMPOTENCY_CONFLICT]: 'Idempotency key reused with a different payload.',
  [ErrorCode.LIVE_ROOM_ALREADY_ACTIVE]: 'You already have a live room.',
  [ErrorCode.LIVE_ROOM_ENDED]: 'The live room has ended.',
  [ErrorCode.TOKEN_EXPIRED]: 'Token has expired or was already used.',
  [ErrorCode.TOKEN_INVALID]: 'Token is invalid.',
  [ErrorCode.RATE_LIMITED]: 'Too many requests.',
  [ErrorCode.INTERNAL_ERROR]: 'Internal server error.',
  [ErrorCode.SERVICE_UNAVAILABLE]: 'Service temporarily unavailable.',
  [ErrorCode.LIVE_HOSTING_UNAVAILABLE]: 'Going live is not available.',
  [ErrorCode.LIVE_HOSTING_NOT_ALLOWED]: 'Your account cannot go live yet.',
  [ErrorCode.LIVE_GUESTS_NOT_ALLOWED]: 'Sign in to watch this live.',
  [ErrorCode.LEVEL_CONFIG_INVALID]: 'The level configuration is invalid.',
  [ErrorCode.LEVEL_VERSION_NOT_DRAFT]: 'Only draft versions can change.',
  [ErrorCode.MEDIA_UPLOADS_UNAVAILABLE]: 'Uploading is not available.',
  [ErrorCode.MEDIA_INVALID]: 'The uploaded file is not a valid image.',
  [ErrorCode.PIN_LIMIT_REACHED]: 'You can pin up to 3 posts.',
  [ErrorCode.REPORT_ALREADY_RESOLVED]: 'The report was already resolved.',
  [ErrorCode.LIVE_SCHEDULE_FULL]: 'You can schedule up to 10 lives.',
  [ErrorCode.LIVE_SEAT_UNAVAILABLE]: 'That seat is not available.',
  [ErrorCode.LIVE_REQUEST_NOT_PENDING]: 'The request or invitation is no longer pending.',
  [ErrorCode.LIVE_QUESTIONS_CLOSED]: 'The host is not taking questions now.',
  [ErrorCode.LIVE_NOT_STREAMER]: 'This live is not a streamer live.',
  [ErrorCode.LIVE_CHAT_NOT_IN_ROOM]: 'Join the live to chat.',
  [ErrorCode.LIVE_CHAT_MUTED]: 'You are muted in this live.',
  [ErrorCode.LIVE_CHAT_CLOSED]: 'The chat is off.',
  [ErrorCode.INSUFFICIENT_COINS]: 'Not enough coins.',
  [ErrorCode.LIVE_KICKED]: 'You were removed from this live.',
  [ErrorCode.ALREADY_IN_FAMILY]: 'Already in a family.',
  [ErrorCode.FAMILY_FULL]: 'The family is full.',
  [ErrorCode.FAMILY_NAME_TAKEN]: 'That family name is taken.',
  [ErrorCode.FAMILY_REQUEST_PENDING]: 'You already asked to join a family.',
  [ErrorCode.FAMILY_REQUEST_NOT_PENDING]: 'The join request is no longer pending.',
  [ErrorCode.FAMILY_NOT_EMPTY]: 'The family still has members.',
  [ErrorCode.FAMILY_LEADER_CANNOT_LEAVE]: 'Hand the family over before leaving.',
  [ErrorCode.FAMILY_CHAT_MUTED]: 'You are muted in this family chat.',
  [ErrorCode.LUCKY_GIFT_AGE_UNCONFIRMED]: 'Confirm that you are 18 or older to send lucky gifts.',
  [ErrorCode.LUCKY_GIFT_REGION_UNAVAILABLE]: 'Lucky gifts are not available in your region.',
  [ErrorCode.PREMIUM_USERNAME_UNAVAILABLE]: 'This username cannot be rented now.',
  [ErrorCode.PREMIUM_USERNAME_PRICE_CHANGED]: 'The price of this username changed.',
  [ErrorCode.PREMIUM_USERNAME_ACTIVE]: 'You already have a premium username.',
  [ErrorCode.DM_NOT_ALLOWED]: 'This person does not accept messages from you.',
  [ErrorCode.DM_REQUEST_LIMIT]: 'Wait for a reply before sending more messages.',
  [ErrorCode.DM_REQUEST_TEXT_ONLY]: 'Only text, emojis and gifts can be sent until the request is accepted.',
  [ErrorCode.DM_DELETE_WINDOW_PASSED]: 'This message can no longer be deleted for everyone.',
  [ErrorCode.CP_ALREADY_PAIRED]: 'Already in a CP couple.',
  [ErrorCode.CP_REQUEST_PENDING]: 'You already have a pending CP request.',
  [ErrorCode.CP_REQUEST_NOT_PENDING]: 'The CP request is no longer pending.',
  [ErrorCode.CP_NOT_PAIRED]: 'You have no CP partner.',
  [ErrorCode.MEDAL_NOT_UNLOCKED]: 'You have not unlocked that medal.',
  [ErrorCode.BAG_ITEM_NOT_OWNED]: 'You do not own that item.',
  [ErrorCode.BAG_ITEM_NOT_TRANSFERABLE]: 'This item cannot be sent.',
  [ErrorCode.BAG_SEND_PERMANENT_WHOLE_ONLY]: 'A permanent item can only be sent whole.',
  [ErrorCode.BAG_SEND_EXCEEDS_REMAINING]: 'That is more time than the item has left.',
  [ErrorCode.BAG_RECIPIENT_HAS_PERMANENT]: 'They already own this item permanently.',
  [ErrorCode.GIFT_UNAVAILABLE]: 'That gift is not available.',
  [ErrorCode.GIFT_BAG_INSUFFICIENT]: 'Not enough of that gift in your bag.',
  [ErrorCode.LIVE_GIFT_RECIPIENT_UNAVAILABLE]: 'A recipient cannot receive gifts in this live now.',
  [ErrorCode.CP_TASK_NOT_COMPLETED]: 'That CP task is not completed yet today.',
  [ErrorCode.CP_PRIVILEGE_LOCKED]: 'This couple has not unlocked that CP privilege.',
  [ErrorCode.QUIP_FREE_USED]: 'You already sent your free quip in this live.',
  [ErrorCode.QUIP_QUEUE_FULL]: 'Too many quips are waiting in this live; try again in a moment.',
  [ErrorCode.BOOST_QUEUE_FULL]: 'The featured slots are booked too far ahead; try a shorter card or later.',
  [ErrorCode.BOOST_CARD_INSUFFICIENT]: 'You have no traffic card of that length.',
  [ErrorCode.BOOST_ROOM_BUSY]: 'This live already has a traffic card running or waiting.',
  [ErrorCode.YOUTUBE_VIDEO_UNAVAILABLE]: 'This YouTube video cannot be played here.',
  [ErrorCode.YOUTUBE_SEARCH_UNAVAILABLE]: 'YouTube search is not available; paste a link instead.',
  [ErrorCode.TASK_NOT_COMPLETED]: 'That task is not completed yet.',
  [ErrorCode.TASK_DAILY_CAP_REACHED]: 'You already got today’s maximum of task rewards.',
  [ErrorCode.FOLLOW_REQUEST_NOT_PENDING]: 'That follow request is no longer pending.',
  [ErrorCode.AGENCY_ALREADY_MEMBER]: 'You are already a host of another agency.',
  [ErrorCode.AGENCY_JOIN_NOT_ALLOWED]: 'An agency owner cannot join an agency as a host.',
  [ErrorCode.AGENCY_LEAVE_WINDOW_CLOSED]: 'The leave window is over; send a complaint to the admin.',
  [ErrorCode.AGENCY_OPEN_NOT_ALLOWED]: 'You cannot open an agency now.',
  [ErrorCode.HOST_APPLICATION_NOT_ALLOWED]: 'You cannot apply to host with the Kabso team now.',
  [ErrorCode.CREATOR_APPLICATION_NOT_ALLOWED]: 'You cannot apply to the creator programme now.',
  [ErrorCode.AGENCY_ACTIVATION_NOT_ALLOWED]: 'This member cannot be activated that way.',
  [ErrorCode.LEVEL_RAISE_DUPLICATE]:
    'This source account already has a pending or approved level-raise request.',
  [ErrorCode.KYC_NOT_ALLOWED]: 'An identity check cannot be started now.',
  [ErrorCode.KYC_UNAVAILABLE]: 'Identity verification is not available right now.',
  [ErrorCode.INSUFFICIENT_CHERRIES]: 'Not enough cherries for that withdrawal.',
  [ErrorCode.WITHDRAWAL_PENDING]: 'You already have a withdrawal waiting to be paid.',
  [ErrorCode.RECHARGE_APPLICATION_NOT_ALLOWED]: 'You cannot apply to be a recharge agent now.',
  [ErrorCode.RECHARGE_AGENT_NOT_ACTIVE]: 'This recharge agent is not active.',
  [ErrorCode.RECHARGE_OFF_SHIFT]: 'You can act for the agent only during your working hours.',
  [ErrorCode.RECHARGE_STOCK_INSUFFICIENT]: 'Not enough coins in the stock.',
  [ErrorCode.RECHARGE_EMPLOYEE_NOT_ALLOWED]: 'This person cannot be added as an employee.',
  [ErrorCode.RECHARGE_CHERRY_REQUEST_PENDING]: 'There is already an open request between you.',
  [ErrorCode.RECHARGE_CHERRY_REQUEST_CLOSED]: 'This request is no longer open.',
  [ErrorCode.RECHARGE_CHERRY_CAP_REACHED]: "The agent's daily cherry limit is reached.",
  [ErrorCode.USERNAME_LOCKED]: 'Your username is locked while your special username is active.',
  [ErrorCode.HOST_FRAME_STYLE_FROM_GENDER]: 'Your gender sets the colour of your host frame.',
  [ErrorCode.TASK_MONTHLY_CAP_REACHED]: 'You already got this month’s maximum of task rewards.',
  [ErrorCode.TOPUP_UNAVAILABLE]: 'Card top-up is not enabled (الشحن بالبطاقة غير مفعّل).',
  [ErrorCode.TOPUP_ACCOUNT_FROZEN]: 'Card purchases are frozen on this account.',
  [ErrorCode.ADMIN_PANEL_UNAVAILABLE]: 'The admin panel is not available.',
  [ErrorCode.ADMIN_LOCKED]: 'Too many failed attempts. Try again later.',
  [ErrorCode.ADMIN_TOTP_INVALID]: 'The code is not valid.',
  [ErrorCode.ADMIN_CSRF_INVALID]: 'The request is missing a valid CSRF token.',
  [ErrorCode.ADMIN_ACTION_REFUSED]: 'The action was refused.',
  [ErrorCode.REAUTH_FAILED]: 'The password is not correct.',
  [ErrorCode.ACCOUNT_DELETION_BLOCKED]: 'Some things must be settled before this account can be deleted.',
  [ErrorCode.ACCOUNT_DELETION_PENDING]: 'This account is scheduled for deletion.',
  [ErrorCode.CONSENT_REQUIRED]: 'Please review and accept the updated terms and privacy policy.',
  [ErrorCode.CONSENT_VERSION_MISMATCH]: 'A newer version is in force; review it again.',
  [ErrorCode.DATA_EXPORT_LIMIT]: 'You can ask for one copy of your data every 24 hours.',
  [ErrorCode.DATA_EXPORT_LINK_INVALID]: 'This download link is no longer valid.',
  [ErrorCode.PK_UNAVAILABLE]: 'This live cannot start a PK now.',
  [ErrorCode.PK_HOST_BUSY]: 'That host is already in a PK or answering an invitation.',
  [ErrorCode.PK_INVITES_OFF]: 'This host does not accept PK invitations.',
  [ErrorCode.PK_INVITE_COOLDOWN]: 'Wait a moment before inviting again.',
  [ErrorCode.PK_INVITE_CLOSED]: 'This PK invitation is no longer open.',
  [ErrorCode.PK_NOT_ACTIVE]: 'There is no PK in this live now.',
  [ErrorCode.PK_BOOSTER_UNAVAILABLE]: 'That booster cannot be used now.',
  [ErrorCode.PK_DARE_CLOSED]: 'This dare can no longer be answered.',
  [ErrorCode.PK_DARE_FORBIDDEN]: 'Only the other host can do that.',
  [ErrorCode.PK_REMATCH_UNAVAILABLE]: 'Another round is not possible now.',
  [ErrorCode.PK_REMATCH_CLOSED]: 'This offer of another round is no longer open.',
  [ErrorCode.SECOND_CAMERA_CODE_INVALID]: 'That pairing code is not valid.',
  [ErrorCode.SECOND_CAMERA_UNAVAILABLE]: 'This live cannot take a second camera now.',
  [ErrorCode.SECOND_CAMERA_BUSY]: 'This live already has a second camera.',
  [ErrorCode.RECHARGE_ORDERS_UNAVAILABLE]: 'Recharge orders are not available.',
  [ErrorCode.RECHARGE_ORDER_OPEN_EXISTS]: 'You already have an open order with this agent.',
  [ErrorCode.RECHARGE_ORDER_STATE_CHANGED]: 'This order has changed. Refresh it.',
  [ErrorCode.RECHARGE_ORDER_NOTICE_REQUIRED]: 'Read and acknowledge the protection notice first.',
  [ErrorCode.RECHARGE_ORDER_DISPUTE_TOO_EARLY]: 'You can open a dispute when the wait is over.',
  [ErrorCode.RECHARGE_EMPLOYEE_NOT_PERMITTED]: 'The agent has not allowed you to do this.',
  [ErrorCode.RECHARGE_ORDER_CLAIMED]: 'Another person of the agent already took this order.',
  [ErrorCode.RECHARGE_EMPLOYEE_IS_STAFF]: "A Kabso Team account cannot be a recharge agent's employee.",
  [ErrorCode.ACCOUNT_LOCKED]: 'This account is locked for a while.',
  [ErrorCode.ACCOUNT_RESTRICTED]: 'This is switched off for your account for a while.',
  [ErrorCode.PASSWORD_CHANGE_REQUIRED]: 'Choose a new password to continue.',
  [ErrorCode.REFERRAL_UNAVAILABLE]: 'Inviting friends is not available now.',
  [ErrorCode.REFERRAL_CODE_INVALID]: 'This invite code is not valid.',
  [ErrorCode.REFERRAL_NOT_ALLOWED]: 'You cannot enter an invite code now.',
  [ErrorCode.DEVICE_ACCOUNT_LIMIT]:
    'This device cannot create more accounts. You can sign in to your existing accounts.',
  [ErrorCode.DEVICE_BANNED]: 'This device is banned by the Kabso team.',
  [ErrorCode.VIP_UNAVAILABLE]: 'This VIP tier cannot be bought now.',
  [ErrorCode.VIP_PRICE_CHANGED]: 'The price of this VIP tier changed.',
  [ErrorCode.STORE_UNAVAILABLE]: 'This store item cannot be bought now.',
  [ErrorCode.STORE_PRICE_CHANGED]: 'The price of this store item changed.',
  [ErrorCode.STAFF_PROTECTED]: 'This cannot be done to the Kabso Team.',
  [ErrorCode.LIVE_STAFF_REFUSED]: 'The Kabso Team does not do this in a live.',
  [ErrorCode.STAFF_STEP_UP_REQUIRED]: 'Enter your authenticator code to use the staff tools.',
  [ErrorCode.STAFF_TOTP_NOT_ENROLLED]: 'Set up the authenticator in the admin panel first.',
  [ErrorCode.STAFF_ACCOUNT_LIMITED]: 'A Kabso Team account cannot do this.',
  [ErrorCode.ITEM_BADGES_INVALID]: 'These badges cannot be set together.',
};

export interface ErrorDetail {
  readonly field: string;
  readonly issue: string;
}

export interface ErrorEnvelope {
  error: {
    code: ErrorCode;
    message: string;
    details?: ErrorDetail[];
    requestId: string;
  };
}
