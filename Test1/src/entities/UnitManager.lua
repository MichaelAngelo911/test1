local UnitManager = {}
UnitManager.data = {}
UnitManager.data.selected_unit = nil
UnitManager.data.valid_movement_tiles = {}
UnitManager.data.show_movement_range = false

function UnitManager.new(unit_type)
    local unit_data = UnitManager.data.unit_data[unit_type]
    if not unit_data then return nil end
    local new_unit = {}
    local blueprint = unit_data.blueprint
    local state = unit_data.state
    new_unit.gridx = state.pos.x
    new_unit.gridy = state.pos.y
    new_unit.movement_range = state.movement
    new_unit.allied = (state.faction == "player")
    new_unit.has_acted = state.turn.has_acted
    new_unit.image = love.graphics.newImage(blueprint.image_path)
    new_unit.blueprint = blueprint
    new_unit.state = state
    return new_unit
end

function UnitManager.load()
    UnitManager.data.unit_data = require("src.entities.unit_stats")
    UnitManager.data.all_units = {}
    local heroine_unit = UnitManager.new("heroine")
    local enemy_unit = UnitManager.new("enemy_bandit")
    table.insert(UnitManager.data.all_units, heroine_unit)
    table.insert(UnitManager.data.all_units, enemy_unit)
end

function UnitManager.calculate_movement_range(unit)
    UnitManager.data.valid_movement_tiles = {}
    if unit.movement_range <= 0 then return end
    local start_x, start_y, range = unit.gridx, unit.gridy, unit.movement_range
    for x = start_x - range, start_x + range do
        for y = start_y - range, start_y + range do
            local distance = math.abs(x - start_x) + math.abs(y - start_y)
            if distance <= range and x >= 0 and x <= 15 and y >= 0 and y <= 15 then
                local tile_occupied = false
                for _, other_unit in ipairs(UnitManager.data.all_units) do
                    if other_unit.gridx == x and other_unit.gridy == y then
                        tile_occupied = true
                        break
                    end
                end
                if not tile_occupied then
                    table.insert(UnitManager.data.valid_movement_tiles, {x = x, y = y})
                end
            end
        end
    end
end

function UnitManager.is_valid_movement_tile(grid_x, grid_y)
    for _, tile in ipairs(UnitManager.data.valid_movement_tiles) do
        if tile.x == grid_x and tile.y == grid_y then
            return true
        end
    end
    return false
end

function UnitManager.select_unit_at(pixel_x, pixel_y)
    local clicked_grid_x = math.floor(pixel_x / 32)
    local clicked_grid_y = math.floor(pixel_y / 32)
    local UIManager = require("src.systems.uimanager")

    local found_unit = nil
    for _, unit in ipairs(UnitManager.data.all_units) do
        if unit.gridx == clicked_grid_x and unit.gridy == clicked_grid_y then
            found_unit = unit
            break
        end
    end
    
    if found_unit == UnitManager.data.selected_unit then
        UnitManager.data.selected_unit = nil
        UnitManager.data.show_movement_range = false
        UIManager.hide_unit_info()
        return
    end
    
    UnitManager.data.selected_unit = found_unit
    
    if found_unit then
        UIManager.show_unit_info(found_unit)
        if found_unit.has_acted or found_unit.state.turn.has_acted then
            UnitManager.data.selected_unit = nil
            return
        end
        local Gamestate = require("src.gamestate.gamestate")
        if Gamestate.is_player_phase() and found_unit.allied then
            UnitManager.calculate_movement_range(found_unit)
            UnitManager.data.show_movement_range = true
        else
            UnitManager.data.show_movement_range = false
        end
    else
        UnitManager.data.show_movement_range = false
        UIManager.hide_unit_info()
    end
end

function UnitManager.move_selected_unit_to(pixel_x, pixel_y)
    local clicked_grid_x = math.floor(pixel_x / 32)
    local clicked_grid_y = math.floor(pixel_y / 32)
    local unit_to_move = UnitManager.data.selected_unit
    local Gamestate = require("src.gamestate.gamestate")
    local UIManager = require("src.systems.uimanager")

    if not Gamestate.is_player_phase() or not unit_to_move.allied then
        -- If trying to move an enemy, just deselect them.
        UnitManager.data.selected_unit = nil
        UIManager.hide_unit_info()
        return
    end
    
    if UnitManager.is_valid_movement_tile(clicked_grid_x, clicked_grid_y) then
        unit_to_move.gridx = clicked_grid_x
        unit_to_move.gridy = clicked_grid_y
        unit_to_move.state.pos.x = clicked_grid_x
        unit_to_move.state.pos.y = clicked_grid_y
        UnitManager.data.show_movement_range = false
        UnitManager.data.valid_movement_tiles = {}
        UIManager.show_post_move_menu(unit_to_move)
    else
        -- If the move is invalid (e.g., out of range), deselect the unit.
        print("Cannot move to invalid tile.")
        UnitManager.data.selected_unit = nil
        UnitManager.data.show_movement_range = false
        UIManager.hide_unit_info()
    end
end

-- Deselect the currently selected unit and clear related UI state
function UnitManager.deselect_unit()
    local UIManager = require("src.systems.uimanager")
    UnitManager.data.selected_unit = nil
    UnitManager.data.show_movement_range = false
    UnitManager.data.valid_movement_tiles = {}
    UIManager.hide_unit_info()
    UIManager.hide_post_move_menu()
end

function UnitManager.draw()
    if UnitManager.data.show_movement_range then
        love.graphics.setColor(0, 0, 1, 0.3)
        for _, tile in ipairs(UnitManager.data.valid_movement_tiles) do
            love.graphics.rectangle("fill", tile.x * 32, tile.y * 32, 32, 32)
        end
    end
    
    for _, current_unit in ipairs(UnitManager.data.all_units) do
        if current_unit == UnitManager.data.selected_unit then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.rectangle("fill", current_unit.gridx * 32, current_unit.gridy * 32, 32, 32)
        end
        
        if current_unit.allied then love.graphics.setColor(0, 1, 0, 0.8)
        else love.graphics.setColor(1, 0, 0, 0.8) end
        love.graphics.rectangle("line", current_unit.gridx * 32, current_unit.gridy * 32, 32, 32)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(current_unit.image, current_unit.gridx * 32, current_unit.gridy * 32)
    end
end

return UnitManager
