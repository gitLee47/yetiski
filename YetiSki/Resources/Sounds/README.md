# Sound assets

Drop these files here to enable audio (see `Audio/SoundManager.swift`):

- `crash.*` — stone/hole/tree hit
- `yeti_roar.*` — yeti ambush starts
- `game_over.*` — run ends
- `level_up.*` — difficulty level advances
- `jump.*` — skier launches off a ramp
- `snowflake.*` — snowflake collectible grabbed
- `powerup.*` — shield/speed boost/yeti repellent/extra life grabbed
- `music_loop.*` — looping background music

Until these exist, `SoundManager` no-ops safely — the game runs silently.
