local weapons = {
    short_sword = {
        name = "Short Sword",
        damage = 10,
        range = 1,
        hit = 95,    -- Hit chance modifier
        crit = 5,    -- Critical chance modifier
        weight = 5,  -- Affects speed calculations
    },
    long_sword = {
        name = "Long Sword",
        damage = 15,
        range = 1,
        hit = 85,    -- Slightly less accurate but more damage
        crit = 10,   -- Higher crit chance
        weight = 8,
    },
    bow = {
        name = "Bow",
        damage = 12,
        range = 2,
        hit = 90,    -- Good accuracy at range
        crit = 8,    -- Decent crit chance
        weight = 6,
    },
    iron_axe = {
        name = "Iron Axe",
        damage = 18,
        range = 1,
        hit = 75,    -- Lower accuracy but high damage
        crit = 3,    -- Low crit chance
        weight = 10,
    },
    thunder_tome = {
        name = "Thunder Tome",
        damage = 14,
        range = 2,
        hit = 80,    -- Magic accuracy
        crit = 15,   -- High crit for magic
        weight = 4,
    },
}

return weapons
