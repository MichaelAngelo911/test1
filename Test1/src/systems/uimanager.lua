-- UIManager.lua - This is the dedicated interface department for your game
-- It handles all visual elements that are not part of the game world itself
-- Think of it as the "presentation layer" that shows information and choices to the player
local UIManager = {}
UIManager.data = {}
UIManager.data.UI_STATE_NONE = "none"
UIManager.data.UI_STATE_POST_MOVE = "post_move"
UIManager.data.current_state = UIManager.data.UI_STATE_NONE

UIManager.data.post_move_menu = {
    visible = false, x = 0, y = 0, width = 100, height = 60,
    options = {"Attack", "Wait"}, selected_option = 1
}

UIManager.data.unit_info = {
    visible = false, x = 540, y = 80, width = 250, height = 250,
    unit = nil, portrait = nil
}

UIManager.data.colors = {
    background = {0.1, 0.1, 0.2, 0.85}, border = {0.8, 0.8, 1, 1},
    text = {1, 1, 1, 1}, selected = {1, 1, 0, 1},
    hp_bar_bg = {0.5, 0.1, 0.1, 1}, hp_bar_fill = {0.2, 0.8, 0.2, 1}
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

function UIManager.handle_mouse_input(x, y, button)
    local BattleSystem = require("src.systems.battlesystem")
    if BattleSystem.data.state == "target_select" then
        BattleSystem.handle_mouse_input(x, y, button)
        return
    end
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
            local UnitManager = require("src.entities.UnitManager")
            UnitManager.cancel_post_move()
        end
    end
end

function UIManager.handle_keyboard_input(key)
    local BattleSystem = require("src.systems.battlesystem")
    if BattleSystem.data.state == "target_select" then
        BattleSystem.handle_keyboard_input(key)
        return
    end
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
            local UnitManager = require("src.entities.UnitManager")
            UnitManager.cancel_post_move()
        end
    end
end

function UIManager.handle_menu_selection(option)
    UIManager.hide_post_move_menu()
    local UnitManager = require("src.entities.UnitManager")
    local unit = UnitManager.data.selected_unit
    if not unit then return end

    UnitManager.commit_post_move()
    if option == "Attack" then
        local BattleSystem = require("src.systems.battlesystem")
        BattleSystem.begin_target_select(unit)
        return
    end
    
    
    unit.has_acted = true
    unit.state.turn.has_acted = true
    UnitManager.deselect_unit()
end

function UIManager.draw()
    if UIManager.data.post_move_menu.visible then
        UIManager.draw_post_move_menu()
    end

    if UIManager.data.unit_info.visible then
        UIManager.draw_unit_info()
    end

    local BattleSystem = require("src.systems.battlesystem")
    if BattleSystem.data.state == "target_select" then
        BattleSystem.draw()
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
        love.graphics.draw(info.portrait, x + 10, y + 10, 0, 0.75, 0.75)
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", x + 10, y + 10, 80, 80)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", x + 10, y + 10, 80, 80)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("No portrait", x + 15, y + 45)
    end
    
    love.graphics.setColor(unpack(UIManager.data.colors.text))
    love.graphics.setFont(love.graphics.newFont(18))
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
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function UIManager.is_ui_active()
    -- Check if any UI system is active (post-move menu, unit info, or battle target selection/preview)
    local BattleSystem = require("src.systems.battlesystem")
    return UIManager.data.current_state ~= UIManager.data.UI_STATE_NONE or 
           BattleSystem.data.state == "target_select" or
           BattleSystem.data.state == "preview"
end

return UIManager
