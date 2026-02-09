# Eldritch Hollow Beta Readiness Checklist

Legend: ~~strikethrough~~ = implemented in code · [ ] not implemented yet · (playtest) requires in-editor verification

## Project boot + setup
- [ ] Open the project in Godot 4.x and confirm it loads without errors. (playtest)
- ~~Confirm `scenes/Main.tscn` is the main scene (Project Settings → Application → Run).~~
- [ ] Run the scene and verify the window opens at the expected resolution. (playtest)

## Core simulation wiring
- ~~Ensure `MapStack` is present under `World` and registers in the `map_stack` group.~~
- ~~Verify `MapStack` initializes all maps to the same dimensions.~~
- ~~Confirm `World` uses `MapStack.tile_size_world` when drawing tiles.~~
- ~~Verify `DoomView` uses `MapStack` for raycasts and view distance.~~

## Player loop
- ~~Confirm movement inputs (WASD/arrow keys) are mapped and responsive.~~ (playtest)
- ~~Ensure player writes intent to `VEL_VEC` (velocity map) each frame.~~
- ~~Validate player movement reads from `VEL_VEC` (map-driven motion).~~
- ~~Confirm occupancy (`OCC_ID/OCC_TYPE`) updates as the player moves.~~

## Monster loop
- ~~Confirm monsters write velocity intent based on temperature/wander rules.~~
- ~~Verify monster movement reads from `VEL_VEC` (map-driven motion).~~
- ~~Ensure monsters update occupancy and clear velocity when tamed/removed.~~

## Field deposition + decay
- ~~Validate noise and scent are deposited on movement.~~ (playtest)
- ~~Verify heat/noise/scent/blood decay over time in `MapStack.step_simulation`.~~
- ~~Check temperature drift toward ambient values is active.~~

## Interaction + survival scaffolding
- ~~Confirm `interact` and `attack` actions fire on nearby `Area2D` targets.~~ (playtest)
- ~~Verify taming and harvesting callbacks update inventory/party.~~ (playtest)
- ~~Ensure HUD labels update (hunger/inventory/party).~~

## Visual verification
- ~~Confirm tile colors render and react to heat shading.~~ (playtest)
- ~~Verify Doom-style view renders columns and responds to turning/movement.~~ (playtest)

## Beta session loop (end-to-end)
- ~~Spawn in a safe edge room.~~ (spawn cell carved at edge; playtest still needed)
- ~~Explore corridors/rooms and reach monster encounters.~~ (corridor + rooms carved; monsters placed; playtest still needed)
- ~~Hunt/battle monsters to obtain survival drops.~~ (drops configured; playtest still needed)
- ~~Use drops to stabilize (eat, warm up, craft capture gear).~~ (eat + warm spot + crafting; playtest still needed)
- ~~Push deeper for better drops and targets.~~ (deeper room + higher drops; playtest still needed)
- ~~Reach an Extraction point and leave to end the session.~~ (extraction trigger implemented; playtest still needed)

## Win / lose conditions
- ~~Win: reach Extraction alive with inventory haul (and any captured monster).~~ (win trigger implemented; playtest still needed)
- ~~Lose: player HP reaches 0.~~ (death trigger implemented; playtest still needed)
- ~~Lose: hunger reaches 0 for too long (survival death).~~ (death trigger implemented; playtest still needed)
- ~~Lose: temperature reaches lethal cold for too long (survival death).~~ (death trigger implemented; playtest still needed)

## Beta biome pressure
- ~~Cold + wet is the active environmental pressure.~~ (wetness + temperature pressure implemented; playtest still needed)
- ~~Hypothermia is implemented as the headline status pressure.~~ (player + monster hypothermia tiers; playtest still needed)

## Foraging model
- ~~Monsters are the primary source of food/materials.~~ (harvest drops implemented; playtest still needed)
- ~~World foraging exists but is low-yield emergency-only.~~ (forage action implemented; playtest still needed)

## Beta content minimum
- ~~3 monster types with distinct genes/stats.~~ (distinct mon instances configured; playtest still needed)
- ~~2 capture items: Basic Net (thrown) + Basic Snare (placed).~~ (capture items implemented; playtest still needed)
- ~~1 area/biome: Cold + wet zone with hypothermia pressure.~~ (cold/wet quadrant seeded; playtest still needed)

## Combat & capture feel
- ~~Real-time movement and attacks are tuned for Doom-style feel.~~ (speed tuning + attack cooldowns; playtest still needed)
- ~~Capture is always a player action using an item.~~ (capture inputs implemented; playtest still needed)
- ~~Failed capture attempts cause noise spike + item durability loss.~~ (noise spike + item loss implemented; playtest still needed)

## Survival stats (player-side minimum)
- ~~Hunger drains and can kill the player if ignored.~~ (death trigger implemented; playtest still needed)
- ~~Stamina gates sprint/attacks and impacts combat pacing.~~ (playtest)
- ~~Temperature responds to environment and can kill if too cold.~~ (death trigger implemented; playtest still needed)

## Next system milestones
- ~~Add phase-based simulation pipeline (intent → resolve → deposit → evolve → cleanup).~~ (pipeline hooks implemented; playtest still needed)
- ~~Implement full status/exhaustion system from the monster design doc.~~ (status tiers + exhaustion interactions; playtest still needed)
- ~~Add capture items and capture attempt actions.~~ (net + snare actions implemented; playtest still needed)
- ~~Add diffusion/advection for scent/noise/blood using `FLOW_VEC`.~~ (diffusion/advection passes implemented; playtest still needed)
