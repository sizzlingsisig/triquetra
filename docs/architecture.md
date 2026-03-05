# Triquetra MVP Architecture

## 1. Architecture Overview
The MVP uses a composition-first Godot architecture with one player node, child guardian state nodes, and one autoload manager for run-level authority.

Design priorities:
1. Deterministic state transitions.
2. Minimal coupling between gameplay systems.
3. Event-driven communication through signals.

## 2. Runtime Components
1. `scripts/autoload/game_manager.gd`
Responsibility: global run state, guardian lock map, timeline reset signaling, persistent flags dictionary.

2. `scripts/player/player_controller.gd`
Responsibility: input mapping, movement, active guardian selection, action buffering, swap coyote logic, animation dispatch.

3. `scripts/player/states/base_guardian_state.gd`
Responsibility: shared guardian state contract (`setup`, `enter`, `exit`, action handling, lethal lock flow).

4. `scripts/player/states/state_sword.gd`
Responsibility: sword-specific action handling and animation requests.

5. `scripts/player/states/state_spear.gd`
Responsibility: spear-specific action handling and animation requests.

6. `scripts/player/states/state_bow.gd`
Responsibility: bow-specific action handling and animation requests.

## 3. Scene and Node Structure
Current player scene pattern:
1. `PlayerController` root (`CharacterBody2D`).
2. `GuardianSprite` (`AnimatedSprite2D`) for form animations.
3. `States` node containing one child node per guardian state.

## 4. Data Ownership
1. `GameManager` owns:
`persistent_flags: Dictionary`.
`_guardian_lock_map: Dictionary<StringName, bool>`.

2. `PlayerController` owns:
active form and active state references.
input buffer (`_buffered_action`, `_buffer_remaining`).
swap timing (`_swap_coyote_remaining`).

3. Each guardian state owns:
`form_id`, `is_locked`, and state-local action behavior.

## 5. Event Flow
### 5.1 Form Lock Flow
1. Active state receives lethal damage via `receive_lethal_damage()`.
2. State marks `is_locked = true` and calls `GameManager.lock_guardian(form_id)`.
3. `GameManager` emits `guardian_locked` and `guardian_pool_changed`.
4. `PlayerController` receives local `guardian_locked` signal and requests a swap.
5. If no guardians remain, `GameManager` emits `timeline_reset_requested("no_guardians_remaining")`.

### 5.2 Swap and Action Flow
1. Input enters `PlayerController._unhandled_input`.
2. Swap inputs call `_request_swap(direction)` and skip locked forms.
3. Attack/special inputs call `_request_action(action_name)`.
4. If active state rejects action, action is buffered.
5. On next valid state window, buffered action is consumed.

### 5.3 Animation Flow
1. State requests animation through `_play_animation` helper.
2. `PlayerController.play_guardian_animation` validates animation availability.
3. Locomotion animation runs only when no action animation is active.

## 6. Contracts and Interfaces
Guardian states must support:
1. `setup(player, game_manager)`.
2. `enter(previous_form)` and `exit(next_form)`.
3. `can_accept_action(action_name)` and `handle_action(action_name)`.
4. `receive_lethal_damage()`.

`PlayerController` assumes each state node provides `form_id` and emits `guardian_locked`.

## 7. Technical Constraints
1. Autoload naming conflict must be avoided (`game_manager.gd` has no `class_name GameManager`).
2. Animation names must match state expectations (for example `sword_attack`, `bow_disengage`).
3. Locking must be idempotent to prevent duplicate transitions.

## 8. Planned Near-Term Extensions
1. `world/pandora_trigger.gd` to request timeline reset on breach.
2. `player/combat/combat_resolver.gd` for deterministic outcome rules.
3. `ui/hud_controller.gd` to render active pool and lock indicators.
4. `narrative/dialogue_priority_manager.gd` using `persistent_flags`.

## 9. Testing Strategy
1. Manual state transition matrix for all form lock/swap permutations.
2. Signal contract checks:
`guardian_locked` fires once per form lock.
`timeline_reset_requested` fires when active count reaches zero.
3. Input timing checks for buffer and coyote windows.
