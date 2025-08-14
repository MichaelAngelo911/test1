-- UIManager.lua - This is the dedicated interface department for your game
-- It handles all visual elements that are not part of the game world itself
-- Think of it as the "presentation layer" that shows information and choices to the player
local UIManager = {}
UIManager.data = {}
UIManager.data.UI_STATE_NONE = "none"
UIManager.data.UI_STATE_POST_MOVE = "post_move"
UIManager.data.UI_STATE_TARGET_SELECT = "target_select"
UIManager.data.UI_STATE_BATTLE_PREVIEW = "battle_preview"
UIManager.data.current_state = UIManager.data.UI_STATE_NONE

UIManager.data.post_move_menu = {
    visible = false, x = 0, y = 0, width = 100, height = 60,
    options = {"Attack", "Wait"}, selected_option = 1
}

UIManager.data.unit_info = {
    visible = false, x = 540, y = 80, width = 250, height = 250,
    unit = nil, portrait = nil
}

UIManager.data.battle_preview = {
    visible = false,
    x = 200, y = 100, width = 400, height = 400,
    attacker = nil,
    defender = nil,
    preview_data = nil,
    confirmed = false
}

UIManager.data.target_selection = {
    active = false,
    attacker = nil,
    valid_targets = {},
    selected_target = nil,
    attack_range_tiles = {}
}

UIManager.data.colors = {
    background = {0.1, 0.1, 0.2, 0.85}, border = {0.8, 0.8, 1, 1},
    text = {1, 1, 1, 1}, selected = {1, 1, 0, 1},
    hp_bar_bg = {0.5, 0.1, 0.1, 1}, hp_bar_fill = {0.2, 0.8, 0.2, 1},
    hit_color = {0.2, 0.8, 0.2, 1}, crit_color = {1, 0.8, 0, 1},
    damage_color = {1, 0.2, 0.2, 1}
}

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

function UIManager.start_target_selection(attacker)
    local CombatManager = require("src.systems.CombatManager")
    local UnitManager = require("src.entities.UnitManager")
    
    UIManager.data.target_selection.attacker = attacker
    UIManager.data.target_selection.active = true
    UIManager.data.target_selection.valid_targets = CombatManager.get_enemies_in_range(attacker)
    UIManager.data.target_selection.selected_target = nil
    
    -- Calculate attack range tiles for visualization
    local weapon = CombatManager.get_equipped_weapon(attacker)
    local range = weapon and weapon.range or 1
    UIManager.data.target_selection.attack_range_tiles = {}
    
    for x = attacker.gridx - range, attacker.gridx + range do
        for y = attacker.gridy - range, attacker.gridy + range do
            local distance = math.abs(x - attacker.gridx) + math.abs(y - attacker.gridy)
            if distance <= range and x >= 0 and x <= 15 and y >= 0 and y <= 15 then
                table.insert(UIManager.data.target_selection.attack_range_tiles, {x = x, y = y})
            end
        end
    end
    
    UIManager.data.current_state = UIManager.data.UI_STATE_TARGET_SELECT
    
    -- If there's only one valid target, auto-select it
    if #UIManager.data.target_selection.valid_targets == 1 then
        UIManager.select_target(UIManager.data.target_selection.valid_targets[1])
    elseif #UIManager.data.target_selection.valid_targets == 0 then
        print("No enemies in range!")
        UIManager.cancel_target_selection()
    end
end

function UIManager.select_target(target)
    UIManager.data.target_selection.selected_target = target
    UIManager.show_battle_preview(UIManager.data.target_selection.attacker, target)
end

function UIManager.cancel_target_selection()
    UIManager.data.target_selection.active = false
    UIManager.data.target_selection.attacker = nil
    UIManager.data.target_selection.valid_targets = {}
    UIManager.data.target_selection.selected_target = nil
    UIManager.data.target_selection.attack_range_tiles = {}
    UIManager.data.current_state = UIManager.data.UI_STATE_POST_MOVE
end

function UIManager.show_battle_preview(attacker, defender)
    local CombatManager = require("src.systems.CombatManager")
    
    local preview = UIManager.data.battle_preview
    preview.attacker = attacker
    preview.defender = defender
    preview.preview_data = CombatManager.calculate_battle_preview(attacker, defender)
    preview.visible = true
    preview.confirmed = false
    
    UIManager.data.current_state = UIManager.data.UI_STATE_BATTLE_PREVIEW
end

function UIManager.hide_battle_preview()
    local preview = UIManager.data.battle_preview
    preview.visible = false
    preview.attacker = nil
    preview.defender = nil
    preview.preview_data = nil
    preview.confirmed = false
    
    -- Go back to target selection
    if UIManager.data.target_selection.active then
        UIManager.data.current_state = UIManager.data.UI_STATE_TARGET_SELECT
    else
        UIManager.data.current_state = UIManager.data.UI_STATE_NONE
    end
end

function UIManager.confirm_battle()
    local CombatManager = require("src.systems.CombatManager")
    local preview = UIManager.data.battle_preview
    
    if preview.attacker and preview.defender then
        -- Execute the actual combat
        local battle_log = CombatManager.execute_combat(preview.attacker, preview.defender)
        
        -- Print battle results to console (you can enhance this later)
        for _, round in ipairs(battle_log.rounds) do
            if round.hit then
                local crit_text = round.critical and " (CRITICAL!)" or ""
                local counter_text = round.is_counter and " (Counter)" or ""
                local double_text = round.is_double and " (Double)" or ""
                print(round.attacker .. " attacks " .. round.defender .. " for " .. round.damage .. " damage!" .. crit_text .. counter_text .. double_text)
            else
                local counter_text = round.is_counter and " (Counter)" or ""
                print(round.attacker .. " misses!" .. counter_text)
            end
        end
        
        -- Check for defeated units
        if battle_log.defender_defeated then
            print(preview.defender.blueprint.name .. " was defeated!")
            -- Remove defeated unit from the game
            local UnitManager = require("src.entities.UnitManager")
            for i, unit in ipairs(UnitManager.data.all_units) do
                if unit == preview.defender then
                    table.remove(UnitManager.data.all_units, i)
                    break
                end
            end
        end
        
        if battle_log.attacker_defeated then
            print(preview.attacker.blueprint.name .. " was defeated!")
            -- Remove defeated unit from the game
            local UnitManager = require("src.entities.UnitManager")
            for i, unit in ipairs(UnitManager.data.all_units) do
                if unit == preview.attacker then
                    table.remove(UnitManager.data.all_units, i)
                    break
                end
            end
        end
        
        -- Mark attacker as having acted
        preview.attacker.has_acted = true
        preview.attacker.state.turn.has_acted = true
    end
    
    -- Clean up UI
    UIManager.hide_battle_preview()
    UIManager.data.target_selection.active = false
    UIManager.data.target_selection.attacker = nil
    UIManager.data.target_selection.valid_targets = {}
    UIManager.data.target_selection.selected_target = nil
    UIManager.data.target_selection.attack_range_tiles = {}
    
    local UnitManager = require("src.entities.UnitManager")
    UnitManager.deselect_unit()
end

function UIManager.handle_mouse_input(x, y, button)
    if button == 1 then
        if UIManager.data.current_state == UIManager.data.UI_STATE_POST_MOVE then
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
        elseif UIManager.data.current_state == UIManager.data.UI_STATE_TARGET_SELECT then
            -- Check if clicking on a valid target
            local clicked_grid_x = math.floor(x / 32)
            local clicked_grid_y = math.floor(y / 32)
            
            for _, target in ipairs(UIManager.data.target_selection.valid_targets) do
                if target.gridx == clicked_grid_x and target.gridy == clicked_grid_y then
                    UIManager.select_target(target)
                    return
                end
            end
        elseif UIManager.data.current_state == UIManager.data.UI_STATE_BATTLE_PREVIEW then
            -- Battle preview is shown, clicking confirms the attack
            UIManager.confirm_battle()
        end
    elseif button == 2 then
        -- Right click cancels current action
        if UIManager.data.current_state == UIManager.data.UI_STATE_BATTLE_PREVIEW then
            UIManager.hide_battle_preview()
        elseif UIManager.data.current_state == UIManager.data.UI_STATE_TARGET_SELECT then
            UIManager.cancel_target_selection()
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
    elseif UIManager.data.current_state == UIManager.data.UI_STATE_BATTLE_PREVIEW then
        if key == "return" or key == "space" then
            UIManager.confirm_battle()
        elseif key == "escape" then
            UIManager.hide_battle_preview()
        end
    elseif UIManager.data.current_state == UIManager.data.UI_STATE_TARGET_SELECT then
        if key == "escape" then
            UIManager.cancel_target_selection()
        end
    end
end

function UIManager.handle_menu_selection(option)
    UIManager.hide_post_move_menu()
    local UnitManager = require("src.entities.UnitManager")
    local unit = UnitManager.data.selected_unit
    if not unit then return end

    if option == "Attack" then
        UIManager.start_target_selection(unit)
        return  -- Don't deselect unit yet
    end
    
    unit.has_acted = true
    unit.state.turn.has_acted = true
    UnitManager.deselect_unit()
end

function UIManager.draw()
    -- Draw attack range if in target selection mode
    if UIManager.data.target_selection.active then
        UIManager.draw_attack_range()
        UIManager.draw_valid_targets()
    end
    
    if UIManager.data.post_move_menu.visible then
        UIManager.draw_post_move_menu()
    end
    if UIManager.data.unit_info.visible then
        UIManager.draw_unit_info()
    end
    if UIManager.data.battle_preview.visible then
        UIManager.draw_battle_preview()
    end
end

function UIManager.draw_attack_range()
    love.graphics.setColor(1, 0.2, 0.2, 0.2)
    for _, tile in ipairs(UIManager.data.target_selection.attack_range_tiles) do
        love.graphics.rectangle("fill", tile.x * 32, tile.y * 32, 32, 32)
    end
end

function UIManager.draw_valid_targets()
    love.graphics.setColor(1, 0, 0, 0.5)
    for _, target in ipairs(UIManager.data.target_selection.valid_targets) do
        love.graphics.rectangle("fill", target.gridx * 32, target.gridy * 32, 32, 32)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", target.gridx * 32, target.gridy * 32, 32, 32)
    end
    love.graphics.setLineWidth(1)
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
        
        -- Add weapon info and combat stats
        local CombatManager = require("src.systems.CombatManager")
        local weapon = CombatManager.get_equipped_weapon(unit)
        if weapon then
            love.graphics.print("Weapon: " .. weapon.name, x + 20, stats_y + 70)
            love.graphics.print("Dmg: " .. weapon.damage .. " Rng: " .. weapon.range, x + 20, stats_y + 90)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function UIManager.draw_battle_preview()
    local preview = UIManager.data.battle_preview
    local data = preview.preview_data
    if not data then return end
    
    local x, y, w, h = preview.x, preview.y, preview.width, preview.height
    
    -- Background
    love.graphics.setColor(unpack(UIManager.data.colors.background))
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(unpack(UIManager.data.colors.border))
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
    
    -- Title
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf("BATTLE PREVIEW", x, y + 10, w, "center")
    
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Attacker side (left)
    local att_x = x + 20
    local att_y = y + 50
    
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.print(data.attacker.unit.blueprint.name, att_x, att_y)
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    
    -- Attacker HP bar
    local hp_bar_y = att_y + 25
    local hp_ratio = data.attacker.unit.state.hp / data.attacker.unit.state.max_hp
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_bg))
    love.graphics.rectangle("fill", att_x, hp_bar_y, 150, 15)
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_fill))
    love.graphics.rectangle("fill", att_x, hp_bar_y, 150 * hp_ratio, 15)
    
    -- Current HP
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.print("HP: " .. data.attacker.unit.state.hp .. "/" .. data.attacker.unit.state.max_hp, att_x, hp_bar_y + 20)
    
    -- Predicted HP
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("→ " .. data.attacker.predicted_hp, att_x + 100, hp_bar_y + 20)
    
    -- Attacker combat stats
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.print("Damage: " .. data.attacker.damage, att_x, hp_bar_y + 45)
    
    love.graphics.setColor(unpack(UIManager.data.colors.hit_color))
    love.graphics.print("Hit: " .. math.floor(data.attacker.hit_chance) .. "%", att_x, hp_bar_y + 65)
    
    love.graphics.setColor(unpack(UIManager.data.colors.crit_color))
    love.graphics.print("Crit: " .. math.floor(data.attacker.crit_chance) .. "%", att_x, hp_bar_y + 85)
    
    if data.attacker.double_attack then
        love.graphics.setColor(0, 1, 1, 1)
        love.graphics.print("x2 Attack!", att_x, hp_bar_y + 105)
    end
    
    -- Defender side (right)
    local def_x = x + 220
    local def_y = y + 50
    
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.print(data.defender.unit.blueprint.name, def_x, def_y)
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    
    -- Defender HP bar
    hp_bar_y = def_y + 25
    hp_ratio = data.defender.unit.state.hp / data.defender.unit.state.max_hp
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_bg))
    love.graphics.rectangle("fill", def_x, hp_bar_y, 150, 15)
    love.graphics.setColor(unpack(UIManager.data.colors.hp_bar_fill))
    love.graphics.rectangle("fill", def_x, hp_bar_y, 150 * hp_ratio, 15)
    
    -- Current HP
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.print("HP: " .. data.defender.unit.state.hp .. "/" .. data.defender.unit.state.max_hp, def_x, hp_bar_y + 20)
    
    -- Predicted HP
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("→ " .. data.defender.predicted_hp, def_x + 100, hp_bar_y + 20)
    
    -- Defender combat stats (if can counter)
    if data.defender.can_counter then
        love.graphics.setColor(unpack(UIManager.data.colors.text))
        love.graphics.print("Damage: " .. data.defender.damage, def_x, hp_bar_y + 45)
        
        love.graphics.setColor(unpack(UIManager.data.colors.hit_color))
        love.graphics.print("Hit: " .. math.floor(data.defender.hit_chance) .. "%", def_x, hp_bar_y + 65)
        
        love.graphics.setColor(unpack(UIManager.data.colors.crit_color))
        love.graphics.print("Crit: " .. math.floor(data.defender.crit_chance) .. "%", def_x, hp_bar_y + 85)
        
        if data.defender.double_attack then
            love.graphics.setColor(0, 1, 1, 1)
            love.graphics.print("x2 Attack!", def_x, hp_bar_y + 105)
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.print("Cannot counter", def_x, hp_bar_y + 45)
    end
    
    -- VS text in the middle
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("VS", x, y + 120, w, "center")
    
    -- Instructions
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.setColor(unpack(UIManager.data.colors.selected))
    love.graphics.printf("Click or press ENTER to confirm attack", x, y + h - 60, w, "center")
    love.graphics.printf("Right-click or press ESC to cancel", x, y + h - 40, w, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

function UIManager.is_ui_active()
    return UIManager.data.current_state ~= UIManager.data.UI_STATE_NONE
end

return UIManager
