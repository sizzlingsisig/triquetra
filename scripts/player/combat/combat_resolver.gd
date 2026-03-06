extends RefCounted
class_name CombatResolver

# Canonical attack channels used by player guardian forms.
enum AttackType {
	SWORD_PRIMARY,
	SWORD_SPECIAL,
	SPEAR_PRIMARY,
	SPEAR_SPECIAL,
	BOW_PRIMARY,
	BOW_SPECIAL
}

# Enemy traits can be combined to build deterministic outcomes.
enum EnemyTrait {
	NONE,
	SHIELDED,
	ARMORED,
	ELITE,
	UNDEAD
}

# Shared resolver outcome categories for combat rule routing.
enum Outcome {
	NO_EFFECT,
	DAMAGE,
	GUARD_BREAK,
	DEFLECTED,
	STAGGER,
	DEFEATED
}

const ATTACK_TYPE_NAMES: Dictionary = {
	AttackType.SWORD_PRIMARY: "sword_primary",
	AttackType.SWORD_SPECIAL: "sword_special",
	AttackType.SPEAR_PRIMARY: "spear_primary",
	AttackType.SPEAR_SPECIAL: "spear_special",
	AttackType.BOW_PRIMARY: "bow_primary",
	AttackType.BOW_SPECIAL: "bow_special"
}

const ENEMY_TRAIT_NAMES: Dictionary = {
	EnemyTrait.NONE: "none",
	EnemyTrait.SHIELDED: "shielded",
	EnemyTrait.ARMORED: "armored",
	EnemyTrait.ELITE: "elite",
	EnemyTrait.UNDEAD: "undead"
}

# Baseline trait bundles for quick enemy setup.
const ENEMY_ARCHETYPE_TRAITS: Dictionary = {
	"basic_knight": [EnemyTrait.NONE],
	"shielded_knight": [EnemyTrait.SHIELDED],
	"armored_knight": [EnemyTrait.ARMORED],
	"elite_guard": [EnemyTrait.SHIELDED, EnemyTrait.ELITE],
	"skeleton_warrior": [EnemyTrait.UNDEAD]
}

# Phase 2 rule wiring lives here so state scripts can stay lightweight.
func resolve(_attack_type: int, _enemy_traits: Array[int], _context: Dictionary = {}) -> Dictionary:
	return {
		"outcome": Outcome.NO_EFFECT,
		"damage": 0,
		"tags": PackedStringArray([])
	}

func has_trait(enemy_traits: Array[int], enemy_trait_id: int) -> bool:
	for current_trait in enemy_traits:
		if current_trait == enemy_trait_id:
			return true
	return false

func attack_type_name(attack_type: int) -> String:
	return String(ATTACK_TYPE_NAMES.get(attack_type, "unknown_attack"))

func enemy_trait_name(enemy_trait: int) -> String:
	return String(ENEMY_TRAIT_NAMES.get(enemy_trait, "unknown_trait"))
