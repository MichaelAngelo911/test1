-- src/systems/battlesystem.lua
-- Minimal Fire Emblem-style battle flow to fit the current project.
-- Usage:
--   1) From UIManager.handle_menu_selection("Attack"), call BattleSystem.begin_target_select(unit)
--   2) While active, route mouse/keyboard to BattleSystem via UIManager.
--   3) Battle resolves immediately (no animations) and consumes the attacker's turn.

local BattleSystem = {}
BattleSystem.data = {
    state = "idle",   -- "idle" | "target_select" | "preview" | "resolving"
    attacker = nil,
    targets = {},     -- list of units in range (enemies)
    tile_size = 32,
    preview = {
        target = nil,
        hit_chance = 0,
        crit_chance = 0,
        estimated_damage = 0,
        estimated_crit_damage = 0,
        attacker_hp_after = 0,
        defender_hp_after = 0,
        defender_hp_after_crit = 0
    }
}

-- Try to require weapons from a few common paths so this works with your layout.
local weapons_db
do
    local candidates = { "src.entities.weapons", "src.data.weapons", "src.weapons", "weapons" }
    for _, m in ipairs(candidates) do
        local ok, mod = pcall(require, m)
        if ok and type(mod) == "table" then
            weapons_db = mod
            break
        end
    end
    if not weapons_db then
        -- Fallback for MVP
        weapons_db = {
            short_sword = { name="Short Sword", damage=10, range=1 },
        }
    end
end

local function grid_at_pixel(px, py)
    return math.floor(px / BattleSystem.data.tile_size), math.floor(py / BattleSystem.data.tile_size)
end

local function manhattan(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function equipped_weapon(unit)
    -- For MVP, default to short_sword unless you later wire loadouts.
    -- If unit.weapon is a string matching weapons_db key, use it.
    -- If it's a table, assume it's already a full weapon descriptor.
    local w = (unit.weapon or unit.weapon_id)
    if type(w) == "table" then return w end
    if type(w) == "string" and weapons_db[w] then return weapons_db[w] end
    return weapons_db.short_sword or select(2, next(weapons_db))
end

local function stat(u, key, fallback)
    if u and u.blueprint and u.blueprint.stats and u.blueprint.stats[key] then
        return u.blueprint.stats[key]
    end
    return fallback or 0
end

local function in_bounds(x, y)
    return x >= 0 and y >= 0 and x <= 15 and y <= 15
end

local function list_enemy_targets_in_range(attacker)
    local UnitManager = require("src.entities.UnitManager")
    local weapon = equipped_weapon(attacker)
    local range = (weapon and weapon.range) or 1
    local ax, ay = attacker.gridx, attacker.gridy
    local out = {}
    for _, u in ipairs(UnitManager.data.all_units or {}) do
        if u ~= attacker and not u.allied then
            local d = math.abs(u.gridx - ax) + math.abs(u.gridy - ay)
            if d <= range and in_bounds(u.gridx, u.gridy) then
                table.insert(out, u)
            end
        end
    end
    return out
end

local function remove_unit(u)
    local UnitManager = require("src.entities.UnitManager")
    local list = UnitManager.data.all_units or {}
    for i, v in ipairs(list) do
        if v == u then table.remove(list, i) return end
    end
end

-- === Hit/Crit helpers ===
local function clamp(x, a, b)
    return math.max(a, math.min(b, x))
end

local function get_stat(unit, key, defaultValue)
    -- Map LCK to existing LUK if present in your data
    if unit and unit.blueprint and unit.blueprint.stats then
        local stats = unit.blueprint.stats
        if stats[key] ~= nil then return stats[key] end
        if key == "lck" and stats["luk"] ~= nil then return stats["luk"] end
    end
    return defaultValue or 0
end

local function terrain_avoid_at(x, y)
    -- MVP: no terrain yet
    return 0
end

local function calc_acc(attacker, weapon)
    local skl = get_stat(attacker, "skl", 0)
    local lck = get_stat(attacker, "lck", 0)
    local wHit = (weapon and weapon.hit) or 0
    return wHit + (2 * skl) + math.floor(lck / 2)
end

local function calc_avo(defender)
    local spd = get_stat(defender, "agi", 0) -- AGI used as SPD
    local lck = get_stat(defender, "lck", 0)
    local terr = terrain_avoid_at(defender.gridx, defender.gridy)
    return (2 * spd) + lck + terr
end

local function final_hit(attacker, defender, weapon)
    return clamp(calc_acc(attacker, weapon) - calc_avo(defender), 0, 100)
end

local function calc_crit_rate(attacker, weapon)
    local skl = get_stat(attacker, "skl", 0)
    local wCrit = (weapon and weapon.crit) or 0
    return wCrit + math.floor(skl / 2)
end

local function calc_crit_avoid(defender)
    return get_stat(defender, "lck", 0)
end

local function final_crit(attacker, defender, weapon)
    return clamp(calc_crit_rate(attacker, weapon) - calc_crit_avoid(defender), 0, 100)
end

local function roll_2rn()
    -- 0..99 average for classic FE feel
    return (love.math.random(0, 99) + love.math.random(0, 99)) / 2
end

-- === Battle Preview Functions ===
local function calculate_battle_preview(attacker, defender)
    local weapon = equipped_weapon(attacker)
    local preview = BattleSystem.data.preview
    
    -- Calculate hit and crit chances
    preview.hit_chance = final_hit(attacker, defender, weapon)
    preview.crit_chance = final_crit(attacker, defender, weapon)
    
    -- Calculate base damage
    local str = stat(attacker, "str", 0)
    local weapon_damage = (weapon and weapon.damage) or 0
    local atk = str + weapon_damage
    local def = stat(defender, "def", 0)
    preview.estimated_damage = math.max(0, atk - def)
    preview.estimated_crit_damage = preview.estimated_damage * 3
    
    -- Calculate HP after battle
    local defender_current_hp = defender.state.hp or defender.blueprint.stats.hp or 1
    local attacker_current_hp = attacker.state.hp or attacker.blueprint.stats.hp or 1
    
    preview.defender_hp_after = math.max(0, defender_current_hp - preview.estimated_damage)
    preview.defender_hp_after_crit = math.max(0, defender_current_hp - preview.estimated_crit_damage)
    
    -- Calculate counterattack damage if defender can hit back
    local w_def = equipped_weapon(defender)
    local dist = math.abs(defender.gridx - attacker.gridx) + math.abs(defender.gridy - attacker.gridy)
    local counter_damage = 0
    
    if w_def and w_def.range and dist <= w_def.range then
        local def_str = stat(defender, "str", 0)
        local def_weapon_damage = (w_def and w_def.damage) or 0
        local def_atk = def_str + def_weapon_damage
        local att_def = stat(attacker, "def", 0)
        counter_damage = math.max(0, def_atk - att_def)
    end
    
    preview.attacker_hp_after = math.max(0, attacker_current_hp - counter_damage)
end

-- === Public API ===
function BattleSystem.is_active()
    return BattleSystem.data.state ~= "idle"
end

function BattleSystem.load()
    -- Seed RNG once for this session
    if love and love.math and love.math.setRandomSeed then
        love.math.setRandomSeed(os.time())
    end
end

function BattleSystem.begin_target_select(attacker)
    BattleSystem.data.attacker = attacker
    BattleSystem.data.targets = list_enemy_targets_in_range(attacker)
    BattleSystem.data.state = "target_select"

    -- If there are no targets, bounce back to the post-move menu.
    if #BattleSystem.data.targets == 0 then
        local UIManager = require("src.systems.uimanager")
        print("No targets in range.")
        UIManager.show_post_move_menu(attacker)
        BattleSystem.data.state = "idle"
    end
end

function BattleSystem.cancel_target_select()
    if BattleSystem.data.state ~= "target_select" then return end
    local UIManager = require("src.systems.uimanager")
    if BattleSystem.data.attacker then
        UIManager.show_post_move_menu(BattleSystem.data.attacker)
    end
    BattleSystem.data.attacker = nil
    BattleSystem.data.targets = {}
    BattleSystem.data.state = "idle"
end

function BattleSystem.show_battle_preview(target)
    local attacker = BattleSystem.data.attacker
    if not attacker or not target then return end
    
    BattleSystem.data.preview.target = target
    calculate_battle_preview(attacker, target)
    BattleSystem.data.state = "preview"
end

function BattleSystem.hide_battle_preview()
    BattleSystem.data.state = "target_select"
    BattleSystem.data.preview.target = nil
end

function BattleSystem.confirm_battle()
    local attacker = BattleSystem.data.attacker
    local defender = BattleSystem.data.preview.target
    
    if not attacker or not defender then return end
    
    BattleSystem.data.state = "resolving"
    
    -- Resolve the actual battle
    local dealt = resolve_strike(attacker, defender)
    print(("Attacker dealt %d damage"):format(dealt))
    if defender.state.hp <= 0 then
        remove_unit(defender)
        print("Defender defeated!")
    else
        -- Counterattack if defender can hit back
        local w_def = equipped_weapon(defender)
        local dist = math.abs(defender.gridx - attacker.gridx) + math.abs(defender.gridy - attacker.gridy)
        if w_def and w_def.range and dist <= w_def.range then
            local back = resolve_strike(defender, attacker)
            print(("Defender countered for %d damage"):format(back))
            if attacker.state.hp <= 0 then
                remove_unit(attacker)
                print("Attacker was defeated!")
            end
        end
    end

    -- Clean up and finish attacker turn if still alive
    local UnitManager = require("src.entities.UnitManager")
    local UIManager = require("src.systems.uimanager")
    
    if attacker and attacker.state and attacker.state.hp > 0 then
        attacker.has_acted = true
        attacker.state.turn.has_acted = true
        UnitManager.deselect_unit()
    end
    UIManager.hide_post_move_menu()

    -- Reset battle system state
    BattleSystem.data.attacker = nil
    BattleSystem.data.targets = {}
    BattleSystem.data.preview.target = nil
    BattleSystem.data.state = "idle"
end

local function resolve_strike(attacker, defender)
    local w = equipped_weapon(attacker)

    -- Determine hit chance using 2RN
    local hitPercent = final_hit(attacker, defender, w)
    local hitRoll = roll_2rn()
    local didHit = hitRoll < hitPercent

    -- Base damage pre-crit
    local str = stat(attacker, "str", 0)
    local weapon_damage = (w and w.damage) or 0
    local atk = str + weapon_damage
    local def = stat(defender, "def", 0)
    local baseDamage = math.max(0, atk - def)

    local critPercent = 0
    local critRoll = 0
    local didCrit = false
    local finalDamage = 0

    if didHit and baseDamage > 0 then
        -- Check for crit
        critPercent = final_crit(attacker, defender, w)
        critRoll = love.math.random(0, 99)
        didCrit = critRoll < critPercent
        finalDamage = didCrit and (baseDamage * 3) or baseDamage
    else
        finalDamage = 0
    end

    -- Logging for learning
    print("=== BATTLE CALCULATION ===")
    print("Attacker: " .. (attacker.blueprint.name or "Unknown"))
    print("  STR: " .. str .. ", Weapon: " .. (w and w.name or "None") .. " (DMG " .. weapon_damage .. ")")
    print("Defender: " .. (defender.blueprint.name or "Unknown") .. ", DEF: " .. def)
    print("-- Accuracy --")
    print("  Hit%: " .. hitPercent .. ", Roll(2RN): " .. hitRoll .. (didHit and " -> HIT" or " -> MISS"))
    if didHit then
        print("-- Critical --")
        print("  Crit%: " .. critPercent .. ", Roll: " .. critRoll .. (didCrit and " -> CRIT" or " -> no crit"))
    end

    local beforeHP = (defender.state.hp or defender.blueprint.stats.hp or 1)
    if didHit then
        defender.state.hp = math.max(0, beforeHP - finalDamage)
    end
    print("  Damage Applied: " .. finalDamage .. (didCrit and " (critical)" or ""))
    print("  HP Before: " .. beforeHP .. " -> After: " .. (defender.state.hp or beforeHP))
    print("========================")

    return finalDamage
end

local function tile_has_unit(x, y, units)
    for _, u in ipairs(units) do
        if u.gridx == x and u.gridy == y then return u end
    end
    return nil
end

function BattleSystem.handle_mouse_input(x, y, button)
    if button ~= 1 then return end
    
    local UnitManager = require("src.entities.UnitManager")
    local UIManager = require("src.systems.uimanager")
    
    if BattleSystem.data.state == "target_select" then
        local gx, gy = grid_at_pixel(x, y)
        local defender = tile_has_unit(gx, gy, BattleSystem.data.targets)
        if defender then
            -- Show battle preview
            BattleSystem.show_battle_preview(defender)
        else
            -- Clicked outside: cancel back to the action menu
            BattleSystem.cancel_target_select()
        end
    elseif BattleSystem.data.state == "preview" then
        -- Check if clicked on preview UI elements
        local preview = BattleSystem.data.preview
        
        -- Check if clicked on "Confirm Attack" button (roughly positioned)
        if x >= 300 and x <= 500 and y >= 400 and y <= 430 then
            BattleSystem.confirm_battle()
        -- Check if clicked on "Cancel" button
        elseif x >= 300 and x <= 500 and y >= 440 and y <= 470 then
            BattleSystem.hide_battle_preview()
        end
    end
end

function BattleSystem.handle_keyboard_input(key)
    if key == "escape" then
        if BattleSystem.data.state == "target_select" then
            BattleSystem.cancel_target_select()
        elseif BattleSystem.data.state == "preview" then
            BattleSystem.hide_battle_preview()
        end
    elseif key == "return" or key == "space" then
        if BattleSystem.data.state == "preview" then
            BattleSystem.confirm_battle()
        end
    end
end

function BattleSystem.update(dt)
    -- no animations yet
end

function BattleSystem.draw()
    if BattleSystem.data.state == "target_select" then
        -- Highlight targetable enemy tiles in red
        love.graphics.setColor(1, 0, 0, 0.35)
        for _, u in ipairs(BattleSystem.data.targets) do
            love.graphics.rectangle("fill", u.gridx * BattleSystem.data.tile_size, u.gridy * BattleSystem.data.tile_size,
                BattleSystem.data.tile_size, BattleSystem.data.tile_size)
        end
        
        -- Draw instruction text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Click on red tile to preview attack!", 10, 550)
        love.graphics.print("Press ESC to cancel", 10, 570)
        
    elseif BattleSystem.data.state == "preview" then
        -- Draw battle preview UI
        local preview = BattleSystem.data.preview
        local attacker = BattleSystem.data.attacker
        local defender = preview.target
        
        if not attacker or not defender then return end
        
        -- Semi-transparent overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        
        -- Preview panel
        love.graphics.setColor(0.1, 0.1, 0.2, 0.95)
        love.graphics.rectangle("fill", 200, 150, 400, 350)
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.rectangle("line", 200, 150, 400, 350)
        
        -- Title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf("BATTLE PREVIEW", 200, 170, 400, "center")
        
        -- Combatants
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.print("Attacker: " .. (attacker.blueprint.name or "Unknown"), 220, 210)
        love.graphics.print("Defender: " .. (defender.blueprint.name or "Unknown"), 220, 230)
        
        -- Hit and Crit chances
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("Hit Chance: " .. preview.hit_chance .. "%", 220, 260)
        love.graphics.print("Crit Chance: " .. preview.crit_chance .. "%", 220, 280)
        
        -- Estimated damage
        love.graphics.setColor(1, 0.8, 0.8, 1)
        love.graphics.print("Estimated Damage: " .. preview.estimated_damage, 220, 310)
        if preview.crit_chance > 0 then
            love.graphics.print("Critical Damage: " .. preview.estimated_crit_damage, 220, 330)
        end
        
        -- HP outcomes
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("Defender HP after: " .. preview.defender_hp_after, 220, 360)
        if preview.crit_chance > 0 then
            love.graphics.print("Defender HP after crit: " .. preview.defender_hp_after_crit, 220, 380)
        end
        
        -- Buttons
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", 300, 400, 200, 30)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Confirm Attack (Enter)", 300, 405, 200, "center")
        
        love.graphics.setColor(0.8, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", 300, 440, 200, 30)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Cancel (ESC)", 300, 445, 200, "center")
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return BattleSystem