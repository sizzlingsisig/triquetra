# Triquetra MVP Implementation Plan

## 1. Current Baseline
The following systems already exist in code:
1. `GameManager` autoload with guardian lock map, pool count, and timeline reset signal.
2. `PlayerController` with movement, state activation, swap cycling, input buffering, and coyote timing.
3. Guardian state hierarchy (`BaseGuardianState`, `StateSword`, `StateSpear`, `StateBow`).
4. Form animation playback routing through `GuardianSprite`.

This plan focuses on closing MVP gaps and producing a stable vertical slice.

## 2. Phase Plan

### Phase 1: Stabilize Core Guardian Loop
Goal: make current loop robust and observable.

Tasks:
1. Add debug logging or on-screen debug widget for:
active form, locked forms, buffered action, last reset reason.
2. Verify lock idempotency across both state and manager paths.
3. Add explicit reset handling flow after `timeline_reset_requested` (scene reload or run reset routine).
4. Add guardrails for missing animations with warning output.

Exit criteria:
1. No soft lock when active guardian gets locked.
2. No duplicate lock side effects.
3. Reset signal always results in visible run restart behavior.

### Phase 2: Combat Rule Layer
Goal: implement deterministic interaction rules.

Tasks:
1. Create `scripts/player/combat/combat_resolver.gd`.
2. Define enums/constants for attack types and enemy traits.
3. Implement canonical outcomes:
Spear special defeats shielded knight.
Sword applies guard-break after threshold.
Bow is deflected by shield.
4. Route state actions through combat resolver instead of only animation playback.
5. Add one enemy prototype script (`shielded_knight.gd`) that consumes resolver outcomes.

Exit criteria:
1. Same input/state pair always yields same combat result.
2. Shielded knight interactions match design rules in all three forms.

### Phase 3: World Fail-State Integration
Goal: connect Pandora breach to run reset.

Tasks:
1. Create `scripts/world/pandora_trigger.gd` area trigger.
2. Detect enemy entry and call `GameManager.request_timeline_reset("pandora_breached")`.
3. Add minimal level wiring in main scene for trigger and enemy pathing toward Pandora.

Exit criteria:
1. Enemy entering Pandora always emits timeline reset request with breach reason.
2. No false positives from player entering the trigger.

### Phase 4: HUD and Feedback
Goal: ensure player can read system state at runtime.

Tasks:
1. Create `scripts/ui/hud_controller.gd`.
2. Subscribe to `GameManager.guardian_locked` and `guardian_pool_changed`.
3. Show active guardian, locked guardian list, and remaining pool count.
4. Show last reset reason briefly after reset trigger.

Exit criteria:
1. Guardian losses are visually obvious.
2. Reset reason is always visible to player/tester.

### Phase 5: Narrative Hook Foundation
Goal: wire persistent flag usage for loop-aware content.

Tasks:
1. Add `scripts/narrative/dialogue_priority_manager.gd`.
2. Define dialogue entry schema (`id`, `priority`, `requirements`, `payload`).
3. Query `GameManager.persistent_flags` to pick top valid line.
4. Set baseline flags on run outcomes (for example `last_run_death_reason`).

Exit criteria:
1. Dialogue manager consistently selects highest-priority valid entry.
2. At least one second-loop line changes based on a previous run flag.

## 3. Suggested File Additions
1. `scripts/player/combat/combat_resolver.gd`
2. `scripts/enemies/shielded_knight.gd`
3. `scripts/world/pandora_trigger.gd`
4. `scripts/ui/hud_controller.gd`
5. `scripts/narrative/dialogue_priority_manager.gd`

## 4. Work Breakdown and Order
1. Stabilize core guardian loop.
2. Implement combat resolver and shielded knight.
3. Integrate Pandora trigger reset path.
4. Add HUD feedback.
5. Add dialogue priority manager and persistent-flag updates.

This order minimizes integration risk by finalizing core gameplay contracts before layering world, UI, and narrative systems.

## 5. Test Checklist
1. Swap cycle test:
`Sword -> Spear -> Bow`, skipping locked forms in both directions.
2. Lock test:
lethal hit on each form marks it locked and updates pool count.
3. Empty pool test:
locking final guardian triggers `timeline_reset_requested("no_guardians_remaining")`.
4. Pandora test:
enemy breach triggers `timeline_reset_requested("pandora_breached")`.
5. Buffer test:
queued attack executes once state accepts action.
6. Coyote test:
late swap input within window still swaps correctly.

## 6. Definition of Done (MVP)
1. Player loop is playable end-to-end with reliable guardian lifecycle.
2. Canonical trinity combat interactions are implemented and readable.
3. Both reset paths are active and visible.
4. HUD communicates guardian state and reset reasons.
5. Persistent flags are used by at least one loop-aware narrative decision.