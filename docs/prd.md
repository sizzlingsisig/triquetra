# Triquetra MVP PRD

## 1. Product Summary
Triquetra is a top-down action prototype where one player body channels three guardian forms: `Sword`, `Spear`, and `Bow`.

The core player fantasy is fast tactical adaptation: swap forms, execute form-specific actions, and survive by preserving the guardian pool. If all guardians are lost, the timeline resets.

## 2. MVP Goals
1. Deliver a fully playable core loop with guardian swapping and lock-per-run consequences.
2. Validate rock-paper-scissors combat readability through form-specific attacks/specials.
3. Prove timeline-reset fail states and run-level persistence hooks.
4. Ship a testable vertical slice with one player, one enemy archetype, and one fail-state trigger.

## 3. Non-Goals (MVP)
1. Full narrative content pipeline and final dialogue tooling.
2. Multiple enemy factions and boss complexity.
3. Full save/load UI and meta-progression screens.
4. Multiplayer, advanced equipment systems, and procedural generation.

## 4. Target Experience
1. Form swap feels immediate and reliable.
2. Every form has a distinct tactical role.
3. Player clearly understands why a guardian became locked.
4. Fail states are deterministic and legible.

## 5. Core Gameplay Requirements
1. Single `PlayerController` controls movement, input routing, state switching, and animation routing.
2. Three guardian states exist and are swappable in sequence, skipping locked forms.
3. Lethal damage to active form permanently locks that form for the run.
4. If no forms remain, timeline reset is requested.
5. Input buffering supports queued actions during temporary action denial.
6. Swap coyote window allows forgiving swap timing.
7. Form actions:
`Sword`: primary attack, parry special.
`Spear`: primary attack, impale special.
`Bow`: primary shot, disengage special.

## 6. Functional Requirements
1. Global state authority via `GameManager` autoload.
2. Signals for guardian lock, guardian pool changes, and timeline reset request.
3. Player animation naming convention per form: `<form>_<action>`.
4. Input actions supported: `attack`, `special`, `swap_next`, `swap_prev`, movement UI actions.
5. Pandora breach trigger can request timeline reset with explicit reason.

## 7. Success Metrics (MVP Validation)
1. Player can complete a 5-minute test session with no control dead-ends.
2. 100 percent deterministic guardian lock behavior in manual test matrix.
3. No state where player has zero active forms without timeline reset signal firing.
4. Average action response under 1 frame after buffer becomes valid.

## 8. User Stories
1. As a player, I can swap to the next available guardian without selecting locked forms.
2. As a player, when my active guardian takes lethal damage, that form is unavailable for the rest of the run.
3. As a player, if all guardians are lost, the run resets immediately and clearly.
4. As a designer, I can add combat logic per form without rewriting player movement/input plumbing.

## 9. Risks and Mitigations
1. Risk: animation names drift from script expectations.
Mitigation: enforce naming convention in setup docs and add debug warnings.
2. Risk: duplicate lock triggers from both state and manager paths.
Mitigation: manager lock method is idempotent and should remain single source of truth.
3. Risk: unclear combat interactions reduce readability.
Mitigation: keep deterministic enemy responses and telegraphed specials.

## 10. Release Exit Criteria
1. All three guardian states are playable and swappable.
2. Lock-per-run behavior works and updates HUD/debug output.
3. Timeline reset triggers on no guardians remaining and Pandora breach.
4. Basic enemy test case demonstrates canonical counter behavior.
