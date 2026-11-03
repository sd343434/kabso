# VIP art test fixtures (D252b)

Owner-supplied VIP 1 still PNGs, used ONLY by the temporary screenshot harness and widget tests —
they are NOT bundled into the app (pubspec has no `assets/vip/`). In production every VIP tier's
badge and perk art is a hosted URL uploaded through the admin panel (the gifts `animationUrl`
pattern, D126), so the app binary stays light (the 13 MB entry-effect SVGA is never shipped).

| file | size | role |
| ---- | ---- | ---- |
| vip1_badge.png | 500×500 | tier badge (green peacock crest) |
| vip1_frame.png | 500×500 | avatar frame perk |
| vip1_card.png | 720×1280 | profile-card frame perk |
| vip1_entrance.png | 660×150 | entry bar perk |
| vip1_bubble.png | 990×720 | message-bubble frame perk |
| vip1_entry_effect.png | 563×1000 | full-screen entry effect perk (still only) |
