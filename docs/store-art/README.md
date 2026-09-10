# Store art

The images currently live on Creator Hub. They are designed key-art cards, not in-game
screenshots: the handbook's thumbnail briefs ([store-page.md](../store-page.md)) need a finished map,
so these hold the slot until the art pass.

| File | Size | Uploaded to |
| --- | --- | --- |
| `icon.png` | 512×512 | Place → Icon |
| `pass-vip.png` | 512×512 | Passes → VIP (on sale, R$399) |
| `pass-radio.png` | 512×512 | Passes → Radio (off sale until the perk is built) |
| `pass-emotes.png` | 512×512 | Passes → Emotes (off sale until the perk is built) |
| `product-coins.png` | 512×512 | Developer products → 2,500 coins |
| `product-key.png` | 512×512 | Developer products → Seasonal Key |
| `thumb-1-knife.jpg` | 1920×1080 | Thumbnails, both tabs — first on the Experience Detail Page |
| `thumb-2-evidence.jpg` | 1920×1080 | Thumbnails, both tabs |
| `thumb-3-roles.jpg` | 1920×1080 | Thumbnails, both tabs |
| `thumb-4-collect.jpg` | 1920×1080 | Thumbnails, both tabs |

The Home Page tab has all four active with personalization on, so Roblox picks the winner per
player. Wait at least 7 days between thumbnail tests.

Palette and fonts follow `Theme` and the Design Bible: knife `#f2a63b`, ground `#0a0c0f` →
`#1b2530`, wash `#d9443f`, Big Shoulders Display and IBM Plex Mono.

## Regenerating

Sources are in `src/`. The 512px images are plain SVG wrapped in HTML; the thumbnails load their
fonts from Google Fonts, so render them online.

```bash
cd docs/store-art/src
# 512×512 icon, passes and products
for f in icon pass-vip pass-radio pass-emotes product-coins product-key; do
  chromium --headless --disable-gpu --hide-scrollbars --window-size=512,512 \
    --screenshot="../$f.png" "file://$PWD/$f.html"
done
# 1920×1080 thumbnails (the time budget lets web fonts load)
for f in thumb-1-knife thumb-2-evidence thumb-3-roles thumb-4-collect; do
  chromium --headless --disable-gpu --hide-scrollbars --virtual-time-budget=8000 \
    --window-size=1920,1080 --screenshot="/tmp/$f.png" "file://$PWD/$f.html"
  convert "/tmp/$f.png" -alpha off -quality 90 "../$f.jpg"
done
```

Upload the JPEGs for thumbnails; they are a quarter the size of the PNGs.
