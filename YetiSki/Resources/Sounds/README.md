# Sound assets

Drop these files here to enable audio (see `Audio/SoundManager.swift`):

- `swoosh.caf` / `.wav` / `.mp3` / `.m4a` — continuous skiing sound
- `crash.*` — stone/hole/tree hit
- `yeti_roar.*` — yeti ambush starts
- `game_over.*` — run ends
- `level_up.*` — difficulty level advances
- `music_loop.*` — looping background music

Until these exist, `SoundManager` no-ops safely — the game runs silently.
