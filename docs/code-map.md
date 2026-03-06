# Triquetra Code Map

Quick-reference map of core gameplay scripts and how they interact.

## Core Runtime Files

- `scripts/autoload/game_manager.gd`
  - Global run-state authority.
  - Tracks guardian lock state and emits timeline reset events.
  - Key methods: `reset_run_state`, `lock_guardian`, `is_guardian_locked`, `request_timeline_reset`.

- `scripts/player/player_controller.gd`
  - Main player orchestrator.
  - Buffers commands, applies movement/jump offsets, delegates form actions, manages attack overlap checks.
  - Key methods: `_unhandled_input`, `_consume_command_buffer`, `_try_execute_command`, `_set_active_form`, `_set_attack_area_active`, `_update_jump`.

- `scripts/player/components/player_animation_manager.gd`
  - Animation routing layer for locomotion and action clips.
  - Builds method-track attack-window timelines and emits `attack_window_toggled`.
  - Key methods: `setup`, `play`, `update_locomotion`, `_rebuild_attack_window_tracks`.

- `scripts/player/components/player_debug_widget.gd`
  - Optional runtime debug HUD for form, lock, buffer, and reset reason.
  - Key methods: `setup`, `_refresh`.

## Player State Files

- `scripts/player/states/base_guardian_state.gd`
  - Base contract for guardian states.
  - Shared lock gating and animation helper methods.

- `scripts/player/states/state_sword.gd`
  - Sword behavior: 3-hit primary combo + block special.

- `scripts/player/states/state_spear.gd`
  - Spear behavior: primary combo + impale special.

- `scripts/player/states/state_bow.gd`
  - Bow behavior: ranged primary shots + disengage special.
  - Spawns `arrow_scene` projectile with short animation-synced delay.

## Combat and Enemy Files

- `scripts/player/combat/player_arrow_projectile.gd`
  - Projectile movement and hit cleanup.

- `scripts/player/combat/combat_resolver.gd`
  - Combat rule scaffold (enums + resolver entry point).
  - Intended location for deterministic trait-vs-attack outcomes.

- `scripts/enemy/enemy.gd`
  - Enemy attack loop, hurt reactions, melee attack window, and enemy projectile spawn.

## Scene Wiring

- `scenes/player/player.tscn`
  - Wires `PlayerController`, `AnimationManager`, `PlayerDebugWidget`, and `States` (`Sword`, `Spear`, `Bow`).
  - Includes `AttackArea` and `CollisionShape2D` used by jump offset sync.

- `scenes/player/arrow_projectile.tscn`
  - PackedScene used by Bow state for arrow instantiation.

## Primary Runtime Flow

1. Input enters `PlayerController._unhandled_input` and is converted to buffered command IDs.
2. `_physics_process` consumes one executable command via the active guardian state.
3. State requests animations through controller -> `PlayerAnimationManager`.
4. Animation manager emits `attack_window_toggled` during attack clips.
5. Controller enables/disables `AttackArea` and resolves overlaps to enemy `receive_player_hit`.
6. `GameManager` lock/reset signals drive form lockout and timeline reset flow.
