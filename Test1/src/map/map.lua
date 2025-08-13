
local Map = {}
Map.data = {}

function Map.load()
    print("Map module is loading its assets...")
    Map.data.grasstile = love.graphics.newImage("assets/images/tiles/grass.png")
end

function Map.draw()
    if Map.data.grasstile then
        local x = 1
        local y = 1
        while x < 500 do
            while y < 500 do
                love.graphics.draw(Map.data.grasstile, x, y)
                y = y + 32
            end
            x = x + 32
            y = 1
        end
    end
end

return Map

