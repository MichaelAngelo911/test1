-- UIManager.lua - This is the dedicated interface department for your game
-- It handles all visual elements that are not part of the game world itself
-- Think of it as the "presentation layer" that shows information and choices to the player
local UIManager = {}
UIManager.data = {}
UIManager.data.UI_STATE_NONE = "none"
UIManager.data.UI_STATE_POST_MOVE = "post_move"
UIManager.data.UI_STATE_ATTACK_PREVIEW = "attack_preview"
UIManager.data.current_state = UIManager.data.UI_STATE_NONE

UIManager.data.post_move_menu = {
    visible = false, x = 0, y = 0, width = 100, height = 60,
    options = {"Attack", "Wait"}, selected_option = 1
}

UIManager.data.unit_info = {
    visible = false, x = 540, y = 80, width = 250, height = 270,
    unit = nil, portrait = nil
}

UIManager.data.colors = {
    background = {0.1, 0.1, 0.2, 0.85}, border = {0.8, 0.8, 1, 1},
    text = {1, 1, 1, 1}, selected = {1, 1, 0, 1},
    hp_bar_bg = {0.5, 0.1, 0.1, 1}, hp_bar_fill = {0.2, 0.8, 0.2, 1}
}

-- Attack Preview State
UIManager.data.attack_preview = {
    visible = false,
    attacker = nil,
    targets = {},
    selected_index = 1,
    panel = { x = 300, y = 60, width = 260, height = 240 }
}

local weapons = require("src.entities.weapons")

function UIManager.load() end

function UIManager.show_post_move_menu(unit)
    local menu = UIManager.data.post_move_menu
    menu.x = unit.gridx * 32 + 34
    menu.y = unit.gridy * 32
    menu.visible = true
    menu.selected_option = 1
    UIManager.data.current_state = UIManager.data.UI_STATE_POST_MOVE
end

function UIManager.hide_post_move_menu()
    UIManager.data.post_move_menu.visible = false
    UIManager.data.current_state = UIManager.data.UI_STATE_NONE
end

function UIManager.show_unit_info(unit)
    local info = UIManager.data.unit_info
    info.unit = unit
    if unit.blueprint.portrait and love.filesystem.getInfo(unit.blueprint.portrait) then
        info.portrait = love.graphics.newImage(unit.blueprint.portrait)
    else
        info.portrait = nil
    end
    info.visible = true
end

function UIManager.hide_unit_info()
    local info = UIManager.data.unit_info
    info.visible = false
    info.unit = nil
    info.portrait = nil
end

-- Utility: determine a unit's current weapon (fallback to short sword)
local function get_unit_weapon(unit)
    if unit.weapon then return unit.weapon end
    -- fallback
    return weapons.short_sword
end

-- Utility: manhattan distance between two grid units
local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

-- Combat calculations (simple approximations)
function UIManager.calculate_hit(attacker, defender)
    local atk_stats = attacker.blueprint.stats or {}
    local def_stats = defender.blueprint.stats or {}
    local acc = 70 + (atk_stats.skl or 0) * 2 + math.floor((atk_stats.luk or 0) / 2)
    local eva = (def_stats.agi or 0) * 2 + (def_stats.luk or 0)
    local hit = acc - eva
    if hit < 5 then hit = 5 end
    if hit > 95 then hit = 95 end
    return hit
end

function UIManager.calculate_crit(attacker, defender)
    local atk_stats = attacker.blueprint.stats or {}
    local def_stats = defender.blueprint.stats or {}
    local base = math.floor((atk_stats.skl or 0) / 2)
    local resist = math.floor((def_stats.luk or 0) / 2)
    local crit = base - resist
    if crit < 0 then crit = 0 end
    if crit > 50 then crit = 50 end
    return crit
end

function UIManager.calculate_damage(attacker, defender)
    local weap = get_unit_weapon(attacker)
    local atk_stats = attacker.blueprint.stats or {}
    local def_stats = defender.blueprint.stats or {}
    local raw = (atk_stats.str or 0) + (weap.damage or 0)
    local damage = raw - (def_stats.def or 0)
    if damage < 0 then damage = 0 end
    return damage
end

-- Base values for showing in the unit panel when no target is selected
local function calculate_base_hit_for_unit(unit)
    local stats = unit.blueprint.stats or {}
    local hit = 70 + (stats.skl or 0) * 2 + math.floor((stats.luk or 0) / 2)
    if hit < 0 then hit = 0 end
    if hit > 100 then hit = 100 end
    return hit
end

local function calculate_base_crit_for_unit(unit)
    local stats = unit.blueprint.stats or {}
    local crit = math.floor((stats.skl or 0) / 2)
    if crit < 0 then crit = 0 end
    if crit > 100 then crit = 100 end
    return crit
end

-- Build target list in range and open preview
local function open_attack_preview(attacker)
    local UnitManager = require("src.entities.UnitManager")
    local preview = UIManager.data.attack_preview
    preview.attacker = attacker
    preview.targets = {}
    preview.selected_index = 1

    -- Hide the post-move menu when entering preview
    UIManager.data.post_move_menu.visible = false

    local weap = get_unit_weapon(attacker)
    for _, candidate in ipairs(UnitManager.data.all_units) do
        if candidate ~= attacker and candidate.allied ~= attacker.allied then
            local dist = manhattan(attacker.gridx, attacker.gridy, candidate.gridx, candidate.gridy)
            if dist <= (weap.range or 1) then
                table.insert(preview.targets, candidate)
            end
        end
    end

    if #preview.targets == 0 then
        -- No targets: keep the post-move menu open and notify
        print("No targets in range.")
        UIManager.data.current_state = UIManager.data.UI_STATE_POST_MOVE
        UIManager.data.post_move_menu.visible = true
        return
    end

    preview.visible = true
    UIManager.data.current_state = UIManager.data.UI_STATE_ATTACK_PREVIEW
end

-- Execute attack with RNG
local function execute_attack(attacker, defender)
    local UnitManager = require("src.entities.UnitManager")
    local hit = UIManager.calculate_hit(attacker, defender)
    local crit = UIManager.calculate_crit(attacker, defender)
    local damage = UIManager.calculate_damage(attacker, defender)
    local crit_multiplier = 2

    local r_hit = love.math.random(1, 100)
    local did_hit = r_hit <= hit
    local total_damage = 0
    if did_hit then
        local r_crit = love.math.random(1, 100)
        local did_crit = r_crit <= crit
        total_damage = did_crit and (damage * crit_multiplier) or damage
    end

    defender.state.hp = math.max(0, defender.state.hp - total_damage)

    -- End attacker's action
    attacker.has_acted = true
    attacker.state.turn.has_acted = true

    -- Cleanup preview and UI
    UIManager.data.attack_preview.visible = false
    UIManager.data.current_state = UIManager.data.UI_STATE_NONE

    -- Deselect after action
    UnitManager.deselect_unit()
end

function UIManager.handle_mouse_input(x, y, button)
    if button == 1 and UIManager.data.current_state == UIManager.data.UI_STATE_POST_MOVE then
        local menu = UIManager.data.post_move_menu
        if x >= menu.x and x <= menu.x + menu.width and y >= menu.y and y <= menu.y + menu.height then
            local option_height = menu.height / #menu.options
            local relative_y = y - menu.y
            local clicked_option = math.floor(relative_y / option_height) + 1
            if clicked_option >= 1 and clicked_option <= #menu.options then
                UIManager.handle_menu_selection(menu.options[clicked_option])
            end
        else
            UIManager.handle_menu_selection("Wait")
        end
    elseif UIManager.data.current_state == UIManager.data.UI_STATE_ATTACK_PREVIEW then
        if button == 2 then
            -- Right click cancels preview
            local preview = UIManager.data.attack_preview
            preview.visible = false
            UIManager.data.current_state = UIManager.data.UI_STATE_POST_MOVE
            UIManager.data.post_move_menu.visible = true
        end
    end
end

function UIManager.handle_keyboard_input(key)
    if UIManager.data.current_state == UIManager.data.UI_STATE_POST_MOVE then
        local menu = UIManager.data.post_move_menu
        if key == "up" or key == "w" then
            menu.selected_option = menu.selected_option - 1
            if menu.selected_option < 1 then menu.selected_option = #menu.options end
        elseif key == "down" or key == "s" then
            menu.selected_option = menu.selected_option + 1
            if menu.selected_option > #menu.options then menu.selected_option = 1 end
        elseif key == "return" or key == "space" then
            UIManager.handle_menu_selection(menu.options[menu.selected_option])
        elseif key == "escape" then
            UIManager.handle_menu_selection("Wait")
        end
    elseif UIManager.data.current_state == UIManager.data.UI_STATE_ATTACK_PREVIEW then
        local preview = UIManager.data.attack_preview
        if key == "left" or key == "up" or key == "w" then
            preview.selected_index = preview.selected_index - 1
            if preview.selected_index < 1 then preview.selected_index = #preview.targets end
        elseif key == "right" or key == "down" or key == "s" then
            preview.selected_index = preview.selected_index + 1
            if preview.selected_index > #preview.targets then preview.selected_index = 1 end
        elseif key == "return" or key == "space" then
            local target = preview.targets[preview.selected_index]
            if target then
                execute_attack(preview.attacker, target)
            end
        elseif key == "escape" then
            -- Cancel preview and return to post move menu
            preview.visible = false
            UIManager.data.current_state = UIManager.data.UI_STATE_POST_MOVE
            UIManager.data.post_move_menu.visible = true
        end
    end
end

function UIManager.handle_menu_selection(option)
    local UnitManager = require("src.entities.UnitManager")
    local unit = UnitManager.data.selected_unit
    if not unit then return end

    if option == "Attack" then
        -- Hide menu and open attack preview instead of instantly ending the turn
        UIManager.hide_post_move_menu()
        open_attack_preview(unit)
        return
    elseif option == "Wait" then
        unit.has_acted = true
        unit.state.turn.has_acted = true
        UIManager.hide_post_move_menu()
        UnitManager.deselect_unit()
        return
    end
end

function UIManager.draw()
    if UIManager.data.post_move_menu.visible then
        UIManager.draw_post_move_menu()
    end
    if UIManager.data.unit_info.visible then
        UIManager.draw_unit_info()
    end
    if UIManager.data.attack_preview.visible then
        UIManager.draw_attack_preview()
    end
end

function UIManager.draw_post_move_menu()
    local menu = UIManager.data.post_move_menu
    love.graphics.setColor(unpack(UIManager.data.colors.background))
    love.graphics.rectangle("fill", menu.x, menu.y, menu.width, menu.height)
    love.graphics.setColor(unpack(UIManager.data.colors.border))
    love.graphics.rectangle("line", menu.x, menu.y, menu.width, menu.height)
    
    local option_height = menu.height / #menu.options
    for i, option in ipairs(menu.options) do
        if i == menu.selected_option then
            love.graphics.setColor(unpack(UIManager.data.colors.selected))
        else
            love.graphics.setColor(unpack(UIManager.data.colors.text))
        end
        love.graphics.printf(option, menu.x, menu.y + (i - 1) * option_height + 5, menu.width, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function UIManager.draw_unit_info()
    local info = UIManager.data.unit_info
    local unit = info.unit
    if not unit then return end
    
    local x, y, w, h = info.x, info.y, info.width, info.height
    
    love.graphics.setColor(unpack(UIManager.data.colors.background))
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(unpack(UIManager.data.colors.border))
    love.graphics.rectangle("line", x, y, w, h)
    
    if info.portrait then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(info.portrait, x + 10, y + 10)
    end
    
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf(unit.blueprint.name, x + 100, y + 20, w - 110, "left")
    
    local hp_bar_x, hp_bar_y, hp_bar_w, hp_bar_h = x + 100, y + 50, 140, 20
    local hp_ratio = unit.state.hp / unit.state.max_hp
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_bg))
    love.graphics.rectangle("fill", hp_bar_x, hp_bar_y, hp_bar_w, hp_bar_h)
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_fill))
    love.graphics.rectangle("fill", hp_bar_x, hp_bar_y, hp_bar_w * hp_ratio, hp_bar_h)
    
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.setFont(love.graphics.newFont(14))
    local hp_text = unit.state.hp .. " / " .. unit.state.max_hp
    love.graphics.printf(hp_text, hp_bar_x, hp_bar_y + 2, hp_bar_w, "center")
    
    local stats_y = y + 100
    love.graphics.setFont(love.graphics.newFont(14))
    
    if unit.blueprint and unit.blueprint.stats then
        love.graphics.print("Level: " .. (unit.state.level or 'N/A'), x + 20, stats_y)
        love.graphics.print("Attack: " .. (unit.blueprint.stats.str or 'N/A'), x + 20, stats_y + 20)
        love.graphics.print("Defense: " .. (unit.blueprint.stats.def or 'N/A'), x + 20, stats_y + 40)
        love.graphics.print("Move: " .. (unit.movement_range or 'N/A'), x + 130, stats_y)
        love.graphics.print("Skill: " .. (unit.blueprint.stats.skl or 'N/A'), x + 130, stats_y + 20)
        love.graphics.print("Speed: " .. (unit.blueprint.stats.agi or 'N/A'), x + 130, stats_y + 40)
        -- New: Hit/Crit display (base values)
        local base_hit = calculate_base_hit_for_unit(unit)
        local base_crit = calculate_base_crit_for_unit(unit)
        love.graphics.print("Hit: " .. base_hit .. "%", x + 20, stats_y + 60)
        love.graphics.print("Crit: " .. base_crit .. "%", x + 130, stats_y + 60)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function UIManager.draw_attack_preview()
    local p = UIManager.data.attack_preview.panel
    local preview = UIManager.data.attack_preview
    local attacker = preview.attacker
    local target = preview.targets[preview.selected_index]
    if not attacker or not target then return end
    
    -- Calculate values
    local hit = UIManager.calculate_hit(attacker, target)
    local crit = UIManager.calculate_crit(attacker, target)
    local damage = UIManager.calculate_damage(attacker, target)
    local crit_multiplier = 2
    local expected = damage * (hit / 100) * (1 + (crit / 100) * (crit_multiplier - 1))
    local expected_enemy_hp = math.max(0, math.floor(target.state.hp - expected + 0.5))
    
    -- Counterattack estimates (if in range)
    local dist = manhattan(attacker.gridx, attacker.gridy, target.gridx, target.gridy)
    local target_weapon = get_unit_weapon(target)
    local can_counter = (target_weapon.range or 1) >= dist
    local enemy_dmg, enemy_hit, enemy_crit, expected_ally_hp
    if can_counter then
        enemy_hit = UIManager.calculate_hit(target, attacker)
        enemy_crit = UIManager.calculate_crit(target, attacker)
        enemy_dmg = UIManager.calculate_damage(target, attacker)
        local enemy_expected = enemy_dmg * (enemy_hit / 100) * (1 + (enemy_crit / 100) * (crit_multiplier - 1))
        expected_ally_hp = math.max(0, math.floor(attacker.state.hp - enemy_expected + 0.5))
    else
        enemy_hit = 0; enemy_crit = 0; enemy_dmg = 0
        expected_ally_hp = attacker.state.hp
    end
    
    love.graphics.setColor(unpack(UIManager.data.colors.background))
    love.graphics.rectangle("fill", p.x, p.y, p.width, p.height)
    love.graphics.setColor(unpack(UIManager.data.colors.border))
    love.graphics.rectangle("line", p.x, p.y, p.width, p.height)
    
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("Attack Preview", p.x, p.y + 8, p.width, "center")
    
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.print("Attacker: " .. attacker.blueprint.name, p.x + 12, p.y + 36)
    love.graphics.print("Target:   " .. target.blueprint.name, p.x + 12, p.y + 54)
    
    -- Ally HP estimated
    love.graphics.print("Ally HP:", p.x + 12, p.y + 78)
    local abar_x, abar_y, abar_w, abar_h = p.x + 12, p.y + 96, p.width - 24, 16
    local a_ratio_now = attacker.state.hp / attacker.state.max_hp
    local a_ratio_expected = expected_ally_hp / attacker.state.max_hp
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_bg))
    love.graphics.rectangle("fill", abar_x, abar_y, abar_w, abar_h)
    love.graphics.setColor(0.2, 0.6, 0.9, 1)
    love.graphics.rectangle("fill", abar_x, abar_y, abar_w * a_ratio_now, abar_h)
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.rectangle("fill", abar_x, abar_y, abar_w * a_ratio_expected, abar_h)
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.printf(attacker.state.hp .. " -> ~" .. expected_ally_hp, abar_x, abar_y - 2, abar_w, "center")
    
    -- Enemy HP estimated
    love.graphics.print("Enemy HP:", p.x + 12, p.y + 120)
    local bar_x, bar_y, bar_w, bar_h = p.x + 12, p.y + 138, p.width - 24, 16
    local ratio_now = target.state.hp / target.state.max_hp
    local ratio_expected = expected_enemy_hp / target.state.max_hp
    
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_bg))
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h)
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * ratio_now, bar_h)
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * ratio_expected, bar_h)
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.printf(target.state.hp .. " -> ~" .. expected_enemy_hp, bar_x, bar_y - 2, bar_w, "center")
    
    love.graphics.print("You   DMG:" .. damage .. "  HIT:" .. hit .. "%  CRT:" .. crit .. "%", p.x + 12, p.y + 164)
    local enemy_line = can_counter and ("Them  DMG:" .. enemy_dmg .. "  HIT:" .. enemy_hit .. "%  CRT:" .. enemy_crit .. "%") or "Them  DMG:--  HIT:--  CRT:--"
    love.graphics.print(enemy_line, p.x + 12, p.y + 184)
    
    -- Target cycling hint
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.print("Targets: " .. preview.selected_index .. "/" .. #preview.targets, p.x + 12, p.y + 206)
    love.graphics.print("Enter: Confirm  Esc/RightClick: Cancel", p.x + 12, p.y + 222)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function UIManager.is_ui_active()
    return UIManager.data.current_state ~= UIManager.data.UI_STATE_NONE
end

function UIManager.hide_attack_preview()
    UIManager.data.attack_preview.visible = false
    if UIManager.data.current_state == UIManager.data.UI_STATE_ATTACK_PREVIEW then
        UIManager.data.current_state = UIManager.data.UI_STATE_NONE
    end
end

return UIManager
