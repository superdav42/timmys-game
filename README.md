# Scrap Sprites: Workshop Rumble

An original Godot 4.7 portrait mobile vehicle-builder auto-battler. Equip Pip's rolling workshop creation, stay within its power budget, and watch it battle rival scrap sprites automatically.

## Play online

<https://superdav42.github.io/timmys-game/>

The published build is a static browser game with no accounts, advertising, analytics, forms, or third-party data services. Progress is stored only in the player's browser.

## Playable prototype

- Garage with three original chassis, button-boot, and tool families.
- Purchases, local saving, scrap rewards, trophies, and opponent progression.
- Autonomous 1v1 combat with melee, lifting, and ranged behaviors.
- Fair simultaneous-hit resolution, explicit draws, numeric health, and rivals constrained by the same part stats and power limits as the player.
- A visible 20% Pip drive-speed bonus keeps the player's machine moving quickly without altering rival equipment stats.
- Procedural vector art; no third-party game assets or copied characters.

## Requirements

- Godot 4.7.x

## Run locally

Run: godot --path .

Headless smoke check: godot --headless --path . --quit-after 1

Playable-flow smoke check: godot --headless --path . --script res://tests/smoke_game.gd

Web export: godot --headless --path . --export-release "Web" site/index.html

## Project layout

- project.godot: mobile-oriented project settings.
- scenes/main.tscn: main game scene.
- scripts/main.gd: garage, progression, battle orchestration, results, and UI.
- scripts/battle_bot.gd: autonomous combat behavior and procedural vehicle art.
- tests/smoke_game.gd: garage, battle, results, and return-flow smoke coverage.
- DESIGN.md: original visual identity, mechanics, and MVP constraints.
- export_presets.cfg: reproducible single-threaded web export.
- site/: generated, reviewable GitHub Pages artifact containing only the game.
- .github/workflows/pages.yml: pinned official GitHub Pages deployment workflow.
- docs/mobile-notes.md: next steps for Android/iOS export setup.
