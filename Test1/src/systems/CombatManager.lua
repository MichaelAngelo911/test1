-- CombatManager.lua - Handles all combat calculations and battle mechanics
local CombatManager = {}

-- Combat formulas and constants
CombatManager.BASE_HIT_RATE = 80  -- Base hit chance percentage
CombatManager.BASE_CRIT_RATE = 5  -- Base critical chance percentage
CombatManager.CRIT_MULTIPLIER = 2.5  -- Damage multiplier for critical hits

-- Calculate hit chance between attacker and defender
function CombatManager.calculate_hit_chance(attacker, defender, weapon)
    -- Base formula: Hit = Weapon Hit + (Skill * 2) + (Luck / 2) - (Enemy Speed * 2) - (Enemy Luck / 4)
    local weapon_hit = weapon and weapon.hit or 90
    local attacker_skill = attacker.blueprint.stats.skl or 10
    local attacker_luck = attacker.blueprint.stats.luk or 10
    local defender_speed = defender.blueprint.stats.agi or 10
    local defender_luck = defender.blueprint.stats.luk or 10
    
    local hit_chance = weapon_hit + (attacker_skill * 2) + (attacker_luck / 2) - (defender_speed * 2) - (defender_luck / 4)
    
    -- Clamp between 0 and 100
    return math.max(0, math.min(100, hit_chance))
end

-- Calculate critical hit chance
function CombatManager.calculate_crit_chance(attacker, defender, weapon)
    -- Base formula: Crit = Weapon Crit + (Skill / 2) + (Luck / 4) - (Enemy Luck / 4)
    local weapon_crit = weapon and weapon.crit or 0
    local attacker_skill = attacker.blueprint.stats.skl or 10
    local attacker_luck = attacker.blueprint.stats.luk or 10
    local defender_luck = defender.blueprint.stats.luk or 10
    
    local crit_chance = weapon_crit + (attacker_skill / 2) + (attacker_luck / 4) - (defender_luck / 4)
    
    -- Clamp between 0 and 100
    return math.max(0, math.min(100, crit_chance))
end

-- Calculate base damage
function CombatManager.calculate_damage(attacker, defender, weapon, is_critical)
    -- Base formula: Damage = (Weapon Power + Strength) - Defense
    local weapon_power = weapon and weapon.damage or 5
    local attacker_str = attacker.blueprint.stats.str or 10
    local defender_def = defender.blueprint.stats.def or 10
    
    local base_damage = weapon_power + attacker_str - defender_def
    
    -- Apply critical multiplier if it's a critical hit
    if is_critical then
        base_damage = math.floor(base_damage * CombatManager.CRIT_MULTIPLIER)
    end
    
    -- Minimum damage is 1
    return math.max(1, base_damage)
end

-- Check if attacker can double attack (based on speed difference)
function CombatManager.can_double_attack(attacker, defender)
    local attacker_speed = attacker.blueprint.stats.agi or 10
    local defender_speed = defender.blueprint.stats.agi or 10
    
    -- If attacker has 5+ more speed, they can double attack
    return (attacker_speed - defender_speed) >= 5
end

-- Get equipped weapon for a unit
function CombatManager.get_equipped_weapon(unit)
    local weapons = require("src.entities.weapons")
    
    -- Check if unit has equipped weapon in loadout
    if unit.loadout and unit.loadout.equipment and unit.loadout.equipment.weapon then
        return weapons[unit.loadout.equipment.weapon]
    end
    
    -- Default to short_sword if no weapon equipped
    return weapons.short_sword
end

-- Check if units are in attack range
function CombatManager.is_in_range(attacker, defender)
    local weapon = CombatManager.get_equipped_weapon(attacker)
    local range = weapon and weapon.range or 1
    
    local distance = math.abs(attacker.gridx - defender.gridx) + math.abs(attacker.gridy - defender.gridy)
    return distance <= range
end

-- Get all enemies in attack range
function CombatManager.get_enemies_in_range(attacker)
    local UnitManager = require("src.entities.UnitManager")
    local enemies_in_range = {}
    
    for _, unit in ipairs(UnitManager.data.all_units) do
        -- Check if it's an enemy (different faction)
        if unit.allied ~= attacker.allied then
            if CombatManager.is_in_range(attacker, unit) then
                table.insert(enemies_in_range, unit)
            end
        end
    end
    
    return enemies_in_range
end

-- Calculate battle preview (returns predicted outcome without actually executing)
function CombatManager.calculate_battle_preview(attacker, defender)
    local preview = {
        attacker = {
            unit = attacker,
            hit_chance = 0,
            crit_chance = 0,
            damage = 0,
            double_attack = false,
            predicted_hp = attacker.state.hp
        },
        defender = {
            unit = defender,
            hit_chance = 0,
            crit_chance = 0,
            damage = 0,
            double_attack = false,
            predicted_hp = defender.state.hp,
            can_counter = false
        }
    }
    
    -- Get weapons
    local attacker_weapon = CombatManager.get_equipped_weapon(attacker)
    local defender_weapon = CombatManager.get_equipped_weapon(defender)
    
    -- Calculate attacker's stats
    preview.attacker.hit_chance = CombatManager.calculate_hit_chance(attacker, defender, attacker_weapon)
    preview.attacker.crit_chance = CombatManager.calculate_crit_chance(attacker, defender, attacker_weapon)
    preview.attacker.damage = CombatManager.calculate_damage(attacker, defender, attacker_weapon, false)
    preview.attacker.crit_damage = CombatManager.calculate_damage(attacker, defender, attacker_weapon, true)
    preview.attacker.double_attack = CombatManager.can_double_attack(attacker, defender)
    
    -- Check if defender can counter-attack
    preview.defender.can_counter = CombatManager.is_in_range(defender, attacker)
    
    if preview.defender.can_counter then
        preview.defender.hit_chance = CombatManager.calculate_hit_chance(defender, attacker, defender_weapon)
        preview.defender.crit_chance = CombatManager.calculate_crit_chance(defender, attacker, defender_weapon)
        preview.defender.damage = CombatManager.calculate_damage(defender, attacker, defender_weapon, false)
        preview.defender.crit_damage = CombatManager.calculate_damage(defender, attacker, defender_weapon, true)
        preview.defender.double_attack = CombatManager.can_double_attack(defender, attacker)
    end
    
    -- Calculate predicted HP (using average expected damage)
    local attacker_expected_damage = preview.attacker.damage * (preview.attacker.hit_chance / 100)
    if preview.attacker.double_attack then
        attacker_expected_damage = attacker_expected_damage * 2
    end
    
    local defender_expected_damage = 0
    if preview.defender.can_counter then
        defender_expected_damage = preview.defender.damage * (preview.defender.hit_chance / 100)
        if preview.defender.double_attack then
            defender_expected_damage = defender_expected_damage * 2
        end
    end
    
    preview.defender.predicted_hp = math.max(0, math.floor(defender.state.hp - attacker_expected_damage))
    preview.attacker.predicted_hp = math.max(0, math.floor(attacker.state.hp - defender_expected_damage))
    
    return preview
end

-- Execute actual combat (returns battle log)
function CombatManager.execute_combat(attacker, defender)
    local battle_log = {
        rounds = {},
        attacker_final_hp = attacker.state.hp,
        defender_final_hp = defender.state.hp,
        defender_defeated = false,
        attacker_defeated = false
    }
    
    local attacker_weapon = CombatManager.get_equipped_weapon(attacker)
    local defender_weapon = CombatManager.get_equipped_weapon(defender)
    
    -- Attacker's first strike
    local hit_chance = CombatManager.calculate_hit_chance(attacker, defender, attacker_weapon)
    local crit_chance = CombatManager.calculate_crit_chance(attacker, defender, attacker_weapon)
    
    local hit_roll = math.random(100)
    if hit_roll <= hit_chance then
        local crit_roll = math.random(100)
        local is_critical = crit_roll <= crit_chance
        local damage = CombatManager.calculate_damage(attacker, defender, attacker_weapon, is_critical)
        
        defender.state.hp = math.max(0, defender.state.hp - damage)
        
        table.insert(battle_log.rounds, {
            attacker = attacker.blueprint.name,
            defender = defender.blueprint.name,
            hit = true,
            critical = is_critical,
            damage = damage,
            defender_hp = defender.state.hp
        })
    else
        table.insert(battle_log.rounds, {
            attacker = attacker.blueprint.name,
            defender = defender.blueprint.name,
            hit = false,
            damage = 0,
            defender_hp = defender.state.hp
        })
    end
    
    -- Check if defender is defeated
    if defender.state.hp <= 0 then
        battle_log.defender_defeated = true
        battle_log.defender_final_hp = 0
        return battle_log
    end
    
    -- Defender counter-attack (if in range)
    if CombatManager.is_in_range(defender, attacker) then
        hit_chance = CombatManager.calculate_hit_chance(defender, attacker, defender_weapon)
        crit_chance = CombatManager.calculate_crit_chance(defender, attacker, defender_weapon)
        
        hit_roll = math.random(100)
        if hit_roll <= hit_chance then
            local crit_roll = math.random(100)
            local is_critical = crit_roll <= crit_chance
            local damage = CombatManager.calculate_damage(defender, attacker, defender_weapon, is_critical)
            
            attacker.state.hp = math.max(0, attacker.state.hp - damage)
            
            table.insert(battle_log.rounds, {
                attacker = defender.blueprint.name,
                defender = attacker.blueprint.name,
                hit = true,
                critical = is_critical,
                damage = damage,
                defender_hp = attacker.state.hp,
                is_counter = true
            })
        else
            table.insert(battle_log.rounds, {
                attacker = defender.blueprint.name,
                defender = attacker.blueprint.name,
                hit = false,
                damage = 0,
                defender_hp = attacker.state.hp,
                is_counter = true
            })
        end
        
        -- Check if attacker is defeated
        if attacker.state.hp <= 0 then
            battle_log.attacker_defeated = true
            battle_log.attacker_final_hp = 0
            return battle_log
        end
    end
    
    -- Double attacks (if applicable)
    if CombatManager.can_double_attack(attacker, defender) and defender.state.hp > 0 then
        -- Attacker's second strike
        hit_roll = math.random(100)
        if hit_roll <= hit_chance then
            local crit_roll = math.random(100)
            local is_critical = crit_roll <= crit_chance
            local damage = CombatManager.calculate_damage(attacker, defender, attacker_weapon, is_critical)
            
            defender.state.hp = math.max(0, defender.state.hp - damage)
            
            table.insert(battle_log.rounds, {
                attacker = attacker.blueprint.name,
                defender = defender.blueprint.name,
                hit = true,
                critical = is_critical,
                damage = damage,
                defender_hp = defender.state.hp,
                is_double = true
            })
        else
            table.insert(battle_log.rounds, {
                attacker = attacker.blueprint.name,
                defender = defender.blueprint.name,
                hit = false,
                damage = 0,
                defender_hp = defender.state.hp,
                is_double = true
            })
        end
        
        if defender.state.hp <= 0 then
            battle_log.defender_defeated = true
        end
    elseif CombatManager.can_double_attack(defender, attacker) and attacker.state.hp > 0 and CombatManager.is_in_range(defender, attacker) then
        -- Defender's second strike
        hit_chance = CombatManager.calculate_hit_chance(defender, attacker, defender_weapon)
        hit_roll = math.random(100)
        if hit_roll <= hit_chance then
            local crit_roll = math.random(100)
            local is_critical = crit_roll <= crit_chance
            local damage = CombatManager.calculate_damage(defender, attacker, defender_weapon, is_critical)
            
            attacker.state.hp = math.max(0, attacker.state.hp - damage)
            
            table.insert(battle_log.rounds, {
                attacker = defender.blueprint.name,
                defender = attacker.blueprint.name,
                hit = true,
                critical = is_critical,
                damage = damage,
                defender_hp = attacker.state.hp,
                is_counter = true,
                is_double = true
            })
        else
            table.insert(battle_log.rounds, {
                attacker = defender.blueprint.name,
                defender = attacker.blueprint.name,
                hit = false,
                damage = 0,
                defender_hp = attacker.state.hp,
                is_counter = true,
                is_double = true
            })
        end
        
        if attacker.state.hp <= 0 then
            battle_log.attacker_defeated = true
        end
    end
    
    battle_log.attacker_final_hp = attacker.state.hp
    battle_log.defender_final_hp = defender.state.hp
    
    return battle_log
end

return CombatManager