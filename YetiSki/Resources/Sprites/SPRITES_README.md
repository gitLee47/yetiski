# Sprite assets

Pixel-art sprites sourced from Kenney's **Tiny Ski** asset pack:
https://kenney.nl/assets/tiny-ski

License: CC0 1.0 (public domain) — free for personal, educational, and
commercial use, no attribution required. (Crediting Kenney is appreciated
but optional; see the pack's own `License.txt` if it's ever re-downloaded.)

Loaded via `SpriteTextureLoader` (`YetiSki/Game/SpriteTextureLoader.swift`),
which sets `filteringMode = .nearest` so the pixel art stays crisp instead of
blurring when scaled up from its native 16×16 size.

## Sourced directly from Kenney's tiles

- `sprite_skier_1.png` / `sprite_skier_2.png` — 2-frame skier pole-push
  animation (used by `SkierNode`, tinted per cosmetic skin)
- `sprite_tree.png` — pine tree obstacle (`ObstacleNode`)
- `sprite_rock.png` — stone obstacle (`ObstacleNode`)
- `sprite_yeti_1/2/3.png` — 3-frame yeti idle/chase animation (`YetiNode`)
- `sprite_rival_skier_1.png` / `sprite_rival_skier_2.png` — the pack's
  alt-color skier (blue helmet/pink jacket), reused as the drifting rival
  hazard (`SnowboarderNode`) — the pack has no snowboard-stance art, so a
  distinctly-colored rival skier stands in as "a reckless skier crossing
  your line" instead.

## Hand-authored (matching the pack's palette + dark outline-halo style)

No ready-made tile exists in the pack for a pit, an icy patch, a jump ramp,
an icicle, or any of the powerup badges, so these were drawn from scratch —
sampling the pack's own outline color (`#3F262E`) and mirroring its flat-fill
silhouette-plus-halo look — via a small script (see
`/scratchpad/pixel_art/gen.py` from the session that made them, not checked
into the repo):

- `sprite_hole.png` — pit obstacle (`ObstacleNode`)
- `sprite_ice_patch.png` — ice patch obstacle (`ObstacleNode`)
- `sprite_ramp.png` — wooden kicker ramp, chevron baked in (`RampNode`)
- `sprite_icicle.png` — falling icicle shard (`IcicleNode`)
- `sprite_pickup_shield.png` / `sprite_pickup_speed.png` /
  `sprite_pickup_repellent.png` / `sprite_pickup_life.png` /
  `sprite_pickup_snowflake.png` — the five grab-able pickup badges
  (`PickupNode`). The snowflake is styled as a gold coin with sparkle glints
  (rather than the icy blue of the other four) plus a slow spin-and-pulse
  animation in `PickupNode.init` — it's common "currency," so it's meant to
  read as enticing to grab, not as another icy hazard like `sprite_ice_patch`.

## Locker (SwiftUI) previews

- `sprite_skin_preview_<skin>.png` (one per `SkierSkin` case) — `sprite_skier_1`
  pre-tinted offline with the exact same blend `SkierNode.applySkin(_:)` applies
  at runtime (`jacketColor` at a 0.55 blend factor, 0 for classic), so the
  Locker's SwiftUI card matches the in-game sprite exactly. Loaded directly as
  `UIImage`s by `SkinShopView` (see its `UIImage.loose(named:)`), since SwiftUI
  `Image(_:)` by asset-catalog name doesn't apply here — these are loose files.
