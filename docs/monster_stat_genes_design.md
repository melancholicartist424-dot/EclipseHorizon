# Monster Stat + Genes Design Document

System: Exhaustion tiers + tiered status effects + capture as an item-based chance action
Scope: everything needed to implement monsters, battles, and progression

## 1. High-level concept
This game treats a monster like a living system under stress. Combat and survival are mostly about stacking pressure until a failure mode occurs. HP still matters, but the “main spiral” is Exhaustion interacting with tiered statuses and environment. Capture is never automatic; it’s always a player action using an item.

## 2. Loss modes (exactly four)
These are the only four ways a monster loses a fight.

### 2.1 Death / Body KO
- Trigger: HP reaches 0.
- Interpretation: dead or “downed” depending on your world lethality rules.

### 2.2 Exhaustion Collapse
- Trigger: Exhaustion Tier reaches Collapse (Tier 4).
- Interpretation: system shutdown, passing out, full failure.

### 2.3 Incapacitation (Action Lockout)
- Trigger: the monster has no legal actions available through a full resolution cycle.
- Cause: tiered statuses + constraints prevent attacking, moving, stabilizing, fleeing, or interacting.

### 2.4 Capture (success of capture action)
- Trigger: player uses a capture action with an item; the capture check succeeds.
- Important: low HP or high exhaustion never “auto-captures” anything. Those only make the attempt more likely to work.

## 3. Core state variables per monster
These exist on every monster.

### 3.1 HP
- Range: 0..MaxHP
- Used for: physical survival and injury thresholds.

### 3.2 Exhaustion Tier
- Stored as an integer tier, not a long meter.
- Range: 0..4
- Tier meanings (locked):
  - Tier 0 Normal
  - Tier 1 Strained
  - Tier 2 Fatigued
  - Tier 3 Critical
  - Tier 4 Collapse (loss)

### 3.3 Status effects (tiered)
- Each status has a tier: 0..3
- Tier meanings:
  - Tier 0 None
  - Tier 1 Mild
  - Tier 2 Severe
  - Tier 3 Critical

### 3.4 Condition flags (small booleans)
Examples: “Cornered”, “Trapped”, “Grounded”, “In Water”, “On Fire”, “In Darkness”, “In Deep Snow”.
These usually come from environment/map checks but are stored on the monster for the current tick.

## 4. Primary combat stats (the small “numbers set”)
These stats do not try to be clever. They are the math knobs for damage, defense, and accuracy.

### 4.1 Power (physical offense)
Used for physical attack damage and force effects (push, shove).

### 4.2 Guard (physical defense)
Reduces physical damage and physical force effects.

### 4.3 Focus (special offense)
Used for non-physical attack types (venom, shock, psychic, acid, cold, heat, etc.).
Also used for some status application strength.

### 4.4 Ward (special defense)
Reduces special damage and reduces severity of special status applications.

## 5. Secondary traits (limited list, but meaningful)
These are the “survival feel” stats. Keep them few and use them everywhere.

### 5.1 Speed
Affects initiative ordering and chase pressure.
Interacts strongly with terrain friction (mud, snow, water).

### 5.2 Mass
Affects knockback, trap triggering, net effectiveness, and how hard it is to restrain.

### 5.3 Recovery
Affects how quickly the monster stabilizes and how quickly certain statuses decay.

### 5.4 Composure
Controls fear/panic escalation and willingness to disengage.
This is not a sanity bar. It’s a modifier on tier escalation and surrender behavior.

## 6. Exhaustion system (detailed rules)
Exhaustion is the main spiral. It should rise from effort, harsh conditions, and struggling against control effects.

### 6.1 Exhaustion tier effects
- Tier 0 Normal: No penalties.
- Tier 1 Strained: Reduced effective Recovery. More sensitive to terrain costs and wet/cold penalties.
- Tier 2 Fatigued: Status escalation is faster. “Push actions” (sprinting, struggling, repeated heavy moves) have a higher chance to increase exhaustion again.
- Tier 3 Critical: Forced penalties each turn (examples: reduced action options, higher misstep risk). Any additional stress source is likely to push to Collapse.
- Tier 4 Collapse: Immediate loss mode: Exhaustion Collapse.

### 6.2 Exhaustion gain sources (standard list)
A) Effort
- High movement effort (sprinting, climbing, deep snow, mud).
- Over-extending (acting while heavily impaired).

B) Environment
- Cold + wet exposure
- Heat exposure
- Low oxygen / toxic air (if you add)

C) Status-driven strain
- Immobilize: “struggling” increases exhaustion
- Panic: increases exhaustion from movement and actions
- Fatigue status directly accelerates exhaustion rise

D) Repeated high-cost moves
- Moves can have “strain tags” that increase exhaustion chance, especially at tiers 2–3.

### 6.3 Exhaustion reduction rules (kept hard)
To preserve the spiral, reduction should be limited in-combat.
- In-combat: only special “Rest / Stabilize” actions and some abilities can reduce exhaustion tier, and usually by at most 1.
- Out of combat: rest/sleep and care actions reduce exhaustion tier reliably.

## 7. Status effects (tiered)
Statuses are severity-based and can escalate due to time, re-application, exhaustion tier, and environment.

### 7.1 Status category list (recommended minimum)
Injury
- Bleeding
- Infection

Control
- Immobilize (trap/net)
- Stagger (brief action loss)

System strain
- Fatigue (bridge status to exhaustion)
- Hypothermia (cold+wet)
- Heatstroke (heat)

Mental/behavior
- Panic
- Rage (optional, but useful)

### 7.2 Status escalation drivers (universal rules)
- Higher Exhaustion tier increases escalation probability.
- Re-applying the same status tends to increase tier (or refreshes severity).
- Certain environment pairs escalate specific statuses (examples):
  - Cold + Wet → Hypothermia tier rises
  - Toxic terrain + Bleeding → Infection tier rises
  - Loud noise + darkness → Panic tier rises

### 7.3 Status tier effects (examples in spec form)
Bleeding
- Tier 1: light HP drain over time; leaves blood field.
- Tier 2: stronger HP drain; blood field increases faster; effort increases.
- Tier 3: severe HP drain; high chance of exhaustion gain on movement.

Immobilize
- Tier 1: movement restricted; escape action available.
- Tier 2: movement mostly blocked; struggling adds exhaustion pressure.
- Tier 3: movement blocked; action list heavily restricted; capture attempts get a large bonus.

Fatigue
- Tier 1: effort costs “feel” higher (more likely exhaustion rises).
- Tier 2: repeated actions and movement frequently raise exhaustion.
- Tier 3: actions can force exhaustion rise each resolution cycle.

Hypothermia (cold+wet)
- Tier 1: Recovery reduced; speed reduced.
- Tier 2: exhaustion rises over time; control statuses last longer.
- Tier 3: rapid collapse risk; lockout becomes likely.

Panic
- Tier 1: reduced control (move choice restricted).
- Tier 2: increased exhaustion from movement/actions; noise output increases.
- Tier 3: frequent action loss or forced flee behavior; capture attempts may become easier due to bad resistance.

## 8. Combat actions and initiative (how stats actually get used)
### 8.1 Action types
- Attack (physical or special)
- Move
- Stabilize / Rest (limited in-combat recovery, reduces certain status pressure)
- Escape / Struggle (to reduce immobilize tier or break restraints)
- Capture Attempt (player-only action with item)

### 8.2 Initiative ordering
You can keep it simple:
- InitiativeScore = Speed + modifiers from exhaustion tier + modifiers from statuses (stagger/panic/immobilize).
- Higher score acts first.
- Tie-break uses a stable value (INIT map tie-break or monster seed).

## 9. Capture system (full spec)
Capture is a deliberate play. It uses items and has real consequences on failure.

### 9.1 Capture attempt requirements
- Player chooses Capture Attempt as the action.
- Player must have a capture item equipped/available.
- The target must be within the item’s application rules (range, line, tile condition).

### 9.2 Capture item definition
Every capture item has these properties:
- ItemType: Net / Trap / Snare / Cage / Bola (whatever you support)
- ApplicationType: thrown / placed / contact
- Range
- Allowed target size/mass range
- BaseCapturePower
- Durability (consumed or degrades)
- FailConsequence profile (noise, self-stagger, target-bonus)

### 9.3 Capture chance formula shape (locked)
CaptureChance = ItemBase + StateBonus − TargetResistance

ItemBase
- Derived from BaseCapturePower, and whether the application succeeded cleanly.

StateBonus (target state helps you)
- Exhaustion Tier bonus
- Immobilize tier bonus
- Stagger tier bonus
- Cornered flag bonus
- Trap-triggered bonus
- Low HP bonus (small; should not dominate)

TargetResistance (target traits hurt you)
- Genes: slippery, strong, armored, nimble
- Mass vs item strength mismatch
- Body plan mismatch (some traps are bad for slug bodies, etc.)

### 9.4 Capture failure consequences (must exist)
On failed capture attempt, apply one or more:
- Item durability loss or item consumed
- Noise spike (attracts threats)
- Target “escape momentum” (temporary resistance bonus against capture)
- Player penalty (optional: stumble, lose next initiative if you want risk)

## 10. Genes (full structure)
Genes define what a monster is. They should not add extra meters. They should change ranges, resistances, and interaction rules.

### 10.1 Gene layers
A) Body Plan Genes (geometry + compatibility)
- Locomotion: slug / quad / biped
- Tissue: fur / skin / carapace
- SizeClass: tiny / small / medium / large
- Morph tags: flexible, rigid, spined, adhesive, etc.

B) Physiology Genes (numbers + tolerances)
- MaxHP range modifier
- Exhaustion resistance (how quickly exhaustion rises from effort)
- Recovery efficiency modifier
- Cold tolerance / heat tolerance
- Toxin tolerance

C) Temperament Genes (behavior + escalation)
- Composure baseline modifier
- Panic susceptibility
- Rage susceptibility
- Flee threshold bias
- Surrender bias (if you keep surrender as behavior, not a loss mode)

D) Sense Genes (field interaction strength)
- Smell acuity (better tracking of SCENT/BLOOD gradients)
- Hearing acuity (better response to NOISE)
- Vision/low-light (less affected by VIS_BLOCK/darkness)

### 10.2 Gene outputs into mechanics (explicit)
- Endurant: reduces exhaustion gain chance from effort.
- Slippery: increases TargetResistance vs nets, reduces immobilize tier duration.
- Heavy: increases Mass, harder to trap, triggers traps more often, louder movement.
- Cold-adapted: hypothermia escalation slowed; wetness less harmful.
- Fearful: panic escalates faster; may flee earlier.
- Stoic: panic escalates slower; can still collapse from exhaustion.

## 11. Growth, age, and body condition (if you use them)
These change the same stats in predictable ways.

### 11.1 Age stage modifiers (example approach)
- Youth: lower MaxHP and Mass, higher Speed, lower Guard.
- Prime: best balance.
- Old: lower Recovery and Speed, higher vulnerability to strain statuses.

### 11.2 Body condition modifiers (malnourished / normal / obese)
- Malnourished: lower MaxHP, lower Recovery, faster exhaustion rise, higher hypothermia risk.
- Normal: baseline.
- Obese: higher MaxHP and Mass, lower Speed, higher heat/effort strain, harder to capture with small nets but easier to corner.

## 12. Move design rules (to keep the system stable)
Every move should declare what it does in these lanes:

### 12.1 Move payload types
- Damage (physical or special)
- Status application attempt (which status, tier pressure)
- Control effect (immobilize/stagger)
- Field write (noise spike, blood splash)
- Strain tag (raises exhaustion chance)

### 12.2 Status application rule shape
ApplyStatusChance depends on attacker Focus (or Power for physical grapples) versus defender Ward/Guard, then modified by existing tiers and environment.
If applied, it starts at Tier 1 unless the move explicitly “jumps” tiers.

## 13. Balancing knobs (so you can tune without redesign)
These are the safest places to tune later.
- Exhaustion tier thresholds (how easily tiers rise)
- Status escalation rates per exhaustion tier
- Capture ItemBase values and durability
- Resistance weights from genes
- Cornered bonus size
- In-combat exhaustion reduction limits (keep small)

## 14. Implementation checklist (what to store per monster)
Required per monster:
- MaxHP, HP
- ExhaustionTier (0..4)
- Power, Guard, Focus, Ward
- Speed, Mass, Recovery, Composure
- Status tiers for the chosen status list (each 0..3)
- Gene tags list + derived resistances
- CaptureResistance derived value(s)
- Current flags (cornered, trapped, wet, cold, etc.) for the tick

## 15. Minimal “first playable” recommendation
If you want a first implementation that already feels like the real system:

Stats
- HP/MaxHP
- Power, Guard, Focus, Ward
- Speed, Mass
- Recovery, Composure

Exhaustion tiers
- 0..4

Statuses
- Bleeding
- Immobilize
- Fatigue
- Hypothermia
- Panic

Capture items
- Basic Net (thrown)
- Basic Snare (placed)
