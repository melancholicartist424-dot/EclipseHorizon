# Pixel Automata World Design Document

## Index

### A) Map stack (what exists as full-world images)
- A1) TILE_MAT — Static terrain/material + flags + base cost
- A2) OCC_ID — Occupancy EntityID (who is in each cell)
- A3) OCC_TYPE — Occupancy category/state (what is in each cell)
- A4) INIT — Initiative + phase scheduling (order + slow-tick gating)
- A5) BLOOD — Blood trail field (strength + type + age + tag)
- A6) SCENT — Scent field (strength + type + age)
- A7) NOISE — Noise memory field (intensity + type + age)
- A8) HEAT — Temperature/wetness field (temp + wet + inertia)
- A9) FLOW_VEC — Vector field (wind/current) (vx + vy + magnitude)
- A10) VEL_VEC — Vector field (desired movement) (vx + vy + speed intent)
- A11) FRICTION — Movement resistance field (mud/snow/water drag)
- A12) VIS_BLOCK — Line-of-sight / visibility attenuation field

### B) One unified overlay system (NOT a map stack, but required)
- B1) COMPLEX_PTR — Single pointer map for “multi-occupancy systems”
- B2) COMPLEX_REGISTRY — Dynamic table of nodes (events, packs, item piles, hazards)
- B3) FREE_LIST — Reuse pool for Complex IDs
- B4) GENERATION — Safety counter for ID reuse

### C) Cross-trigger types (the main interactions)
- C1) Movement legality (TILE_MAT + OCC_ID + FRICTION)
- C2) Movement resolution (INIT + EVENT intents)
- C3) Field deposition (BLOOD/SCENT/NOISE/HEAT writes)
- C4) Field evolution (diffuse/decay/advect using FLOW_VEC)
- C5) Capture and traps (EVENT + PACK + terrain constraints)

## 0. Hard constraints

- All maps share the exact same dimensions.
- No nested maps. No zones. No regions.
- Pixel values are numeric only. Strings live in registries.
- Movement updates every spatial map that represents that thing.
- Update order is explicit and stable.

## 1. Map stack spec (full-world images)

### 1.1 TILE_MAT (static terrain/material)

Models: world structure and terrain rules.

Channels:
- R = material id
- G = terrain flags bitmask
- B = base movement cost OR elevation
- A = reserved

Examples of terrain flags:
- blocks_move
- blocks_sight
- liquid
- slows
- climbable
- hazardous (optional)

### 1.2 OCC_ID (occupancy entity id)

Models: who occupies each pixel.

Channels:
- RGBA = 32-bit EntityID

Values:
- 0 = empty
- nonzero = occupied by that entity

Notes:
- Multi-tile entities write the same EntityID into all occupied pixels.

### 1.3 OCC_TYPE (occupancy category/state)

Models: what category the occupant is (fast behavior rules).

Channels:
- R = major type id (empty/player/predator/prey/neutral/corpse/etc.)
- G = subtype/species-group id (optional)
- B = quick state id (trapped/prone/climbing/etc.)
- A = flags bitmask (optional)

### 1.4 INIT (initiative + phase scheduling)

Models: ordering and “slow tick without zones.”

Channels:
- R = phase group id (0..N-1)
- G = stable tie-break value
- B = optional priority weight
- A = reserved

Uses:
- Resolve conflicts deterministically.
- Update only `INIT.R == currentPhase` pixels for heavy passes.

### 1.5 BLOOD (blood trail field)

Models: forensic trail + predator tracking input.

Channels:
- R = strength
- G = blood type id (category, not unique entity)
- B = age (0 fresh → 255 old)
- A = tag (infection/acidity/clotting/etc.)

### 1.6 SCENT (scent field)

Models: smell tracking + stealth pressure.

Channels:
- R = strength
- G = scent type id (blood/food/fear/smoke/territory/etc.)
- B = age
- A = reserved

### 1.7 NOISE (noise memory field)

Models: “something happened here” stimulus that fades.

Channels:
- R = intensity
- G = noise type id (impact/scream/splash/door slam/etc.)
- B = age
- A = reserved

### 1.8 HEAT (temperature/wetness field)

Models: survival pressure and status escalation drivers.

Channels:
- R = temperature (0 cold → 255 hot)
- G = wetness (0 dry → 255 soaked)
- B = inertia/age (optional)
- A = reserved

### 1.9 FLOW_VEC (wind/current vector field)

Models: environmental flow that pushes other fields.

Channels:
- R = vx packed (-1..+1 → 0..255)
- G = vy packed (-1..+1 → 0..255)
- B = magnitude
- A = turbulence/variance (optional)

Primary effects:
- Advection of SCENT (and optional BLOOD smear).
- Drift of light hazards (smoke/gas) if you add them.

### 1.10 VEL_VEC (desired movement + speed intent)

Models: where entities want to move and how hard they push.

This is optional but useful for “vector movement and speed.”

Channels:
- R = desired vx packed
- G = desired vy packed
- B = speed intent (0..255)
- A = movement mode (walk/sprint/crawl/swim/etc.)

Use:
- Entities write intent vectors instead of target tiles.
- Movement solver reads VEL_VEC and resolves to actual moves.
- Exhaustion integrates from speed intent + terrain friction.

### 1.11 FRICTION (movement resistance field)

Models: drag and resistance that affects speed and exhaustion.

Channels:
- R = friction/drag (0..255)
- G = slip risk (0..255)
- B = stamina tax multiplier (0..255)
- A = reserved

Sources:
- Derived from TILE_MAT material + wetness + snow depth.
- Updated medium/slow tick depending on complexity.

### 1.12 VIS_BLOCK (visibility attenuation field)

Models: how vision/raycasting is blocked or reduced.

Channels:
- R = opacity/attenuation (0 clear → 255 fully blocked)
- G = fog/smoke density (optional)
- B = darkness (optional)
- A = reserved

Use:
- Doom-style raycast reads TILE_MAT blocks_sight plus VIS_BLOCK attenuation.
- AI can “hear but not see” if VIS_BLOCK is high.

## 2. The single complex overlay system (one map for events + packs + piles)

### 2.1 COMPLEX_PTR (pointer map)

Models: “there are one or more complex nodes at this pixel.”

Channels:
- RGBA = 32-bit ComplexRef pointer

Values:
- 0 = none
- nonzero = index into COMPLEX_REGISTRY

### 2.2 COMPLEX_REGISTRY (dynamic node table)

Models: linked-list nodes for all complex systems.

Each node contains:
- next_ref
- kind (EVENT, PACK, ITEMPILE, HAZARD, MARKER)
- life_mode (EPHEMERAL or PERSISTENT)
- generation (for safe reuse)
- payload (kind-specific)
- optional string_id (debug only)

### 2.3 Dynamic assignment and reuse

- Maintain FREE_LIST of unused indices.
- Allocate by popping FREE_LIST.
- Free by pushing back to FREE_LIST.
- Increment generation on reuse.

### 2.4 Why this is the correct place for “multiple things in one pixel”

- OCC_ID stays single-owner truth for occupancy.
- COMPLEX_PTR holds “overlaps” and “systems” without requiring nested maps.
- Many nodes can exist at one pixel via the linked list.

## 3. Event and pack definitions (using the same mechanism)

### 3.1 EVENT nodes (ephemeral)

Purpose: represent interactions and conflicts for resolution.

Event payload fields:
- event_type_id
- actor_entity_id
- target_entity_id (optional)
- item_id (optional)
- strength/value (optional)
- timestamp/phase (optional)

Event examples:
- MOVE_INTENT
- MOVE_CONFLICT
- CONTACT_TRAP
- ATTACK_INTENT
- CAPTURE_ATTEMPT
- INTERACT

### 3.2 PACK nodes (persistent)

Purpose: represent group-level structure and coordination.

Pack payload fields:
- pack_id
- pack_type (pack/herd/swarm)
- goal_state (hunt/flee/rest/patrol)
- cohesion (0..255)
- preference ids (preferred BLOOD.G or SCENT.G types)

## 4. Movement and speed (vector-based version)

### 4.1 Intent writing

Entities write to VEL_VEC rather than picking a single destination tile.

### 4.2 Movement resolution reads

Read: VEL_VEC, TILE_MAT, FRICTION, OCC_ID, INIT.

Decide: actual step(s) and collisions.

Write: OCC_ID, OCC_TYPE, and EVENT nodes for conflicts.

Notes:
- High speed intent increases collision probability and noise.
- FRICTION reduces effective speed.
- Wetness + high slip risk can cause falls or forced stops.

### 4.3 Exhaustion integration (conceptual)

Exhaustion increases from “effort,” which is a function of:
- speed intent (VEL_VEC.B)
- friction (FRICTION.R)
- terrain base cost (TILE_MAT.B)
- cold/wet stress (HEAT channels)

## 5. Update pipeline (strict order)

### 5.1 Determine which pixels update this tick

- Use `INIT.R == currentPhase` gating for heavy passes.
- Use per-map tick timers (fast/medium/slow).

### 5.2 Intent phase

- Entities read local maps.
- Entities write VEL_VEC intent.
- Entities write EVENT intents into COMPLEX_PTR where needed (capture attempt, attack intent).

### 5.3 Resolve phase

- For each pixel with EVENT nodes.
- Walk nodes in INIT order.
- Resolve movement conflicts and interactions.
- Apply outcomes to OCC maps and entity table.

### 5.4 Deposit fields phase

Write BLOOD, SCENT, NOISE, HEAT updates caused by outcomes.

### 5.5 Evolve fields phase

- Diffuse/decay/advect scheduled field maps.
- FLOW_VEC pushes SCENT (and optional other fields).

### 5.6 Cleanup phase

- Remove EPHEMERAL EVENT nodes.
- Clear COMPLEX_PTR for pixels that only held ephemeral nodes.
- Keep persistent PACK/ITEMPILE nodes.

## 6. Doom-style rendering (read only)

- Raycast reads TILE_MAT blocks + VIS_BLOCK attenuation + DYN/COMPLEX markers if desired.
- OCC maps provide sprites/entities for the view.
- Fields can modulate visuals (blood darkening, heat shimmer).
- Rendering never writes to simulation maps.

## Next add-on

If you want this to go from “design” to “buildable,” the next add-on is a one-page legend with exact numeric enums:

- major types for OCC_TYPE.R
- scent types for SCENT.G
- blood types for BLOOD.G
- event_type_id list
- pack_type list
