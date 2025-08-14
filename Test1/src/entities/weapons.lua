local weapons = {
    short_sword = {
        name = "Short Sword",
        
        damage = 10,
        hit = 100,
        crit = 10,
        
        range = 1,
        min_range = 1,
        max_range = 1,
        
        weapon_type = "sword",
        type = "melee",
        rank = "E",
        weight = 1,

        --image_path = "assets/images/weapons/short_sword.png",
        description = "A short sword, a basic weapon for close combat.",

        effective = {},
        properties = {},
        uses = 50,
        price = 100,
    },

    long_sword = {
        name = "Long Sword",
        
        damage = 10,
        hit = 100,
        crit = 10,
        
        range = 1,
        min_range = 1,
        max_range = 1,
        
        weapon_type = "sword",
        type = "melee",
        rank = "D",
        weight = 1,

        --image_path = "assets/images/weapons/short_sword.png",
        description = "A long sword, a basic weapon for close combat.",

        effective = {},
        properties = {},
        uses = 50,
        price = 100,
    },

    bow = {
        name = "Bow",
        
        damage = 10,
        hit = 100,
        crit = 10,
        
        range = 2,
        min_range = 2,
        max_range = 2,
        
        weapon_type = "bow",
        type = "ranged",
        rank = "E",
        weight = 1,

        --image_path = "assets/images/weapons/short_sword.png",
        description = "A bow, a basic weapon for ranged combat.",

        effective = {},
        properties = {},
        uses = 50,
        price = 100,
    },
}

return weapons