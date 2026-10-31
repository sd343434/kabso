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
  /** v1.52-social (DRAFT, D179): the cherry balance does not cover the withdrawal. */
  INSUFFICIENT_CHERRIES = 'INSUFFICIENT_CHERRIES',
  /** v1.52-social (DRAFT, D179): the caller already has a withdrawal waiting to be paid. */
  WITHDRAWAL_PENDING = 'WITHDRAWAL_PENDING',
  /** v1.54-social (DRAFT, D185): A pending application, already an agent, or an employee of an agent. */
  RECHARGE_APPLICATION_NOT_ALLOWED = 'RECHARGE_APPLICATION_NOT_ALLOWED',
  /** v1.54-social (DRAFT, D185): The recharge agent is not ACTIVE (waiting for the first top-up, or suspended). */
  RECHARGE_AGENT_NOT_ACTIVE = 'RECHARGE_AGENT_NOT_ACTIVE',
  /** v1.54-social (DRAFT, D185): An employee tried to sell outside their working hours. */
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
  [ErrorCode.INSUFFICIENT_CHERRIES]: 'Not enough cherries for that withdrawal.',
  [ErrorCode.WITHDRAWAL_PENDING]: 'You already have a withdrawal waiting to be paid.',
  [ErrorCode.RECHARGE_APPLICATION_NOT_ALLOWED]: 'You cannot apply to be a recharge agent now.',
  [ErrorCode.RECHARGE_AGENT_NOT_ACTIVE]: 'This recharge agent is not active.',
  [ErrorCode.RECHARGE_OFF_SHIFT]: 'You can sell only during your working hours.',
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
