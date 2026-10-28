# «إفيهات» quip sounds (owner-supplied Kabso assets, 2026-10-28, D154)

Made for Kabso and supplied by the owner on 2026-10-28 (D154 items 5c and 5d), who confirmed both packs are
Kabso's own assets that may enter the repository:

- `room/` — the 8 free room sounds of `kabso_room_sounds/assets/sounds/room/` (clap, laugh, welcome, wow,
  ta-da, ya salam, bell, ooh). The package's reference Dart file and demo page stay outside git.
- `kabi/` — the 27 paid Kabi voice lines of `kabi_voice_pack/assets/sounds/kabi/` (Egyptian Arabic; ghazal
  01–10, funny 01–08, tease 01–09). Their texts are the owner's `lines.json` (tease_02 confirmed by the
  owner, D154 5f) and live on the server (`apps/api/src/modules/gifts/quips.ts`, `Gift.quip.text`). The
  package's `original/` folder, reference Dart file and demo page stay outside git.

**Processing (D154: «normalise their loudness»):** each file was loudness-normalised with ffmpeg's two-pass
`loudnorm` to I = −16 LUFS, TP = −1.5 dBTP, LRA = 11 (linear mode) and re-encoded as MPEG-1 Layer III, mono,
44.1 kHz, 96 kbps, metadata stripped. `room/tada.mp3` is too short and peaky for `loudnorm` to reach the
target, so it was raised by 5.5 dB under a −1.5 dBFS limiter instead (`volume=5.5dB,alimiter=limit=0.84`).
The originals are kept outside git (scratch). Measured after processing (integrated loudness of clips under
3 s is approximate):

| File | Length | Before (LUFS / dBTP) | After (LUFS / dBTP) | Use |
| ---- | ------ | -------------------- | ------------------- | --- |
| `room/bell.mp3` | 1.70 s | -12.93 / -0.89 | -16.43 / -4.43 | free (one per viewer per live; soundboard) |
| `room/clap.mp3` | 2.04 s | -7.20 / -0.01 | -16.44 / -8.99 | free (one per viewer per live; soundboard) |
| `room/laugh.mp3` | 1.12 s | -11.51 / -0.89 | -16.44 / -5.86 | free (one per viewer per live; soundboard) |
| `room/sad.mp3` | 2.22 s | -15.50 / -0.90 | -16.54 / -1.94 | free (one per viewer per live; soundboard) |
| `room/tada.mp3` | 2.30 s | -20.52 / -0.67 | -15.90 / -0.83 | free (one per viewer per live; soundboard) |
| `room/welcome.mp3` | 2.04 s | -12.79 / -0.77 | -16.47 / -4.46 | free (one per viewer per live; soundboard) |
| `room/wow.mp3` | 0.84 s | -13.92 / -0.87 | -16.42 / -3.37 | free (one per viewer per live; soundboard) |
| `room/ya_salam.mp3` | 1.75 s | -13.25 / -0.87 | -16.45 / -4.13 | free (one per viewer per live; soundboard) |
| `kabi/funny_01.mp3` | 7.65 s | -16.50 / -0.88 | -16.80 / -1.83 | 199 coins — «يا جماعة حد يلمّ الجمال ده من على الأرض!» |
| `kabi/funny_02.mp3` | 10.81 s | -16.29 / -0.83 | -16.64 / -1.71 | 199 coins — «ادخلوا بالراحة، الكاريزما هنا عليها أحمال زيادة!» |
| `kabi/funny_03.mp3` | 12.30 s | -17.66 / -0.43 | -16.21 / -1.67 | 199 coins — «يا نجم، النور عندك عالي لدرجة إننا هنطلب فاتورة كهربا!» |
| `kabi/funny_04.mp3` | 10.24 s | -16.98 / -0.85 | -17.22 / -1.51 | 199 coins — «صاحبنا دخل الشات، يا ريت حد يشرحله قواعد الجاذبية!» |
| `kabi/funny_05.mp3` | 9.25 s | -16.96 / -0.78 | -17.23 / -1.68 | 199 coins — «إيه يا عم، داخل تسلّم ولا تستلم قلوب؟» |
| `kabi/funny_06.mp3` | 12.38 s | -17.62 / -0.85 | -17.14 / -1.70 | 199 coins — «تم رصد كمية ثقة غير مرخصة في الغرفة!» |
| `kabi/funny_07.mp3` | 10.71 s | -17.14 / -0.86 | -17.03 / -1.79 | 199 coins — «الرجاء عدم الاقتراب، الشخصية تحت الاختبار!» |
| `kabi/funny_08.mp3` | 11.18 s | -17.37 / -0.80 | -17.46 / -1.63 | 199 coins — «اللي داخل يتغزل ياخد رقم، الدور طويل!» |
| `kabi/ghazal_01.mp3` | 4.36 s | -17.46 / -0.84 | -17.41 / -1.74 | 99 coins — «إيه الجمال ده! تحفة بجد!» |
| `kabi/ghazal_02.mp3` | 4.91 s | -17.43 / -0.86 | -17.55 / -1.82 | 99 coins — «يا فتّان يا جامد!» |
| `kabi/ghazal_03.mp3` | 5.93 s | -19.24 / -0.82 | -18.51 / -1.79 | 99 coins — «ده إنت حكاية!» |
| `kabi/ghazal_04.mp3` | 6.48 s | -16.18 / -0.84 | -16.86 / -1.55 | 99 coins — «يا لهوي يا ناس!» |
| `kabi/ghazal_05.mp3` | 4.49 s | -16.37 / -0.82 | -16.71 / -1.65 | 99 coins — «مين القمر ده؟» |
| `kabi/ghazal_06.mp3` | 8.93 s | -15.93 / -0.85 | -16.68 / -1.77 | 99 coins — «يا خراب بيت الحلاوة!» |
| `kabi/ghazal_07.mp3` | 8.62 s | -16.36 / -0.82 | -16.63 / -1.66 | 99 coins — «الجمال ده مش قانوني!» |
| `kabi/ghazal_08.mp3` | 7.37 s | -16.54 / -0.83 | -16.51 / -1.69 | 99 coins — «خد قلبي وسيبلي عقلي!» |
| `kabi/ghazal_09.mp3` | 6.92 s | -15.76 / -0.79 | -16.45 / -1.70 | 99 coins — «يا جامد يا ابن اللذينة!» |
| `kabi/ghazal_10.mp3` | 9.95 s | -17.02 / -0.83 | -17.06 / -1.71 | 99 coins — «ده إنت محتاج حراسة من المعجبين!» |
| `kabi/tease_01.mp3` | 7.21 s | -20.93 / -0.18 | -17.26 / -0.77 | 299 coins — «إنت مش غبي، إنت بس بتدي الذكاء فرصة يثبت نفسه بعيد عنك!» |
| `kabi/tease_02.mp3` | 5.72 s | -21.43 / -1.63 | -17.20 / -1.49 | 299 coins — «إنت لو التركيز فلوس، كنت استلفت مننا.» |
| `kabi/tease_03.mp3` | 7.81 s | -22.28 / -2.23 | -16.94 / -0.94 | 299 coins — «يا ابني إنت محتاج تحديث نظام، واضح إن النسخة دي فيها مشاكل!» |
| `kabi/tease_04.mp3` | 5.20 s | -21.85 / -1.53 | -17.17 / -1.47 | 299 coins — «مخك مش فاضي، ده لسه تحت التشطيب!» |
| `kabi/tease_05.mp3` | 6.71 s | -20.43 / -0.22 | -17.14 / -1.72 | 299 coins — «يا عم إنت لو كنت إجابة، كنت هتبقى «حاول مرة أخرى»!» |
| `kabi/tease_06.mp3` | 5.56 s | -19.88 / -0.32 | -16.86 / -1.09 | 299 coins — «إنت مش بتقول أي كلام، إنت بتعمل محتوى تجريبي!» |
| `kabi/tease_07.mp3` | 6.50 s | -20.31 / -0.10 | -17.05 / -1.60 | 299 coins — «ربنا مديك قبول، بس واضح إنه مشغول دلوقتي!» |
| `kabi/tease_08.mp3` | 5.17 s | -20.60 / -0.57 | -16.84 / -1.23 | 299 coins — «إنت مش غامض، إنت بس محدش مهتم يسأل!» |
| `kabi/tease_09.mp3` | 7.08 s | -20.02 / 0.26 | -16.83 / -1.40 | 299 coins — «طب جرّب تتكلم من غير ما تفكر، يمكن نوصل لنفس النتيجة بس أسرع!» |

Played by `LiveQuips` (`lib/features/live/application/live_quips.dart`) with `audioplayers` on every phone
in the live, one at a time, while the app's Sound effects setting is on and quips are not muted.

SHA-256:

```
76c3fd4d0c4a0ca4ff993d7046948f04ef736a6726457eab14589cb8a7ef42ca  room/bell.mp3
970f89d2dbf50b49250bd60f00c42b6ea6eba8cf3cf476b737b64d828a811804  room/clap.mp3
10b1fd12e4a135c763746ba75c56338a32f2cee8340558318d01bd98fb28e060  room/laugh.mp3
30f2a45a067e8b4233c358418956d2c1e9607037a37d7d71cc5ee3d1a72543d3  room/sad.mp3
786de54396581a71eeced216f0c22322c1591b9387485b8f51fdf0966e2e626c  room/tada.mp3
b2168cba6433507f16e157376e8e305d9a22c24c0ccbb20ca419771e7431e3c7  room/welcome.mp3
28100f89668c49abfad3454acfb11ce6bf72dd9971b6630581d5d5bac1eddabf  room/wow.mp3
4b0d1a733f9f476f71ebf8c7641249eebb0bd44c9fc4f2c081206419355f7ae1  room/ya_salam.mp3
6297a354f7bef5448197f7d3ba1c4afe9c8b7e393d120cf4c5310af8d97b41b0  kabi/funny_01.mp3
c157c99b73094078ca8c3d0bedac1681391843bbab6f85b657b232c44a3cfef1  kabi/funny_02.mp3
5da1330d7b644bd832467eb7bf0013039d817ac4274365e3fda96fa1ed36c568  kabi/funny_03.mp3
cf07841b2621ae913b54ff08ec7e7a7ad4ec7d004cad00e4a0e70e5e1586fd12  kabi/funny_04.mp3
0ffbb0d50365bc540b649580db3d0911b2cb840b7357e36ed642bfa53a264cf9  kabi/funny_05.mp3
f16bbddd6a4a40298a7eaa7b591728c29dc2df684d77b9e200f155729c43eb4a  kabi/funny_06.mp3
9b4d6ab42c3401e4ed45d28533e362f49b2348eb7f6a226f566555a007c661d3  kabi/funny_07.mp3
5a411deb3775f945c32a4b56fff9be7d26455d1289fd72d0c90e4a6a4794d8af  kabi/funny_08.mp3
93080e4d01832d3cd7d6fccb23664ab13957584b892c02b83c2bfd3b21e10013  kabi/ghazal_01.mp3
c783dc02b10fec474c48785bbccdf2a932bc261700720562a16a5a10fea774b8  kabi/ghazal_02.mp3
f3c9ba78aa9568704432761efc249f13b547ec9700d8bb5291318b861cf22ec0  kabi/ghazal_03.mp3
258c5b80407df8d0b93fa67689676b67820cfe80545a03ef1a73d485a4d2ef86  kabi/ghazal_04.mp3
b4846d7c0195dd8997dec98ec37cc0adade6eaff97cd811b2e28528739dffcac  kabi/ghazal_05.mp3
0dbfa4ef1bb623fd4430aee22a03850d099ac7d424f49107358d92ea391f393c  kabi/ghazal_06.mp3
eaaa766afc485cc69d2a54c4f9864e3e222c6b9beae379ebfb66b8c5c0012fc3  kabi/ghazal_07.mp3
1bf679ac1ecd469a04e20c47b0b58c7d569434f900d41bd30d0b9f3c60229229  kabi/ghazal_08.mp3
81218c7453ea64e2c9563939adf240a136c4fbc1595b4bbce987b11f76e1233a  kabi/ghazal_09.mp3
9b1d83738c025c4dc2ca59cb1f15e64ad528cb83e9f19b4203bae872b58e1549  kabi/ghazal_10.mp3
2ca966e5525ea09e3a490c6b58b4382ee1a7b87a1f95c65e3d9e3bd905b4d1c6  kabi/tease_01.mp3
f2168378b9af860571cca8f7908be35a73655ad69fbf7ebd7e9f38a483bcec32  kabi/tease_02.mp3
8d1ff7f670785353a3367c9bc614389264d0c04076521091fc0052b3c2882f49  kabi/tease_03.mp3
9d009f778f8b70a869920df689a82fb4cbd98139c5c678647118f1fd58babb6c  kabi/tease_04.mp3
1a75c531102d3901dd4d675816c41be7d7cd729ca3b7404315484e195b3451b1  kabi/tease_05.mp3
2deab09956a3859fd728945b7a794741cc58a22d9e3efb1c5b84a6b348a4cf87  kabi/tease_06.mp3
9c62ca4b964576b3672eed45749e4bc74849f3afc1ce2a05df62a62edec677f5  kabi/tease_07.mp3
d177a73d7bfaa3d5848c0cad9fe84c9578a3551b2268f20e92bb584b96fb1e7f  kabi/tease_08.mp3
ce19e904aacbe80fa2b2bd5a8d2d03cac4b8fe0ee54d140a08e08ad66d4771c3  kabi/tease_09.mp3
```
