local unit_stats = {
    -- The "heroine" blueprint
    heroine = {
        blueprint = {
            id = "heroine",
            name = "Heroine",
            image_path = "assets/images/units/heroine.png",
            portrait = "assets/images/portraits/heroine.png",
      
            class = { id = "fighter", tier = 1, tags = {"infantry","light"}, move_type = "ground" },
      
            -- Base attributes (consider adding vit/skl)
            stats = {
                level=1,
                str=10,
                int=10,
                agi=10,
                vit=10,
                skl=10,
                mnd=10,
                luk=10,
                cha=8,
                def=10,
                spi=10
            },
      
            caps = { 
                hp=60, 
                str=30, 
                int=30, 
                agi=30, 
                vit=30, 
                skl=30, 
                mnd=30, 
                luk=30, 
                cha=30, 
                def=30, 
                spi=30 
            },
      
            growths = { 
                hp=70, 
                str=55, 
                int=25, 
                agi=40, 
                vit=35, 
                skl=45, 
                mnd=30, 
                luk=20, 
                cha=20, 
                def=20, 
                spi=20 
            },
      
            proficiencies = { sword="C", lance="D", bow="E", tome="E" },
      
            elements = { fire=0, ice=0, lightning=0, holy=0, dark=0 },
            status_res = { poison=5, sleep=0, stun=0, charm=0, bleed=0, burn=0 },
      
            signature = { id="heroine_rally", type="active" },
      
            learnset = {
              [3] = {"PowerStrike"},
              [5] = {"SecondWind"},
              [10] = {"Promotion:Vanguard"}
            }
          },
      
          -- B) LOADOUT (persists between battles)
          loadout = {
            gold = 0,
            inventory = { capacity = 10, items = {} },
            equipment = { weapon = "long_sword", armor = nil }  -- Equipped with long sword
          },
      
          -- C) RUNTIME STATE (map/battle)
          state = {
            faction = "player",
            pos = { x = 0, y = 0, facing = "S" },
            movement = 5,
            turn = { has_moved = false, has_acted = false, ap = 1, ct = 0 },
      
            level = 1, exp = 0,
      
            -- Resources (store current + max for hp/mp/focus; max can be recomputed on level up/equip change)
            hp = 20, max_hp = 20,
            mp = 0,  max_mp = 0,
      
            statuses = {},   -- e.g., { poison={turns=2, power=3} }
            buffs = {},      -- e.g., { atk={+2, turns=2} }
            debuffs = {},    -- e.g., { def={-3, turns=1} }
            cooldowns = {}   -- e.g., { PowerStrike=2 }
      
            -- Optional visibility/ZOC/fog-of-war hooks
            ,vision = 5
            ,zoc = true
          },
      
          -- D) DERIVED (computed, not saved permanently)
          derived = {
            -- Fill at runtime: atk, matk, def, res, acc, eva, crit, crit_dmg, pen, range_min, range_max, weight, mov
          }
    },
    
    enemy_bandit = {
        blueprint = {
            id = "enemy_bandit",
            name = "Bandit",
            image_path = "assets/images/units/enemy_bandit.png",
            class = { id="raider", tier=1, tags={"infantry"}, move_type="ground" },
            stats = {
                level=1,
                str=10,
                int=10,
                agi=10,
                vit=10,
                skl=10,
                mnd=10,
                luk=10,
                cha=8,
                def=10,
                spi=10
            },
            proficiencies = { sword="D", axe="C" },
            elements = { fire=0, ice=0, lightning=0, holy=0, dark=0 },
            status_res = { poison=0, sleep=0, stun=0, charm=0 },
            signature = { id="raider_rush", type="active" },
            learnset = {}
        },
        loadout = {
            inventory = { capacity = 3, items = {} },
            equipment = { weapon = "iron_axe", armor = nil }  -- Equipped with iron axe
        },
        state = {
            faction = "enemy",
            pos = { x=8, y=8, facing="W" },
            movement = 2,
            turn = { has_moved=false, has_acted=false, ap=1, ct=0 },
            level=1, exp=0,
            hp=18, max_hp=18,
            mp=0, max_mp=0,
            statuses = {}, buffs = {}, debuffs = {}, cooldowns = {},
            vision = 4, zoc = true,
            rewards = { xp=20, gold=15, drops={ {id="Herb",p=35} } },
            ai = { behavior="aggressive", leash=6, target="lowest_def" }
        },
        derived = { }
    }
}

return unit_stats