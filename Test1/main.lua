function love.load()
  Map = require("src.map.map")
  Map.load()
  UnitManager = require("src.entities.UnitManager")
  UnitManager.load()
  Gamestate = require("src.gamestate.gamestate")
  Gamestate.load()
  UIManager = require("src.systems.uimanager")
  UIManager.load()
end

function love.update(dt)
  Gamestate.update(dt)
end

function love.keypressed(key)
  Gamestate.handle_input(key)
  UIManager.handle_keyboard_input(key)
end

function love.mousepressed(x, y, button)
  if UIManager.is_ui_active() then
    UIManager.handle_mouse_input(x, y, button)
    return
  end
  
  if button == 1 then -- Left Click
    if UnitManager.data.selected_unit then
      UnitManager.move_selected_unit_to(x, y)
    else
      UnitManager.select_unit_at(x, y)
    end
  elseif button == 2 then -- *** NEW: Right Click is now a universal "cancel" button ***
    if UnitManager.data.selected_unit then
        UnitManager.deselect_unit()
    end
  end
end

function love.draw()
  Map.draw()
  UnitManager.draw()
  Gamestate.draw()
  UIManager.draw()
end
