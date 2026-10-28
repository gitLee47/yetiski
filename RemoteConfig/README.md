# YetiSki remote config

`config.json` here is fetched by the live app at launch from:
`https://raw.githubusercontent.com/gitLee47/yetiski/main/RemoteConfig/config.json`

Editing it and pushing to `main` is a live content update — no new App Store
build or review needed. A malformed file, a schema version the app doesn't
recognize, or no network at all all leave the app on its hardcoded defaults;
nothing ever breaks.

## Schema

```json
{
  "schemaVersion": 1,
  "theme": {
    "accentColorHex": "#FF7A1A",
    "banner": { "isVisible": true, "text": "🎃 Halloween Event: a Spooky Yeti is loose!" }
  },
  "weaponOverrides": [
    { "id": "shotgun", "coinCost": 150 },
    { "id": "pulseBlade", "coinCost": 2500, "unlockLevel": 40 }
  ],
  "assetOverrides": [
    { "spriteName": "sprite_yeti_1", "url": "https://raw.githubusercontent.com/gitLee47/yetiski/main/RemoteConfig/assets/sprite_yeti_1_halloween.png" }
  ]
}
```

- `theme`, `weaponOverrides`, `assetOverrides` are all independently optional
  — set any of them to `null` or omit to leave that part untouched.
- `weaponOverrides[].id` must match a `WeaponKind` raw value: `machineGun`,
  `shotgun`, `rocketLauncher`, `iceCannon`, `feralClaws`, `opticBlast`,
  `wyrmsBreath`, `acidSprayer`, `gravityPulse`, `pulseBlade`.
- `weaponOverrides[].unlockLevel` can be a number (override), omitted (leave
  the hardcoded default alone), or explicit `null` (remove the free-unlock
  path entirely — coin-only).
- `assetOverrides[].spriteName` must exactly match an existing sprite name
  (e.g. `sprite_yeti_1`/`_2`/`_3`, the yeti's 3 chase-animation frames — push
  all 3 together so the animation doesn't flicker between old/new art).
  Put the actual PNG in `assets/` and reference its raw.githubusercontent.com
  URL.
- Real-money IAP pricing (`CoinBundle`) is **not** controlled here — that's
  App Store Connect's job.

Validation: each downloaded asset must be a real decodable image under ~3MB
with both dimensions in `4...1024`px, or it's silently rejected and the
bundled default stays in use.
