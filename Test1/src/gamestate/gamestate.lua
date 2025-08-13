-- Gamestate.lua - This file manages the overall game state and turn system
-- Think of this as the "brain" of your game that keeps track of whose turn it is
-- and what phase of the game we're currently in

local Gamestate = {}

-- This is where we store all the important game data
-- Think of this like a filing cabinet where we keep all our game information
Gamestate.data = {}

-- Game phases - these are like different "modes" your game can be in
-- PLAYER_PHASE = it's the player's turn to move units
-- ENEMY_PHASE = it's the enemy's turn to move units
-- MENU_PHASE = player is in a menu (like selecting items or units)
Gamestate.data.PLAYER_PHASE = "player_phase"
Gamestate.data.ENEMY_PHASE = "enemy_phase"
Gamestate.data.MENU_PHASE = "menu_phase"

-- Current phase - this tells us what phase we're currently in
-- We start with the player's turn
Gamestate.data.current_phase = "player_phase"

-- Turn counter - keeps track of how many turns have passed
-- This is useful for things like "this unit gets stronger every 5 turns"
Gamestate.data.turn_number = 1

-- Function to initialize/start the gamestate
-- This is like setting up the game board before you start playing
function Gamestate.load()
    print("Gamestate is loading...")
    
    -- Reset everything to starting values
    Gamestate.data.current_phase = Gamestate.data.PLAYER_PHASE
    Gamestate.data.turn_number = 1
    
    print("Gamestate loaded! Starting with player phase, turn " .. Gamestate.data.turn_number)
end

-- Function to update the gamestate every frame
-- This runs constantly while the game is running
-- 'dt' stands for "delta time" - it's how much time has passed since the last frame
function Gamestate.update(dt)
    -- We no longer need automatic phase switching, so this function is mostly empty
    -- But we keep it in case we want to add other time-based features later
end

-- Function to handle keyboard input for phase control
-- This is where we check for the E key to end the current phase
function Gamestate.handle_input(key)
    -- Check if the E key was pressed to end the current phase
    if key == "e" or key == "E" then
        Gamestate.switch_phase()
    end
end

-- Function to switch from one phase to another
-- This is like passing the controller to the other player
function Gamestate.switch_phase()
    print("Switching phases...")
    
    -- NEW: Automatically deselect any unit when the phase changes.
    -- We need to require the UnitManager to talk to it.
    local UnitManager = require("src.entities.UnitManager")
    UnitManager.data.selected_unit = nil
    UnitManager.data.show_movement_range = false -- Also hide the range

    -- If we're currently in player phase, switch to enemy phase
    if Gamestate.data.current_phase == Gamestate.data.PLAYER_PHASE then
        Gamestate.data.current_phase = Gamestate.data.ENEMY_PHASE
        print("Switched to ENEMY PHASE")
        
        -- Here we'll later add code to make the enemy units move
        -- For now, we'll just print a message
        print("Enemy is thinking...")
        
    -- If we're currently in enemy phase, switch back to player phase
    elseif Gamestate.data.current_phase == Gamestate.data.ENEMY_PHASE then
        Gamestate.data.current_phase = Gamestate.data.PLAYER_PHASE
        Gamestate.data.turn_number = Gamestate.data.turn_number + 1
        print("Switched to PLAYER PHASE - Turn " .. Gamestate.data.turn_number)
        
        -- Reset the has_acted flag for all allied units so they can act again
        for _, unit in ipairs(UnitManager.data.all_units) do
            if unit.allied then
                unit.has_acted = false
                unit.state.turn.has_acted = false
                print("Reset has_acted flag for allied unit")
            end
        end
        
        -- Here we'll later add code to refresh player units (like healing, status effects, etc.)
        print("Player's turn! Units refreshed.")
    end
end

-- Function to draw the current game state information
-- This will show the player what phase they're in and what turn it is
function Gamestate.draw()
    -- Set the color for our text (white)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw the current phase at the top of the screen
    love.graphics.print("Phase: " .. Gamestate.data.current_phase, 550, 10)
    
    -- Draw the turn number
    love.graphics.print("Turn: " .. Gamestate.data.turn_number, 550, 30)
    
    -- Draw instructions for ending the phase
    if Gamestate.data.current_phase == Gamestate.data.PLAYER_PHASE then
        love.graphics.print("Press E to end player phase", 550, 50)
    else
        love.graphics.print("Press E to end enemy phase", 550, 50)
    end
end

-- Function to get the current phase (useful for other parts of the game)
function Gamestate.get_current_phase()
    return Gamestate.data.current_phase
end

-- Function to check if it's currently the player's turn
function Gamestate.is_player_phase()
    return Gamestate.data.current_phase == Gamestate.data.PLAYER_PHASE
end

-- Function to check if it's currently the enemy's turn
function Gamestate.is_enemy_phase()
    return Gamestate.data.current_phase == Gamestate.data.ENEMY_PHASE
end

-- Function to manually switch to a specific phase (useful for testing)
function Gamestate.set_phase(phase)
    if phase == Gamestate.data.PLAYER_PHASE or 
       phase == Gamestate.data.ENEMY_PHASE or 
       phase == Gamestate.data.MENU_PHASE then
        Gamestate.data.current_phase = phase
        print("Manually switched to: " .. phase)
    else
        print("Invalid phase: " .. phase)
    end
end


-- Return the Gamestate module so other files can use it
return Gamestate
