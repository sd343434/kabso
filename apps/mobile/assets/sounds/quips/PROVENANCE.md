# «إفيهات» quip sounds (owner-supplied Kabso assets, 2026-10-28, D154; 2026-11-09, D349)

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

## D349 — the Gulf «خليجي» and Jordanian «أردني» lines (owner-supplied 2026-11-09)

Supplied by the owner on 2026-11-09 as two folders, «افيهات خليجي» (14 files) and «افيهات اردنية» (4 files), made by
him with **ElevenLabs** text-to-speech: the Gulf lines with the voice «Talya - Human-like Arabic AI Bot», the Jordanian
ones with «Abd Ulrahman» (both ElevenLabs v4, as the source file names say). **Commercial use:** the owner stated on
2026-11-09 that he generated them on a **paid** ElevenLabs plan (commercial use included); recorded in PP-83. The
texts are the owner's own ElevenLabs history (direction tags such as `[chuckles]` removed), matched to the files by
generation order and clip length — the owner confirms by ear (PP-83). They live on the server
(`apps/api/src/modules/gifts/quips.ts`); the source files stay outside git (scratch).

D349 also moves the 27 `kabi/` lines above (prices there are D154's) to the sub-category «مصري» at **100 000 coins**
each (owner 2026-11-09); their files are unchanged.

**Processing:** the same as the D154 pack — ffmpeg two-pass `loudnorm` to I = −16 LUFS, TP = −1.5 dBTP, LRA = 11
(linear mode), re-encoded as MPEG-1 Layer III, mono, 44.1 kHz, 96 kbps, metadata stripped; no trimming (the D154
pipeline trimmed nothing). The sources were 128 kbps mono 44.1 kHz. Numbered `gulf_01…14` / `jordan_01…04` in the
order of the timestamps in their ElevenLabs file names (2026-11-05, given below). Measured after processing:

| File | Length | Made (2026-11-05) | Before (LUFS / dBTP) | After (LUFS / dBTP) | Use |
| ---- | ------ | ----------------- | -------------------- | ------------------- | --- |
| `gulf/gulf_01.mp3` | 6.71 s | 07:39:42 | -19.00 / -3.63 | -16.55 / -1.80 | 100 000 coins — «يا زينك بس، حتى الحظ إذا شافك قال: أنا مالي شغل!» |
| `gulf/gulf_02.mp3` | 5.36 s | 07:43:10 | -19.59 / -4.06 | -16.09 / -1.73 | 100 000 coins — «وش هالثقة؟ داخل علينا كأن التطبيق باسمك!» |
| `gulf/gulf_03.mp3` | 5.09 s | 07:44:05 | -19.46 / -4.33 | -16.49 / -1.75 | 100 000 coins — «هدي اللعب يا وحش، ترى القلوب مو كلها تتحمل! ❤️» |
| `gulf/gulf_04.mp3` | 5.36 s | 07:46:40 | -19.56 / -3.54 | -16.18 / -1.73 | 100 000 coins — «يا جماعة الخير، عطوه هدية يمكن يسكت شوي!» |
| `gulf/gulf_05.mp3` | 5.51 s | 07:47:16 | -20.12 / -4.17 | -16.31 / -1.71 | 100 000 coins — «لا تسوي نفسك مشغول، شفناك متصل من الفجر!» |
| `gulf/gulf_06.mp3` | 4.62 s | 07:47:54 | -18.78 / -4.14 | -16.42 / -1.93 | 100 000 coins — «يا بعد حيي، حضورك لحاله يسوى مليون كوين! 💎» |
| `gulf/gulf_07.mp3` | 4.00 s | 07:48:30 | -21.18 / -5.53 | -16.18 / -1.85 | 100 000 coins — «تكفى لا تطلع، توّنا بدينا نستانس! 🥹» |
| `gulf/gulf_08.mp3` | 5.36 s | 07:49:01 | -19.69 / -3.30 | -16.27 / -1.64 | 100 000 coins — «وش السالفة؟ داخل دخول الملوك وطالع بدون سلام؟» |
| `gulf/gulf_09.mp3` | 6.30 s | 07:49:35 | -20.59 / -5.35 | -16.55 / -1.97 | 100 000 coins — «يا ساتر، منو عطاه المايك؟ شكله ما راح يسكته أحد! 🎤» |
| `gulf/gulf_10.mp3` | 5.51 s | 07:55:02 | -19.30 / -3.69 | -16.32 / -1.80 | 100 000 coins — «وش هالحلا؟ تكفى خف علينا، قلوبنا مو قد هالجمال!» |
| `gulf/gulf_11.mp3` | 5.90 s | 07:55:35 | -20.46 / -4.42 | -16.87 / -1.78 | 100 000 coins — «تدري إنك مشكلة؟ كل ما أشوفك أنسى وش كنت بقول!» |
| `gulf/gulf_12.mp3` | 5.28 s | 07:56:16 | -19.06 / -4.46 | -16.26 / -1.90 | 100 000 coins — «يا زين ضحكتك، أحسها تسوي إعادة تشغيل لقلبي!» |
| `gulf/gulf_13.mp3` | 6.30 s | 07:56:43 | -19.51 / -4.06 | -15.80 / -1.78 | 100 000 coins — «أنت وش تستخدم؟ عسل ولا سحر؟ لأنك مسوي فيني عمايل!» |
| `gulf/gulf_14.mp3` | 7.34 s | 07:57:36 | -19.65 / -3.56 | -16.56 / -1.87 | 100 000 coins — «تدري وش ناقص الدنيا؟ نسخة ثانية منك، عشان إذا اشتقت لك أروح لها! 😂» |
| `jordan/jordan_01.mp3` | 5.02 s | 08:00:43 | -20.36 / -1.45 | -16.94 / -1.69 | 100 000 coins — «ولك شو هالحلا؟ إنت مش بني آدم، إنت مخالفِة جمال!» |
| `jordan/jordan_02.mp3` | 6.87 s | 08:01:29 | -18.98 / -0.87 | -16.58 / -1.77 | 100 000 coins — «يا زلمة قلبي مش واتساب، بس إنت كل ما تطلّ عليّ... بعملك اتصال!» |
| `jordan/jordan_03.mp3` | 5.17 s | 08:02:17 | -20.30 / -1.27 | -15.81 / -1.67 | 100 000 coins — «يا ريتني شاحن تلفون، عشان أضل قريب منك وما تِفصل عني!» |
| `jordan/jordan_04.mp3` | 7.34 s | 08:03:17 | -27.08 / -6.45 | -17.33 / -1.55 | 100 000 coins — «ولك إنت حلو بطريقة بتخليني أستحي أحكي معك، وبنفس الوقت نفسي ما أسكُت!» |

Source files (SHA-256 of the owner's originals, not in git):

```
dc9c34a341611eb177d6a8136f0347989b547068c91528a8ae1c2b67bbe8848d  ElevenLabs_2026-11-05T07_39_42_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_v4.mp3  → gulf/gulf_01.mp3
bd06a9875d71c267634c187c845b3dd5560ea9d690031cb2be4a5cb2e24bae59  ElevenLabs_2026-11-05T07_43_10_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_02.mp3
7b13f000257450b62fdcb64d0abe343e5ced21f661c6a7a855d7be86af0f772f  ElevenLabs_2026-11-05T07_44_05_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_03.mp3
5680fafb92afd1a4d8e9e7ab54895269e1cfff84c5be68eae608f5f9c094cd15  ElevenLabs_2026-11-05T07_46_40_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_04.mp3
40915a3ec8ab5a12a8f024a91455a6f9a7ea5b46e29561aaaeff3e64af99f59e  ElevenLabs_2026-11-05T07_47_16_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_05.mp3
77c8a8a3dba0d253d33041865a7ee8bb19623cc008f213ff4fb785768ebd4cb1  ElevenLabs_2026-11-05T07_47_54_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_06.mp3
18bc7b1bb2da43b82a6d8f1c216d6f0bcdfc1a348c14a7e5760462750a364aa7  ElevenLabs_2026-11-05T07_48_30_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_07.mp3
c4243cfd268c14149868d592c7ccc3c912423fee17bd7d9e471b11d5c1565b9e  ElevenLabs_2026-11-05T07_49_01_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_08.mp3
e1ac077e767fe107c62292dbe390ec496111d6f10f811fa11f9563eb765ebfd1  ElevenLabs_2026-11-05T07_49_35_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_09.mp3
5ea0352d30bbeae816feed0f4a93e1d83924ff040e5d24154301a8f6334de3a1  ElevenLabs_2026-11-05T07_55_02_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_10.mp3
e34e5236ebe942d65995fec7a5f0a0b852599b8db1b03783da82adc4a83e16b9  ElevenLabs_2026-11-05T07_55_35_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_11.mp3
6cbec7a20b7950cf51496d7f3d138d6bb38c13eedb135921063f4b72825f0239  ElevenLabs_2026-11-05T07_56_16_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_12.mp3
d4dbde5e453f42e265fda4d332c04eabb06861bf09200acd8c4579a2f42cc4e3  ElevenLabs_2026-11-05T07_56_43_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_13.mp3
c780c11bebe33282874b8e5ab88434dd9d706e659e23778b892e8f6c36042607  ElevenLabs_2026-11-05T07_57_36_Talya - Human-like Arabic AI Bot_pvc_s50_sim75_cs6_v4.mp3  → gulf/gulf_14.mp3
de06ef24f4bf1920c1f12de1bbe7547b9ee193065cde1e7e31fe6ad6e6614cc1  ElevenLabs_2026-11-05T08_00_43_Abd Ulrahman_pvc_s50_sim75_v4.mp3  → jordan/jordan_01.mp3
52241ba06b83792d016834c65bac109468b5f354853d5323b79d34b57d3a590b  ElevenLabs_2026-11-05T08_01_29_Abd Ulrahman_pvc_s50_sim75_v4.mp3  → jordan/jordan_02.mp3
7b9ef4456c5c631ca788cee416fcbe25e1ad7a649a8839a94544bcf04b4e3b0b  ElevenLabs_2026-11-05T08_02_17_Abd Ulrahman_pvc_s50_sim75_v4.mp3  → jordan/jordan_03.mp3
98341c41197f0b5c06e325aca65cd18030f61e9fb0c4eb281262c7044a622080  ElevenLabs_2026-11-05T08_03_17_Abd Ulrahman_pvc_s50_sim75_v4.mp3  → jordan/jordan_04.mp3
```

SHA-256 of the bundled files:

```
43d96c800a905a15f768620a1f721b7e1c73765cf47e0f0f0dd2afa381d756d7  gulf/gulf_01.mp3
dcbe6a1d5579d57777ecf06f55a9f7e3b2afe01cb1553821da8d3d296cb70b5e  gulf/gulf_02.mp3
cc00451617c03fed14a192c3a2d6632e88e35cd71c2f6fe425ebe5a5ae7f150d  gulf/gulf_03.mp3
87e3ed2f8801f68efc30fafcb242641ebc5cf8ffb79cb40525822acc3f2927a2  gulf/gulf_04.mp3
b4065725ec53993599951131c86232df0015fe0952e3aef800c4078efbc78145  gulf/gulf_05.mp3
c0db30b23c00207b835537376014796891bb80f69b4a66dc3c1d89ef9ce2f1d5  gulf/gulf_06.mp3
dbeccfe7a9c40fc12ac7be05dfbc659b596d1b7182af196c3b4d938b47084314  gulf/gulf_07.mp3
a811b05252adf2437ee68467d7c028c93c96fc432965eaa7e8e3548a72fc4eed  gulf/gulf_08.mp3
3fb79536c80e4ca30f2409db544824e576e5e9da31e82ecbe2dd99b67c3f47e4  gulf/gulf_09.mp3
f51c75caa5c838d5db3f6cf3c61ec35fafb5810d5a6e7d4d545b1999a2fb0471  gulf/gulf_10.mp3
f24bcfeef0f957ff1f0466e2b048d60e2298dfebe6830702b4d51a2a6e5dc1d6  gulf/gulf_11.mp3
88782172706362c908476f077435a13aaaf926fadfcd7d28f57a26a0559ee710  gulf/gulf_12.mp3
3363664f0853203bb6958e2ad376225b12072758520e1bb07d927cbaedd9d42b  gulf/gulf_13.mp3
29a836c0050e6f407b4a295f9c539032fe344e4dc908056874bf0dc2e5b159b4  gulf/gulf_14.mp3
aa3940900a2a1937d278d73760f3e704ff9bdc2c81b8955905e5065e32cf74b2  jordan/jordan_01.mp3
f5a892504668782ad82cd90c9544fd74e63110ffeadd22048d4613eae83d6bc6  jordan/jordan_02.mp3
a272054e3633309781406b58e095eb7279a9c86581e8f875314e8f6528fb3893  jordan/jordan_03.mp3
d0b6eb5268aae1c5221a5ed88d7760553d73d5a3673ae45ffcbdc133d0c4f6f0  jordan/jordan_04.mp3
```
