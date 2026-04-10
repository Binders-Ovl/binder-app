# Changelog - 2026-04-10

## Scope
Session implementation of IMPL-003 combat-system refactor and follow-up fixes in `godot-tactical-rpg`, plus one rollback request at the end.

## Major Implementation (IMPL-003)

### 1) Combat architecture/modules added
- Added `data/models/world/combat/config/combat_config.gd`
- Added `data/models/world/combat/formula/combat_formula.gd`
- Added `data/models/world/combat/class/class_combat_res.gd`
- Added `data/models/world/combat/attack/attack_profile_res.gd`
- Added `data/models/world/combat/area/attack_area_res.gd`
- Added `data/models/world/combat/area/service.gd` (runtime area projection resolver)
- Added skill scaffolding:
  - `data/models/world/skill/skill_res.gd`
  - `data/models/world/skill/skill_library_res.gd`
  - `data/models/world/skill/examples/*.tres`

### 2) Stats model refactor
- Refactored `StatsResource` and runtime `Stats` from single `attack_power/attack_range` to:
  - class resource reference
  - fixed attack slots `attack_1/attack_2/attack_3`
  - formula-derived movement/jump/hp/mp
- Updated expertise bootstrap to keep skill placeholders compatible with current flow.

### 3) Player flow refactor
- Implemented flow:
  - `Attack -> Select Attack Type -> Select Target -> Resolve`
- Added participant stage/state fields:
  - `STAGE_SELECT_ATTACK_TYPE`
  - `selected_attack_slot`
  - `selected_attack`
  - `selected_attack_datum`
  - `clear_attack_selection()`
- Cancel-chain behavior wired:
  - target selection -> attack type selection
  - attack type selection -> action menu
  - action menu -> pawn selection

### 4) Controls/UI updates
- Renamed action `Wait` -> `Guard`
- Added attack-type panel/buttons (`AttackType1/2/3`) in controls scene
- Added corresponding control signals/service wiring:
  - `set_attack_types_menu_visibility`
  - `select_attack_type`
  - slot selection handlers
- Kept `Cancel` available in attack-selection context per follow-up fix.

### 5) Combat resolution refactor
- Attack execution now uses selected attack profile:
  - per-attack ACT cost mode (`default/absolute/multiplier`)
  - AGI vs DEX hit check
  - physical/magic formula routing
  - class-based defense/crit fields
- Area targeting uses datum-relative cardinal orientation with facing fallback where datum cannot define direction.

### 6) Data migration (.tres)
- Added class/attack/area example resources (including required area patterns)
- Migrated hero/mob stats resources to class + slot-based attack references with explicit fields.

## Follow-up Fixes Implemented (kept)

### BUG-013 (potential issues documentation)
- Added `.bugs/BUG-013-BIGCHANGE-Potential-issue.md`
- Indexed in `.bugs/BUGS.md`

### BUG-013A (attack area projection/overlay on slopes)
- Reworked area projection from world-offset matching to tile-neighbor traversal.
- Ensured attack area can extend beyond attack range as long as datum is valid.
- Added/updated docs:
  - `.bugs/BUG-013A-attack-area-overlay-projection-on-slopes.md`

### BUG-013B (Guard unavailable after attack selection)
- Fixed action-state refresh so `Guard` is re-enabled correctly after attack selection transitions.
- Added/updated docs:
  - `.bugs/BUG-013B-guard-disabled-after-attack-selection.md`

## Overlay Work
- Added attack-area preview overlay support on tiles.
- Added editable soft-yellow preview color in `tactics_config.gd`.
- Wired live preview updates from target-hover selection.

## Requested Rollback Performed (latest request)
- Reverted the later batch that introduced:
  - downhill jump behavior change
  - friendly-fire damage modifier/config
  - movement interruption-on-damage cancel behavior
  - hindered shake/tilt feedback
  - BUG-013C doc/index entry
- Final state keeps IMPL-003 + 13A/13B fixes, without the reverted 13C/improvement batch.

## Validation Notes
- Repeated headless Godot compile/start checks completed successfully after each significant patch round.
- No final script parse errors in last validation run.
