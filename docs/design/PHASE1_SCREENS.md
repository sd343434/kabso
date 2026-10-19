# Kabso Live — Phase 1 Screen Specs

> **Contract v1.2 update:** [`PHASE1_1_SCREENS.md`](PHASE1_1_SCREENS.md) supersedes parts of this
> document — register submit (§4.3), display-name rules, the verify-email screens (§6, retired),
> the Profile verify banner (§8), the language rule (§1), and final error copy (§10, via its §5
> KL-015 decisions). Where the two differ, PHASE1_1_SCREENS wins.

Status: **Implementable specification (KL-004).** Describes what Flutter (KL-003) should build;
it does not claim anything is built. Tokens: [`../contracts/design-tokens.json`](../contracts/design-tokens.json).
Components: [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) §9. API: [`../contracts/openapi.yaml`](../contracts/openapi.yaml),
errors: [`../contracts/CONVENTIONS.md`](../contracts/CONVENTIONS.md) §4.

Conventions in this doc:

- Layout is listed **top → bottom**; horizontal positions use **start / end** (start = right in
  Arabic). Default side gutter is `spacing.lg` (16) on start and end.
- Every user-facing string has an ARB key (camelCase) with **ar** and **en** copy. Placeholders
  use ICU syntax. ar is the default locale.
- `{username}`, `{email}`, device names are wrapped in Unicode isolates (`bidiIsolate`,
  DESIGN_SYSTEM §3.4) when embedded in a sentence.
- Error presentation for every code is defined once in **§10** and referenced by screens.

Screens: §1 Global patterns · §2 Splash · §3 Login · §4 Register · §5 Forgot password (+ sent,
reset) · §6 Verify email (notice, result) · §7 Tab shell + phase empty states · §8 Profile tab ·
§9 Settings (theme, language, sessions, logout) · §10 Error copy · §11 QA checklist.

---

## 1. Global patterns (Phase 1)

| Pattern | Spec |
| ------- | ---- |
| Theme | Default **Dark**. User choice Dark / Light / System stored locally (shared preferences); applied before first frame to avoid flash. |
| Locale | First launch: device language `en*` → `en`; anything else → `ar`. User choice stored locally; sent as `Accept-Language` and as `locale` in register. Switching locale rebuilds the app without restarting or losing navigation state. |
| Text input direction | Email, username, password, identifier fields are `TextDirection.ltr` in both locales; their labels/helper text follow the locale. |
| Offline banner | When connectivity is lost on a signed-in screen: a 32 dp strip under the TopBar, `surfaceOverlay`, `caption`, cloud-off icon at start, copy `offlineBanner`. Slides in `durationBaseMs`. Disappears on reconnect. Not used on auth forms (they show errors on submit). |
| Form submit | Primary button enters **loading**; all fields read-only during the request; keyboard stays open; double-submit impossible. |
| Form validation timing | Validate a field on blur and on submit; after the first submit attempt, re-validate on every change. First invalid field receives focus and its error is announced. |
| Form-level error banner | Inline block above the primary button: `surface` fill, radius `sm`, padding `md`, error icon (20, `error`) at start + `body` text; `liveRegion`. Used for non-field errors (credentials, rate limit, network, server). Cleared when the user edits any field. |
| Snackbar | Confirmations (`KSnackbar`), 4 s. |
| Keyboard | Auth screens scroll; primary button stays reachable above the keyboard (scroll into view on focus). "Next" moves field-to-field; last field "Done/Go" submits. |
| Session expiry while using app | Single-flight refresh (CONVENTIONS §6). If refresh fails with `AUTH_REFRESH_INVALID` or `ACCOUNT_SUSPENDED` → clear tokens → Login with snackbar `errAuthRefreshInvalid` or suspended banner. |

Global strings:

| Key | en | ar |
| --- | -- | -- |
| `appName` | Kabso Live | Kabso Live |
| `offlineBanner` | You're offline. Some things may not update. | أنت غير متصل. قد لا يتم تحديث بعض المحتوى. |
| `actionTryAgain` | Try again | حاول مرة أخرى |
| `actionCancel` | Cancel | إلغاء |
| `actionBack` | Back | رجوع |
| `actionClose` | Close | إغلاق |
| `actionContinue` | Continue | متابعة |
| `loadingLabel` | Loading | جارٍ التحميل |
| `fieldRequired` | This field is required | هذا الحقل مطلوب |
| `errorIdLabel` | Error ID: {requestId} | رمز الخطأ: {requestId} |

---

## 2. Splash

**Purpose:** restore the session and route. No artificial delay.

Layout (dark `background`, always dark regardless of theme to avoid a flash):

| Region | Spec |
| ------ | ---- |
| Centre | Wordmark text `appName` in `display` (Inter 700 in both locales — brand is Latin; B8 placeholder until logo) `textPrimary` |
| Below wordmark, `xxl` gap | Circular ProgressBar 24 dp, appears only if routing takes > 600 ms |
| Error state | Replaces indicator: ErrorState (inline variant) with code-mapped title/body (§10), `actionTryAgain` secondary button, and text button `splashSignOut` under it |

Routing logic:

| Condition | Result |
| --------- | ------ |
| No refresh token in secure storage | → Login |
| `POST /auth/refresh` 200 → `GET /me` 200 | → Shell (Home tab). If `emailVerified=false`, Profile shows the verify banner (no forced screen) |
| `AUTH_REFRESH_INVALID` (401) | Clear tokens → Login + snackbar `errAuthRefreshInvalid` |
| `ACCOUNT_SUSPENDED` (403) | Clear tokens → Login with suspended banner (§3) |
| `NETWORK_OFFLINE`, `NETWORK_TIMEOUT`, `RATE_LIMITED`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE` | **Keep tokens.** Show error state with Try again (auto-retry once when connectivity returns) |

| Key | en | ar |
| --- | -- | -- |
| `splashLoadingLabel` | Loading Kabso Live | جارٍ تحميل Kabso Live |
| `splashSignOut` | Log out instead | تسجيل الخروج بدلًا من ذلك |

A11y: semantics label `splashLoadingLabel`; wordmark excluded (decorative duplicate).

---

## 3. Login

TopBar: `large` variant, no back button (root). End action: language Chip (§3 table).

| # | Element | Component | Spacing / notes |
| - | ------- | --------- | --------------- |
| 1 | Language switch | Chip `suggestion` at TopBar end: shows the *other* language name ("English" in ar, "العربية" in en) | Tapping switches instantly |
| 2 | Wordmark | `appName`, `headline`, start-aligned | top `xl` |
| 3 | Title | `loginTitle`, `headline` | `sm` below wordmark |
| 4 | Subtitle | `loginSubtitle`, `body`, `textSecondary` | `xs` below |
| 5 | Identifier | TextField `text` (LTR, keyboard `emailAddress`, autofill `username`+`email`, no autocorrect) | `xl` below subtitle |
| 6 | Password | TextField `password` (autofill `password`) with show/hide | `lg` below |
| 7 | Forgot link | Button `text` `loginForgot`, aligned **end** | `sm` below password |
| 8 | Suspended banner (conditional) | Form banner with `ACCOUNT_SUSPENDED` copy + support text button (hidden until B7 contact exists) | `lg` below |
| 9 | Error banner (conditional) | Form-level banner (§1) | `lg` |
| 10 | Primary CTA | Button `primary` `large`, full width, `loginSubmit` | `xxl` below last field/banner |
| 11 | Register prompt | Row centred: `loginNoAccount` (`body`, `textSecondary`) + Button `text` `loginCreateAccount` | `lg` below CTA; bottom padding `xl` + inset |

Behaviour:

| Event | Behaviour |
| ----- | --------- |
| Client validation | identifier: required, ≥ 3 chars (`loginIdentifierTooShort`); password: required. Trim identifier; never trim password. |
| Submit | `POST /auth/login` with `identifier`, `password`, `device {name, platform, appVersion}` |
| 200 | Store tokens → Shell (Home). Password field cleared from memory. |
| `AUTH_INVALID_CREDENTIALS` | Error banner `errAuthInvalidCredentials`; clear password field; focus password. **Do not** say which part is wrong. |
| `ACCOUNT_SUSPENDED` | Suspended banner (#8) |
| `RATE_LIMITED` | Banner with countdown from `Retry-After` (`errRateLimitedWait`, mm:ss, updates each second visually; announced once); CTA disabled until 0 |
| `VALIDATION_FAILED` | Map `details[].field` (`identifier`, `password`) to field errors; unknown field → banner `errValidationFailed` |
| Network / 5xx | Banner with §10 copy; CTA re-enabled |

| Key | en | ar |
| --- | -- | -- |
| `loginTitle` | Welcome back | مرحبًا بعودتك |
| `loginSubtitle` | Log in to continue | سجّل الدخول للمتابعة |
| `loginIdentifierLabel` | Email or username | البريد الإلكتروني أو اسم المستخدم |
| `loginPasswordLabel` | Password | كلمة المرور |
| `passwordShow` | Show password | إظهار كلمة المرور |
| `passwordHide` | Hide password | إخفاء كلمة المرور |
| `loginForgot` | Forgot password? | نسيت كلمة المرور؟ |
| `loginSubmit` | Log in | تسجيل الدخول |
| `loginNoAccount` | Don't have an account? | ليس لديك حساب؟ |
| `loginCreateAccount` | Create one | أنشئ حسابًا |
| `loginIdentifierTooShort` | Enter at least 3 characters | أدخل 3 أحرف على الأقل |
| `languageNameAr` | العربية | العربية |
| `languageNameEn` | English | English |
| `suspendedSupport` | Contact support | تواصل مع الدعم |

---

## 4. Register

TopBar: `large`, back (flips) at start, title `registerTitle`.

| # | Element | Component | Spacing / notes |
| - | ------- | --------- | --------------- |
| 1 | Subtitle | `registerSubtitle`, `body`, `textSecondary` | top `sm` |
| 2 | Display name | TextField `text`, max 50, counter at end, autofill `name`, capitalisation words (en) | `xl` |
| 3 | Username | TextField `username` (`@` prefix at start, LTR, lowercase transform, max 30) with availability status (below) | `lg` |
| 4 | Email | TextField `email`, max 254, autofill `email` | `lg` |
| 5 | Password | TextField `password`, autofill `newPassword`, helper `registerPasswordHelper` | `lg` |
| 6 | Terms line | `caption` `textSecondary`, `registerTerms`; "Terms" and "Privacy Policy" become links when B7 URLs exist (plain text until then) | `lg` |
| 7 | Error banner (conditional) | Form-level banner | `lg` |
| 8 | Primary CTA | Button `primary` `large`, `registerSubmit` | `xxl` |
| 9 | Login prompt | `registerHaveAccount` + Button `text` `registerLogIn` | `lg`; bottom `xl` + inset |

### 4.1 Field rules (client-side, mirror openapi)

| Field | Rule | Error key |
| ----- | ---- | --------- |
| displayName | 1–50 chars after trim | `fieldRequired`, `registerDisplayNameTooLong` |
| username | regex `^[a-z0-9](?:[a-z0-9._]{1,28}[a-z0-9])?$`; input auto-lowercased; spaces rejected on input | see 4.2 |
| email | trimmed, lowercased on submit, basic `x@y.z` check, ≤ 254 | `registerEmailInvalid` |
| password | 8–128 chars; no composition rules; never trimmed | `registerPasswordTooShort`, `registerPasswordTooLong` |

### 4.2 Username availability states

Trigger: 400 ms debounce after the last keystroke, only when the value passes the regex. Each
response is ignored if the field value changed since the request (compare `username` in the
response). In-flight request is cancelled on new input.

| State | When | Field visual | Helper line (live region) |
| ----- | ---- | ------------ | ------------------------- |
| `idle` | Empty, or not yet edited | default | `registerUsernameHelper` (`textSecondary`) |
| `invalid` | Fails regex (no request sent) | error boundary + error icon | specific reason: `usernameTooShort` / `usernameTooLong` / `usernameBadChars` / `usernameBadEdges` |
| `checking` | Request in flight | trailing 16 dp spinner | `usernameChecking` (`textSecondary`) |
| `available` | `available: true` | trailing check icon (`success`) | `usernameAvailable` (`success` dark / `textPrimary` light) |
| `taken` | `available: false` (includes reserved names) | error boundary + error icon | `usernameTaken` (`error`) |
| `unknown` | Check failed (offline, timeout, 429, 5xx) | default + trailing info icon | `usernameCheckFailed` (`textSecondary`) — submit still allowed; server decides |

Reason precedence for `invalid`: bad characters → too short → too long → bad edges
(leading/trailing `.`/`_`). Submit is blocked while `invalid` or `taken`; if `checking` at
submit, the CTA shows loading and waits for the result (max 3 s, then proceeds).

### 4.3 Submit

| Response | Behaviour |
| -------- | --------- |
| 201 | Store tokens → Verify-email notice (§6.1) |
| `USERNAME_TAKEN` (409) | Username → `taken` state, focus it |
| `EMAIL_TAKEN` (409) | Email field error `errEmailTaken` with an inline text button `registerGoToLogin`. (The contract reveals email use at registration; copy stays neutral.) |
| `VALIDATION_FAILED` | Map `details[].field` (`email`, `password`, `username`, `displayName`) to fields; otherwise banner |
| `RATE_LIMITED` | Banner with countdown (`errRateLimitedWait`) |
| Network / 5xx | Banner (§10) |

| Key | en | ar |
| --- | -- | -- |
| `registerTitle` | Create your account | أنشئ حسابك |
| `registerSubtitle` | It takes less than a minute. | لن يستغرق الأمر أكثر من دقيقة. |
| `registerDisplayNameLabel` | Display name | الاسم الظاهر |
| `registerDisplayNameHelper` | Shown on your profile | يظهر في ملفك الشخصي |
| `registerDisplayNameTooLong` | Use 50 characters or fewer | استخدم 50 حرفًا أو أقل |
| `registerUsernameLabel` | Username | اسم المستخدم |
| `registerUsernameHelper` | 3–30 characters: a–z, 0–9, dot and underscore | من 3 إلى 30 حرفًا: a–z و0–9 والنقطة والشرطة السفلية |
| `usernameTooShort` | Use at least 3 characters | استخدم 3 أحرف على الأقل |
| `usernameTooLong` | Use 30 characters or fewer | استخدم 30 حرفًا أو أقل |
| `usernameBadChars` | Use only a–z, 0–9, dot (.) and underscore (_) | استخدم فقط a–z و0–9 والنقطة (.) والشرطة السفلية (_) |
| `usernameBadEdges` | Can't start or end with a dot or underscore | لا يمكن أن يبدأ أو ينتهي بنقطة أو شرطة سفلية |
| `usernameChecking` | Checking availability… | جارٍ التحقق من التوفر… |
| `usernameAvailable` | @{username} is available | ‏@{username} متاح |
| `usernameTaken` | @{username} isn't available. Try another. | ‏@{username} غير متاح. جرّب اسمًا آخر. |
| `usernameCheckFailed` | Couldn't check right now. You can still continue. | تعذّر التحقق الآن. يمكنك المتابعة على أي حال. |
| `registerEmailLabel` | Email | البريد الإلكتروني |
| `registerEmailInvalid` | Enter a valid email address | أدخل عنوان بريد إلكتروني صالحًا |
| `registerPasswordLabel` | Password | كلمة المرور |
| `registerPasswordHelper` | At least 8 characters | 8 أحرف على الأقل |
| `registerPasswordTooShort` | Use at least 8 characters | استخدم 8 أحرف على الأقل |
| `registerPasswordTooLong` | Use 128 characters or fewer | استخدم 128 حرفًا أو أقل |
| `registerTerms` | By creating an account, you agree to the Terms and the Privacy Policy. | بإنشائك حسابًا، فإنك توافق على الشروط وسياسة الخصوصية. |
| `registerSubmit` | Create account | إنشاء الحساب |
| `registerHaveAccount` | Already have an account? | لديك حساب بالفعل؟ |
| `registerLogIn` | Log in | سجّل الدخول |
| `registerGoToLogin` | Log in instead | سجّل الدخول بدلًا من ذلك |

(`‏` = U+200F RLM at the start of Arabic strings that begin with `@`, so the line resolves RTL.)

---

## 5. Forgot password, Sent, Reset

### 5.1 Forgot password

TopBar `large`, back at start, title `forgotTitle`.

| # | Element | Spec |
| - | ------- | ---- |
| 1 | Body | `forgotBody`, `body` `textSecondary`, top `sm` |
| 2 | Email | TextField `email`, prefilled if Login identifier contained `@`, `xl` |
| 3 | Error banner | conditional, `lg` |
| 4 | CTA | Button `primary` `large` `forgotSubmit`, `xxl` |

| Response | Behaviour |
| -------- | --------- |
| 202 | → Sent screen (5.2). **Identical** for existing and non-existing emails. |
| `VALIDATION_FAILED` | Email field error `registerEmailInvalid` |
| `RATE_LIMITED` | Banner with countdown |
| Network / 5xx | Banner (§10) |

### 5.2 Forgot — Sent (non-enumerating confirmation)

Centred EmptyState-style block (icon: envelope, 48 dp in 88 dp `surface` circle).

| # | Element | Spec |
| - | ------- | ---- |
| 1 | Title | `forgotSentTitle`, `headline`, `xxxl` from top |
| 2 | Body | `forgotSentBody` with isolated `{email}`, `body` `textSecondary`, centred, `sm` |
| 3 | Hint | `forgotSentHint`, `caption` `textSecondary`, `lg` |
| 4 | Resend | Button `secondary` `medium`: disabled with `forgotResendIn` countdown for 60 s, then `forgotResend` (calls the same endpoint; 202 → snackbar `forgotResent`; `RATE_LIMITED` → countdown from `Retry-After`) — `xl` |
| 5 | Back | Button `text` `forgotBackToLogin`, `md` |

### 5.3 Reset password (from email link)

Entry: app link carrying `token` (scheme/domain set by Flutter + CTO; production domain is B7).
TopBar `large`, close (×) at start, title `resetTitle`.

| # | Element | Spec |
| - | ------- | ---- |
| 1 | New password | TextField `password`, autofill `newPassword`, helper `registerPasswordHelper`, `xl` |
| 2 | Confirm | TextField `password`, `lg`; mismatch → `resetMismatch` |
| 3 | Error banner | conditional |
| 4 | CTA | `resetSubmit`, `xxl` |

| Response | Behaviour |
| -------- | --------- |
| 204 | Clear any local tokens (server revoked all sessions) → Login + snackbar `resetDone` |
| `TOKEN_EXPIRED` / `TOKEN_INVALID` | Replace form with ErrorState: §10 copy + Button `resetRequestNew` → Forgot |
| `VALIDATION_FAILED` | Field error on new password |
| Network / 5xx | Banner |

| Key | en | ar |
| --- | -- | -- |
| `forgotTitle` | Reset your password | إعادة تعيين كلمة المرور |
| `forgotBody` | Enter the email you signed up with and we'll send you a reset link. | أدخل البريد الإلكتروني الذي سجّلت به وسنرسل إليك رابطًا لإعادة التعيين. |
| `forgotSubmit` | Send link | إرسال الرابط |
| `forgotSentTitle` | Check your email | تحقّق من بريدك الإلكتروني |
| `forgotSentBody` | If an account exists for {email}, we've sent a link to reset the password. The link expires in 1 hour. | إذا كان هناك حساب مرتبط بـ {email}، فقد أرسلنا إليه رابطًا لإعادة تعيين كلمة المرور. تنتهي صلاحية الرابط خلال ساعة واحدة. |
| `forgotSentHint` | Didn't get it? Check your spam folder. | لم يصلك؟ تحقّق من مجلد الرسائل غير المرغوب فيها. |
| `forgotResend` | Resend link | إعادة إرسال الرابط |
| `forgotResendIn` | Resend in {time} | إعادة الإرسال بعد {time} |
| `forgotResent` | If the account exists, a new link is on its way. | إذا كان الحساب موجودًا، فسيصلك رابط جديد قريبًا. |
| `forgotBackToLogin` | Back to log in | العودة إلى تسجيل الدخول |
| `resetTitle` | Choose a new password | اختر كلمة مرور جديدة |
| `resetNewLabel` | New password | كلمة المرور الجديدة |
| `resetConfirmLabel` | Confirm new password | تأكيد كلمة المرور الجديدة |
| `resetMismatch` | Passwords don't match | كلمتا المرور غير متطابقتين |
| `resetSubmit` | Save password | حفظ كلمة المرور |
| `resetDone` | Password changed. You've been logged out on all devices — log in with your new password. | تم تغيير كلمة المرور. تم تسجيل خروجك من جميع الأجهزة، فسجّل الدخول بكلمة المرور الجديدة. |
| `resetRequestNew` | Request a new link | طلب رابط جديد |

Never: "No account found", "We sent an email to your account", or any copy that differs by
whether the email exists.

---

## 6. Verify email

### 6.1 Verify-email notice

Shown once right after successful registration; afterwards reachable from the Profile banner.
TopBar `large`, no back; end action Button `text` `verifyLater`.

| # | Element | Spec |
| - | ------- | ---- |
| 1 | Icon | envelope-check 48 dp in 88 dp `surface` circle, centred, `xxxl` top |
| 2 | Title | `verifyTitle`, `headline`, centred, `xl` |
| 3 | Body | `verifyBody` with isolated `{email}`, centred, `textSecondary`, `sm` |
| 4 | Status line | conditional `caption`: `verifyNotYet` (`textSecondary`) / resend result, `lg`, live region |
| 5 | Primary | Button `primary` `large` `verifyCheck` → `GET /me`; `emailVerified=true` → snackbar `verifyDone` → Shell; false → status `verifyNotYet` — `xxl` |
| 6 | Secondary | Button `secondary` `large` `verifyResend` → `POST /auth/email/resend` (202 → `verifyResent` + 60 s cooldown showing `forgotResendIn`; `RATE_LIMITED` → countdown) — `md` |
| 7 | Later | (TopBar end) → Shell |

### 6.2 Verify result (from email link)

Entry: app link with `token` → `POST /auth/email/verify` immediately (Splash-like loading
centre spinner + `verifyVerifying`).

| Result | Screen |
| ------ | ------ |
| 204 | Success EmptyState: check icon (`success`), `verifyDone`, Button `primary` `actionContinue` → Shell if signed in (refresh `/me`), else Login |
| `TOKEN_EXPIRED` | ErrorState with `errTokenExpired`; Button: signed in → `verifyResend`; signed out → `forgotBackToLogin` |
| `TOKEN_INVALID` | Same with `errTokenInvalid` |
| Network / 5xx | ErrorState + `actionTryAgain` (re-posts the same token) |

| Key | en | ar |
| --- | -- | -- |
| `verifyTitle` | Verify your email | أكّد بريدك الإلكتروني |
| `verifyBody` | We sent a verification link to {email}. Open it to confirm your account. The link expires in 24 hours. | أرسلنا رابط تأكيد إلى {email}. افتحه لتأكيد حسابك. تنتهي صلاحية الرابط خلال 24 ساعة. |
| `verifyCheck` | I've verified my email | لقد أكّدت بريدي |
| `verifyResend` | Resend email | إعادة إرسال البريد |
| `verifyResent` | Sent. Check your inbox. | تم الإرسال. تحقّق من بريدك الوارد. |
| `verifyNotYet` | Not verified yet. Open the link in the email, then try again. | لم يتم التأكيد بعد. افتح الرابط في البريد ثم حاول مرة أخرى. |
| `verifyLater` | Later | لاحقًا |
| `verifyVerifying` | Verifying your email… | جارٍ تأكيد بريدك الإلكتروني… |
| `verifyDone` | Your email is verified | تم تأكيد بريدك الإلكتروني |
| `verifyBanner` | Your email isn't verified yet. | لم يتم تأكيد بريدك الإلكتروني بعد. |
| `verifyBannerAction` | Verify | تأكيد |

---

## 7. Tab shell and phase empty states

BottomNav per DESIGN_SYSTEM §9.6: Home · Discover · Create (centre, emphasized) · Live ·
Profile. Each tab keeps its own navigator stack (`StatefulShellRoute`). Home is the initial tab.

Each non-Profile tab body: TopBar `standard` with the tab title, then `KEmptyState`
`comingSoon(phase)` vertically centred in the remaining space. No fake content, no skeletons
pretending to load.

| Tab | TopBar title key | Phase Badge | Title key | Body key |
| --- | ---------------- | ----------- | --------- | -------- |
| Home | `tabHome` | `phaseBadge` (2) | `homeSoonTitle` | `homeSoonBody` |
| Discover | `tabDiscover` | `phaseBadge` (9) | `discoverSoonTitle` | `discoverSoonBody` |
| Create | `tabCreate` | — (rows carry badges) | `createSoonTitle` | `createSoonBody` + 4 disabled ListTiles with `phaseBadge`: Post (3), Story (4), Video (5), Live (6) |
| Live | `tabLive` | `phaseBadge` (6) | `liveSoonTitle` | `liveSoonBody` |

The Create tab in Phase 1 is a normal tab destination (in later phases tapping it opens the
Create sheet instead).

| Key | en | ar |
| --- | -- | -- |
| `tabHome` | Home | الرئيسية |
| `tabDiscover` | Discover | استكشاف |
| `tabCreate` | Create | إنشاء |
| `tabLive` | Live | مباشر |
| `tabProfile` | Profile | حسابي |
| `phaseBadge` | Phase {n} | المرحلة {n} |
| `comingInPhase` | Coming in Phase {n} | قادم في المرحلة {n} |
| `homeSoonTitle` | Your feed is on its way | خلاصتك في الطريق |
| `homeSoonBody` | Following people and your home feed arrive in Phase 2; posts in Phase 3. | ستتوفر متابعة الأشخاص وخلاصتك الرئيسية في المرحلة 2، والمنشورات في المرحلة 3. |
| `discoverSoonTitle` | Discover is coming | الاستكشاف قادم |
| `discoverSoonBody` | People search arrives in Phase 2; trending lives, videos and creators in Phase 9. | يتوفر البحث عن الأشخاص في المرحلة 2، والبثوث والفيديوهات وصنّاع المحتوى الرائجون في المرحلة 9. |
| `createSoonTitle` | Creating is coming soon | الإنشاء قادم قريبًا |
| `createSoonBody` | Here's when each tool arrives. | إليك موعد توفر كل أداة. |
| `createPost` | Post | منشور |
| `createStory` | Story | قصة |
| `createVideo` | Video | فيديو |
| `createLive` | Go live | بث مباشر |
| `liveSoonTitle` | Live rooms are coming | غرف البث المباشر قادمة |
| `liveSoonBody` | Watching and hosting live streams arrive in Phase 6; PK battles and gifts in Phase 7. | تتوفر مشاهدة البث المباشر واستضافته في المرحلة 6، ومعارك PK والهدايا في المرحلة 7. |

A11y: each empty state is one semantics group: "{title}. {body}. Coming in Phase {n}". Disabled
Create rows announce "{name}, coming in Phase {n}, disabled".

---

## 8. Profile tab (signed-in basics)

Data: `GET /me` (cached in memory; refreshed on tab open if older than 60 s and on pull-to-refresh).

TopBar `standard`: title `@{username}` (LTR isolate, `title`) at start; end: IconButton
settings (gear, label `settingsTitle`) → Settings.

| # | Element | Spec |
| - | ------- | ---- |
| 1 | Verify banner (if `emailVerified=false`) | `surface` card, radius `md`, padding `md`, margin `lg` gutters + `md` top; info icon (`info`) at start, `verifyBanner` `body`, Button `text` `verifyBannerAction` at end → Verify notice |
| 2 | Avatar | Avatar `lg` (88) with initials fallback (no upload until Phase 2), start-aligned, `xl` top |
| 3 | Display name | `headline`, `md` below avatar; long names wrap to 2 lines then ellipsis |
| 4 | Username | `@{username}` `body` `textSecondary`, `xxs` |
| 5 | Bio | `body`, only when non-null (Phase 1 is always null for new users — render nothing, no placeholder) `sm` |
| 6 | Joined | calendar icon 16 + `profileJoined` `caption` `textSecondary`, `sm` |
| 7 | Edit profile | Button `secondary` `medium`, full width, **disabled** + `phaseBadge`(2) inline, `lg` |
| 8 | Content area | `xl` below: EmptyState `comingSoon` with `profileSoonTitle` / `profileSoonBody` |

No follower/following/post counts in Phase 1 (they would be fake zeros).

| State | Spec |
| ----- | ---- |
| Loading (no cache) | Skeleton: circle 88, bars 160×24, 100×16, 120×12 |
| Error (no cache) | ErrorState from §10 + Try again |
| Offline with cache | Show cached data + offline banner |
| `AUTH_UNAUTHENTICATED` after refresh failure | Global sign-out (§1) |

| Key | en | ar |
| --- | -- | -- |
| `profileJoined` | Joined {monthYear} | انضم في {monthYear} |
| `profileEditSoon` | Edit profile | تعديل الملف الشخصي |
| `profileSoonTitle` | Your posts will live here | ستظهر منشوراتك هنا |
| `profileSoonBody` | Profile editing and followers arrive in Phase 2, posts in Phase 3, stories and highlights in Phase 4. | يتوفر تعديل الملف الشخصي والمتابعون في المرحلة 2، والمنشورات في المرحلة 3، والقصص واللقطات المميزة في المرحلة 4. |

`{monthYear}`: Gregorian, Latin digits — en "October 2026", ar "أكتوبر 2026".

---

## 9. Settings

### 9.1 Settings root

TopBar `standard`, back at start, title `settingsTitle`. Grouped ListTiles on `surface`
(radius `md`), group headers `label` `textSecondary` with `xl` top / `sm` bottom, `lg` gutters.

| Group | Row | Component | Action |
| ----- | --- | --------- | ------ |
| `settingsGroupPreferences` | `settingsTheme` | ListTile `value` (current: Dark/Light/System) | BottomSheet radio list (9.2) |
| | `settingsLanguage` | ListTile `value` (current language in its own script) | BottomSheet radio list (9.2) |
| `settingsGroupAccount` | `settingsEmail` | ListTile `value`: email (LTR) + verified status subtitle (`settingsEmailVerified` / `settingsEmailNotVerified` with `verifyBannerAction` text button) | — |
| | `settingsUsername` | ListTile `value`: `@username` | — (editing Phase 2) |
| `settingsGroupSecurity` | `settingsSessions` | ListTile `navigation` | → Sessions (9.3) |
| `settingsGroupAbout` | `settingsVersion` | ListTile `value`: `{version} ({build})` | long-press copies |
| | `settingsTerms`, `settingsPrivacy` | ListTile `navigation` | **Hidden until B7 URLs exist** |
| — | `settingsLogout` | ListTile `destructive`, `xl` above, no chevron | Dialog (9.4) |

### 9.2 Theme and Language sheets

BottomSheet with title, radio ListTiles, applied **immediately** on tap, sheet closes after
`durationBaseMs`. Theme options: `themeDark` (default, marked with `themeDefault` caption),
`themeLight`, `themeSystem`. Language options show each name in its own script: "العربية",
"English". Language change: re-renders RTL/LTR instantly, keeps the user on Settings.

### 9.3 Active sessions

Data: `GET /auth/sessions` (max 50, newest first). TopBar back + `sessionsTitle`.

| # | Element | Spec |
| - | ------- | ---- |
| 1 | Intro | `sessionsIntro` `body` `textSecondary`, `lg` top |
| 2 | Current device | Group header `sessionsCurrentHeader`; one ListTile: platform icon (android/ios → phone, web → globe, other/null → devices), title `deviceName ?? sessionsUnknownDevice`, Badge `sessionsThisDevice` (`phase`-style neutral badge), subtitle line (below). No revoke button. |
| 3 | Other sessions | Group header `sessionsOtherHeader`; ListTiles as above with trailing Button `destructive` small `sessionsRevoke` |
| 4 | Empty other | If none: `caption` `sessionsOnlyThis` in place of the group |

Subtitle format: `{platformName} · {appVersion} · {lastActive}`; omit null parts.
`lastActive` uses relative time (DESIGN_SYSTEM §3.3) → `sessionsLastActive`. Second subtitle
line: `sessionsSignedIn` with absolute date (`15 Oct 2026` / `15 أكتوبر 2026`).

Revoke flow: tap → Dialog `destructive` (`sessionsRevokeTitle`, `sessionsRevokeBody` with
isolated device name, actions `actionCancel` / `sessionsRevokeConfirm`) → row trailing shows
loading → `DELETE /auth/sessions/{id}`:

| Response | Behaviour |
| -------- | --------- |
| 204 | Remove row (fade `durationBaseMs`), snackbar `sessionsRevoked` |
| `NOT_FOUND` | Remove row, snackbar `sessionsAlreadyEnded` |
| `AUTH_UNAUTHENTICATED` (after refresh fails) | Global sign-out |
| Network / 5xx / 429 | Row returns to normal, snackbar with §10 copy |

Screen states: Loading → Skeleton of 3 ListTiles; Error → ErrorState; Offline → ErrorState
`offline` (no cache for sessions — security data must be fresh). Pull-to-refresh supported.
No "revoke all" in Phase 1 (no endpoint; tell users to use password reset to sign out
everywhere — `sessionsAllHint`).

### 9.4 Logout

Dialog `destructive`: `logoutTitle`, `logoutBody`, actions `actionCancel` /
`logoutConfirm`. Confirm → `POST /auth/logout` with 3 s timeout (best effort) → **always**
delete refresh token from secure storage + clear in-memory state → Login with snackbar
`logoutDone`. Network failure never keeps the user signed in locally.

| Key | en | ar |
| --- | -- | -- |
| `settingsTitle` | Settings | الإعدادات |
| `settingsGroupPreferences` | Preferences | التفضيلات |
| `settingsGroupAccount` | Account | الحساب |
| `settingsGroupSecurity` | Security | الأمان |
| `settingsGroupAbout` | About | حول التطبيق |
| `settingsTheme` | Theme | المظهر |
| `themeDark` | Dark | داكن |
| `themeLight` | Light | فاتح |
| `themeSystem` | Match device | حسب إعدادات الجهاز |
| `themeDefault` | Default | الافتراضي |
| `settingsLanguage` | Language | اللغة |
| `settingsEmail` | Email | البريد الإلكتروني |
| `settingsEmailVerified` | Verified | مؤكَّد |
| `settingsEmailNotVerified` | Not verified | غير مؤكَّد |
| `settingsUsername` | Username | اسم المستخدم |
| `settingsSessions` | Active sessions | الجلسات النشطة |
| `settingsVersion` | Version | الإصدار |
| `settingsTerms` | Terms of Service | شروط الخدمة |
| `settingsPrivacy` | Privacy Policy | سياسة الخصوصية |
| `settingsLogout` | Log out | تسجيل الخروج |
| `sessionsTitle` | Active sessions | الجلسات النشطة |
| `sessionsIntro` | Devices where your account is signed in. End any session you don't recognize. | الأجهزة المسجَّل دخول حسابك عليها. أنهِ أي جلسة لا تتعرّف عليها. |
| `sessionsCurrentHeader` | This device | هذا الجهاز |
| `sessionsOtherHeader` | Other devices | أجهزة أخرى |
| `sessionsThisDevice` | This device | هذا الجهاز |
| `sessionsUnknownDevice` | Unknown device | جهاز غير معروف |
| `sessionsLastActive` | Active {relativeTime} | نشط {relativeTime} |
| `sessionsActiveNow` | Active now | نشط الآن |
| `sessionsSignedIn` | Signed in {date} | تسجيل الدخول في {date} |
| `sessionsOnlyThis` | You're signed in on this device only. | حسابك مسجَّل الدخول على هذا الجهاز فقط. |
| `sessionsRevoke` | End | إنهاء |
| `sessionsRevokeTitle` | End this session? | إنهاء هذه الجلسة؟ |
| `sessionsRevokeBody` | {device} will be logged out right away. | سيتم تسجيل خروج {device} على الفور. |
| `sessionsRevokeConfirm` | End session | إنهاء الجلسة |
| `sessionsRevoked` | Session ended | تم إنهاء الجلسة |
| `sessionsAlreadyEnded` | This session had already ended | كانت هذه الجلسة منتهية بالفعل |
| `sessionsAllHint` | To log out everywhere, reset your password. | لتسجيل الخروج من جميع الأجهزة، أعد تعيين كلمة المرور. |
| `platformAndroid` / `platformIos` / `platformWeb` / `platformOther` | Android / iOS / Web / Other | Android / iOS / الويب / أخرى |
| `logoutTitle` | Log out? | تسجيل الخروج؟ |
| `logoutBody` | You'll need your password to log back in on this device. | ستحتاج إلى كلمة المرور لتسجيل الدخول مجددًا على هذا الجهاز. |
| `logoutConfirm` | Log out | تسجيل الخروج |
| `logoutDone` | You've logged out | تم تسجيل خروجك |

Relative-time strings (`relativeTime`, Latin digits), written in full (D47): en `just now`,
`{n} minute(s) ago`, `{n} hour(s) ago`, `{n} day(s) ago`; ar `الآن` and Arabic plural forms
(`منذ دقيقة`, `منذ دقيقتين`, `منذ {n} دقائق`, `منذ {n} دقيقة`; likewise ساعة/ساعتين/ساعات and
يوم/يومين/أيام/يومًا). Beyond 7 days, use the absolute
date. In `sessionsLastActive`, "just now" maps to `sessionsActiveNow`.

---

## 10. Error copy (every CONVENTIONS §4 code + client-only codes)

Clients branch on `code`, never on `message`. Unknown codes → `errUnknown`. Show
`errorIdLabel` (selectable `caption`) under the message for `INTERNAL_ERROR`,
`SERVICE_UNAVAILABLE` and `errUnknown` when a `requestId` exists.

| Code | Key | en | ar | Default presentation |
| ---- | --- | -- | -- | -------------------- |
| `VALIDATION_FAILED` | `errValidationFailed` | Some details need fixing. Check the highlighted fields. | بعض البيانات تحتاج إلى تصحيح. راجع الحقول المحدَّدة. | Field errors from `details`; banner if no field matches |
| `AUTH_UNAUTHENTICATED` | `errAuthUnauthenticated` | Your session has ended. Please log in again. | انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى. | Refresh once silently; if still failing → Login + snackbar |
| `AUTH_INVALID_CREDENTIALS` | `errAuthInvalidCredentials` | The email/username or password is incorrect. | البريد الإلكتروني/اسم المستخدم أو كلمة المرور غير صحيحة. | Login banner |
| `AUTH_REFRESH_INVALID` | `errAuthRefreshInvalid` | You've been logged out. Please log in again. | تم تسجيل خروجك. يُرجى تسجيل الدخول مرة أخرى. | Clear tokens → Login + snackbar |
| `AUTH_FORBIDDEN` | `errAuthForbidden` | You don't have permission to do this. | ليست لديك صلاحية للقيام بذلك. | Snackbar (action) / ErrorState `forbidden` (screen) |
| `ACCOUNT_SUSPENDED` | `errAccountSuspended` | This account has been suspended. If you think this is a mistake, contact support. | تم إيقاف هذا الحساب. إذا كنت تعتقد أن هذا خطأ، فتواصل مع الدعم. | Clear tokens → Login suspended banner |
| `NOT_FOUND` | `errNotFound` | This isn't available. It may have been removed. | هذا المحتوى غير متاح. ربما تمت إزالته. | ErrorState `notFound` (screen) / snackbar (action) |
| `EMAIL_TAKEN` | `errEmailTaken` | This email can't be used to create a new account. Try logging in or resetting your password. | لا يمكن استخدام هذا البريد الإلكتروني لإنشاء حساب جديد. جرّب تسجيل الدخول أو إعادة تعيين كلمة المرور. | Register email field |
| `USERNAME_TAKEN` | `errUsernameTaken` | This username isn't available. Try another. | اسم المستخدم هذا غير متاح. جرّب اسمًا آخر. | Username field (`taken`) |
| `IDEMPOTENCY_CONFLICT` | `errIdempotencyConflict` | This request was already sent with different details. Refresh and try again. | سبق إرسال هذا الطلب ببيانات مختلفة. حدّث الصفحة وحاول مرة أخرى. | Snackbar (not reachable in Phase 1; required for Phase 8) |
| `TOKEN_EXPIRED` | `errTokenExpired` | This link has expired or has already been used. Request a new one. | انتهت صلاحية هذا الرابط أو سبق استخدامه. اطلب رابطًا جديدًا. | ErrorState on Reset / Verify result |
| `TOKEN_INVALID` | `errTokenInvalid` | This link isn't valid. Request a new one. | هذا الرابط غير صالح. اطلب رابطًا جديدًا. | ErrorState on Reset / Verify result |
| `RATE_LIMITED` | `errRateLimitedWait` | Too many attempts. Try again in {time}. | محاولات كثيرة. حاول مرة أخرى بعد {time}. | Banner + disabled CTA countdown (`{time}` = `m:ss` from `Retry-After`) |
| `RATE_LIMITED` (no `Retry-After`) | `errRateLimited` | Too many attempts. Wait a moment, then try again. | محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى. | Banner / snackbar |
| `INTERNAL_ERROR` | `errInternal` | Something went wrong on our side. Please try again. | حدث خطأ من جهتنا. يُرجى المحاولة مرة أخرى. | Banner / ErrorState `server` + Error ID |
| `SERVICE_UNAVAILABLE` | `errServiceUnavailable` | Kabso Live is temporarily unavailable. Please try again shortly. | Kabso Live غير متاح مؤقتًا. يُرجى المحاولة بعد قليل. | Banner / ErrorState `server` + Error ID |
| `NETWORK_OFFLINE` (client) | `errNetworkOffline` | You're offline. Check your connection and try again. | أنت غير متصل بالإنترنت. تحقّق من اتصالك وحاول مرة أخرى. | Banner (forms) / ErrorState `offline` (screens) / offline strip (cached screens) |
| `NETWORK_TIMEOUT` (client) | `errNetworkTimeout` | The connection timed out. Please try again. | انتهت مهلة الاتصال. يُرجى المحاولة مرة أخرى. | Banner / ErrorState `timeout` |
| *(unknown code)* | `errUnknown` | Something went wrong. Please try again. | حدث خطأ ما. يُرجى المحاولة مرة أخرى. | Banner / ErrorState + Error ID |

ErrorState titles (used above the body copy on full-screen errors):

| Key | en | ar | Used for |
| --- | -- | -- | -------- |
| `errTitleOffline` | No connection | لا يوجد اتصال | `NETWORK_OFFLINE` |
| `errTitleTimeout` | Taking too long | يستغرق الأمر وقتًا طويلًا | `NETWORK_TIMEOUT` |
| `errTitleServer` | Something went wrong | حدث خطأ ما | `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`, unknown |
| `errTitleNotFound` | Not available | غير متاح | `NOT_FOUND` |
| `errTitleForbidden` | Not allowed | غير مسموح | `AUTH_FORBIDDEN` |
| `errTitleLink` | Link can't be used | لا يمكن استخدام الرابط | `TOKEN_EXPIRED`, `TOKEN_INVALID` |

Countdown `{time}` formatting: `m:ss` with Latin digits in both locales (e.g. `4:05`); over
60 minutes `h:mm:ss`.

---

## 11. QA acceptance checklist (for KL-006)

| # | Check |
| - | ----- |
| 1 | Every screen above renders in ar (RTL) and en (LTR), dark and light, text scale 1.0 and 2.0, without clipping or overflow at 360×640 dp |
| 2 | No hard-coded strings; every key above exists in both ARB files |
| 3 | Back arrows/chevrons/send flip in RTL; play/media/clock icons and the wordmark do not |
| 4 | Username availability shows all six states; stale responses never overwrite newer input |
| 5 | Forgot flow copy and navigation identical for registered and unregistered emails |
| 6 | Each §10 code produces the specified copy and presentation (mock server) |
| 7 | Logout clears secure storage even when offline; Splash keeps tokens on network errors |
| 8 | Revoking another session removes it; `NOT_FOUND` handled as already ended |
| 9 | All interactive targets ≥ 48 dp; focus order follows reading direction; screen reader reads labels in the active locale |
| 10 | Reduce motion: no slides/shimmer; transitions are fades or instant |
| 11 | Counts/dates/countdowns use Latin digits in Arabic |
| 12 | Phase empty states name the correct phase and contain no fake data |
