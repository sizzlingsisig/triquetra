# Triquetra MVP Implementation Plan (Weeks 3–5)

## Scope and Principles

This plan covers the MVP architecture, combat core, and narrative loop.

- Preserve canonical Triquetra counter rules (Spear > Shielded Knight, Sword guard-break/stun, Bow deflect on shield).
- Keep systems decoupled via signals/events and narrow interfaces.
- Apply SOLID pragmatically (single-responsibility scripts, explicit dependencies).
- Avoid overengineering: implement only what the current sprint needs.

---

## Week 3: Core Architecture and Soul Link

### Objective
Build the foundational runtime architecture: singleton game authority, state-locked guardian FSM, and Pandora fail-state trigger.

### Deliverables

1. **GameManager Autoload (Singleton)**
   - Owns run-level state and emits game-level events.
   - Maintains:
     - `persistent_flags: Dictionary`
     - guardian pool status (`Sword`, `Spear`, `Bow` active/locked)
   - Exposes:
     - `request_timeline_reset(reason: String)`
     - guardian lock/update methods
   - Signals:
     - `guardian_locked(form_name)`
     - `guardian_pool_changed(active_count)`
     - `timeline_reset_requested(reason)`

2. **State-Locked Player FSM**
   - `PlayerController` routes input and owns active state.
   - 3 concrete state nodes:
     - `State_Sword`
     - `State_Spear`
     - `State_Bow`
   - Lock flow:
     - lethal damage in state -> emit lock signal
     - state sets `is_locked = true`
     - locked states are excluded from swap cycle for remainder of run

3. **Pandora Static Anchor**
   - Implement as stationary collision trigger volume.
   - Triggers timeline reset if:
     - enemy enters Pandora volume, or
     - GameManager reports guardian pool is empty

4. **UI Integration (Minimal)**
   - Reflect guardian lock state and active pool count.
   - Show reset reason (Pandora breach vs no guardians remaining).

### Suggested Architecture Boundaries

- `GameManager`: run state, persistence dictionary, reset orchestration.
- `PlayerController`: input mapping and state switching only.
- `BaseGuardianState` + concrete states: per-form action/damage behavior.
- `PandoraTrigger`: breach detection only.
- `HUDController`: visual state updates only.

### Acceptance Criteria

- Guardian forms can be switched until locked.
- A locked form is permanently unavailable for the current run.
- Enemy breach into Pandora always triggers reset.
- Empty guardian pool always triggers reset.
- No cyclic dependencies between manager, FSM, and UI.

---

## Week 4: Combat Trinity and Game Feel

### Objective
Implement rock-paper-scissors combat interactions and responsiveness safeguards (input buffering + coyote windows).

### Deliverables

1. **Form Specials + Combat Hooks**
   - **Spear: Impale**
     - Forward lunge, piercing hitbox.
     - Instantly kills Shielded Knight.
   - **Sword: Parry**
     - Timed parry window.
     - Reflects projectiles and stuns melee attackers.
     - Guard break on shielded enemies after 2 successful sword hits.
   - **Bow: Disengage**
     - Backward movement burst.
     - Spread shot for spacing.
     - Deflected by shielded enemies.

2. **Shielded Knight (Test Enemy)**
   - Slow advance behavior toward Pandora.
   - Deterministic responses:
     - Spear -> instant death
     - Sword -> 2-hit guard break + stun/vulnerability
     - Bow -> full deflect (no damage)

3. **Responsiveness Systems**
   - Input buffer queue for actions during lockout windows (attack recovery/hit-stun).
   - Coyote timing for forgiving swap/defense windows.

4. **Animation/Hitbox Sync**
   - Activate hitboxes only during authored active frames.
   - Trigger animation via state events; avoid embedding combat rules in animation script logic.

### Acceptance Criteria

- All three specials function and are readable in gameplay.
- Shielded Knight interactions exactly match canonical counter rules.
- Buffered input executes on first valid frame after lockout.
- Coyote windows reduce frustration without invalidating risk/reward.

---

## Week 5: Priority Queue Dialogue and Boss Prototype

### Objective
Validate looped narrative interruption with persistent run data and a minimal boss encounter.

### Deliverables

1. **Priority Queue Dialogue Manager**
   - Evaluates dialogue entries with schema:
     - `id`, `priority`, `requirements`, `line` (or payload)
   - Compares `requirements` against `GameManager.persistent_flags`.
   - Selects highest-priority valid item and dispatches to UI.

2. **Prototype Boss Room**
   - Single room encounter.
   - Basic attack cycle only (no advanced AI needed for MVP).
   - Entry trigger invokes dialogue manager.

3. **Persistent Dictionary Integration**
   - Update flags on encounter outcomes (`boss_defeated`, `last_run_death`, etc.).
   - Verify second-loop dialogue interruption based on prior run flags.

4. **Loop Validation Pass**
   - First run: baseline boss dialogue.
   - Second run: altered/interrupted monologue when prior conditions are met.

### Acceptance Criteria

- Boss room consistently triggers dialogue on entry.
- Dialogue manager always selects the correct highest-priority valid line.
- Encounter outcomes correctly write to persistent dictionary.
- Second loop reflects previous run state in dialogue behavior.

---

## Cross-Week Technical Checklist

- Use signals for cross-system communication.
- Keep combat resolution in a dedicated resolver/service (not UI/animation/input).
- Ensure deterministic state transitions and clear lock reasons.
- Prefer composition over deep inheritance.
- Keep debug tooling simple:
  - current state
  - locked forms
  - buffered action
  - last combat resolution

---

## Suggested Folder/Script Layout (MVP)

```text
autoload/
  game_manager.gd

player/
  player_controller.gd
  states/
    base_guardian_state.gd
    state_sword.gd
    state_spear.gd
    state_bow.gd
  combat/
    combat_resolver.gd
    hitbox.gd

enemies/
  shielded_knight.gd
  prototype_boss.gd

world/
  pandora_trigger.gd

ui/
  hud_controller.gd
  dialogue_view.gd

narrative/
  dialogue_priority_manager.gd
  dialogue_entry.gd
```

---

## Execution Order (Lowest Risk)

1. Week 3 architecture skeleton and reset loop.
2. Week 4 Shielded Knight + specials with deterministic combat outcomes.
3. Week 4 input buffer/coyote timing polish.
4. Week 5 dialogue priority manager.
5. Week 5 boss room + persistent-flag loop validation.

This order ensures core fail-state and combat are stable before narrative dependencies are layered on top.
