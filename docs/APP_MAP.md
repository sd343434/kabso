# Kabso Live — app map (D86)

What the mobile app contains, where each screen lives, and what it is
connected to. Update this table whenever a screen gains an API or a route
moves.

## Status key

| Status | Meaning |
| --- | --- |
| **API** | Uses a real endpoint in `docs/contracts/openapi.yaml`. |
| **Honest** | No endpoint yet: the screen says so ("coming soon" / unavailable) and shows no invented data. |
| **Demo** | Test builds only, with *Settings → Demo data* on: labelled test data, no server (`lib/features/debug/demo_data.dart`). Release builds never contain this path. |

## Bottom bar (`AppRoutes.shellBranches`)

| Tab | Route | Screen | Status without Demo data | With Demo data |
| --- | --- | --- | --- | --- |
| البث / Live | `/home` | `LiveScreen` (Following · Popular · New, categories) | **API** (`/live/config`, `/live/categories`, `/live/rooms`) | Demo hub: 8 test rooms (solo, PK 1v1, PK 2v2) |
| المنشورات / Posts | `/reels` | `FeedScreen` (Posts · Reels, Trending · Following, stories) | **Honest** (no posts/reels/stories API) | Test posts, reels and stories |
| + / Create | `/create` | `CreateScreen` | **Honest** | — |
| الرسائل / Messages | `/messages` | `MessagesTab` → `DmInboxScreen` (conversations · «طلبات المراسلة») | **API** (D155: `/dm/conversations`, `/dm/unread`; badge on the tab) | Designed conversation list → conversation (test builds only) |
| أنا / Me | `/profile` | `ProfileScreen` (posts, reels, saved grids) | **API** for `/me` and counts; grids **Honest** | Test account, counts and grids |

## Above the bar

| Route | Screen | Status | With Demo data |
| --- | --- | --- | --- |
| `/home/room/:roomId` | `LiveRoomScreen` | **API** (`/live/rooms/{id}`) | `demo-*` rooms open the designed live room (`LivePreviewScreen`: PK bar, gifts, viewers box, leaderboard, ranking list) |
| `/discover` | `DiscoverScreen` (from the search buttons) | **Honest** | Designed Discover |
| `/users/:username` | `PublicProfileScreen` | **API** (`/users/{username}`, follow) | Test profiles, local follow |
| `/messages/:username` | `ChatScreen` (text, pack emojis, pictures, voice notes, gifts; requests; 24-hour messages) | **API** (D155: `/dm/peers/{username}`, `/dm/conversations/{id}/messages`, `/dm/messages`, `/dm/gifts`) | Designed conversation (test builds only) |
| `/profile/edit` | `EditProfileScreen` | **API** read; saving waits for the contract | — |
| `/settings` | `SettingsScreen` (theme, language, sessions, levels, Demo data, logout) | **API** (sessions) | Demo data switch |
| `/levels`, `/levels/:category` | `LevelsScreen`, `LevelDetailScreen` | **API** (KL-058) | — (needs the server) |
| `/auth/*`, `/splash` | Splash, welcome, join, login, register, code, forgot password | **API** | "Try with demo data" on welcome and login |

## Developer routes (`/debug/*`, never in release)

`/debug/previews` lists every design preview (feed, live solo/PK, messages,
conversations, discover, profile, user, chat) and the component gallery.
They keep their state switchers for design review.

## Builds

| Build | Command (from `apps/mobile`) |
| --- | --- |
| Test APK that opens on Demo data | `flutter build apk --profile --split-per-abi --target-platform android-arm64 --dart-define=KABSO_DEMO=true` |
| Test APK against a server | add `--dart-define=API_BASE_URL=https://<api-host>` and leave Demo data off |
| Release | `flutter build apk --release` — Demo data, previews and fixtures are compiled out (`kDemoAvailable == false`) |

## Next to connect (needs contracts first)

Posts, reels and stories · comments and shares · messaging · live chat,
gifts, coins and PK · viewers and rankings (D84/D85) · Discover and search ·
Create (photo and video upload). Each one replaces its **Honest** state;
the Demo data path for it is then deleted.
