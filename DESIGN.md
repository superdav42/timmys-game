# Scrap Sprites: Workshop Rumble — Design Brief

## Product direction

A portrait mobile auto-battler about tiny forest mechanics who turn harmless workshop scraps into rambunctious rolling machines. Players make the decisions in the workshop, then watch their build fight by itself in a short, readable arena match.

The game uses the broad build/watch/reward loop common to vehicle-construction battlers. Its world, title, characters, parts, language, interface, silhouettes, colors, tuning, and progression are original. Do not introduce names, artwork, characters, layouts, audio, levels, or branded terminology from C.A.T.S. or another existing game.

## Core loop

1. Choose a chassis, wheel set (“button boots”), and tool.
2. Keep the wheel and tool power cost within the chassis capacity.
3. Start a Rumble and watch a 24-second autonomous duel.
4. Earn scrap and trophies; spend scrap to unlock alternative parts.
5. Rebuild to counter tougher workshop rivals.

## Identity

- **Player character:** Pip, a pink leaf-eared scrap sprite.
- **Rivals:** Moxie, Pogo, and Juniper.
- **Setting:** a warm reclaimed workshop and a moonlit greenhouse arena.
- **Tone:** handmade, cheerful, slightly chaotic; impacts feel playful rather than violent.
- **Visual language:** chunky rounded panels, dark green ink outlines, cream paper, mint, coral, and sunflower accents.
- **Rendering:** procedural vector shapes only in the MVP, ensuring every silhouette is original and crisp at mobile resolutions.

## Parts and counterplay

- **Chassis:** Moss Bug is balanced; Tin Kite is quick with a large power budget; Brick Beetle is slow and durable.
- **Button boots:** steady Button Boots, fast Comet Rollers, and armored Tumble Treads.
- **Tools:** Spark Fork lifts at close range, Buzz Bloom deals rapid melee damage, and Acorn Mortar trades fire rate for long range.
- Rival loadouts cycle from balanced to fast melee to armored range, gaining 7% health and damage each three-trophy level so progression continues indefinitely.

## UX principles

- The whole loadout and its main stats remain visible on one portrait screen.
- Every selectable card communicates ownership, price, and selection state.
- Cards show exact combat stats and flag incompatible power requirements before a purchase.
- Combat is intentionally hands-off; the arena explains that the build does the battling.
- Attacks raised on the same simulation step resolve together; evenly matched destruction and timer ties are draws rather than order-dependent wins.
- Health is communicated numerically as well as by color, and primary controls reserve bottom safe-area space.
- Results always pay some scrap so the player cannot get progression-locked.
- Session progress saves locally.

## MVP acceptance criteria

- Garage allows selection and purchase across three parts in each category.
- Invalid over-capacity configurations are blocked with useful feedback.
- Procedurally drawn machines visibly reflect selected chassis, wheels, tools, and pilot colors.
- Three autonomous opponents use distinct builds and scale with trophies.
- Battle resolves through health depletion or the 24-second timer.
- Win/loss/draw result screen supports rematch and rebuild flows.
- Headless Godot startup exits without parser or runtime errors.
