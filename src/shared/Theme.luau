-- COLD CASE · the only place UI colours and fonts are defined.
-- Handbook rule: two fonts in the whole game, one colour per role.
local Theme = {}

-- Big Shoulders Display and IBM Plex Mono are not on the Creator Store.
-- Oswald is the closest built-in condensed display face; RobotoMono stands in
-- for Plex Mono. Upload the real faces and swap these two lines.
Theme.DISPLAY = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
Theme.DISPLAY_HEAVY = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
Theme.MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

Theme.INK = Color3.fromHex("e8e6e1")
Theme.BODY = Color3.fromHex("c3c8ce")
Theme.SOFT = Color3.fromHex("a9afb7")
Theme.MUTED = Color3.fromHex("8b9199")
Theme.DIM = Color3.fromHex("6f7883")
Theme.GROUND = Color3.fromHex("0b0d10")
Theme.PANEL = Color3.fromHex("12151a")
Theme.CARD = Color3.fromHex("111419")
Theme.STROKE = Color3.fromHex("262d36")
Theme.AMBER = Color3.fromHex("f2a63b")
Theme.CYAN = Color3.fromHex("37bcf0")
Theme.DANGER = Color3.fromHex("d9443f")

-- One colour per role. Used nowhere else in the UI.
Theme.ROLE = {
    innocent = Color3.fromHex("d8d5cf"),
    sheriff = Color3.fromHex("f2a63b"),
    murderer = Color3.fromHex("d9443f"),
    hero = Color3.fromHex("37bcf0"),
    medic = Color3.fromHex("4fb0a0"),
    snitch = Color3.fromHex("b45fe8"),
}

-- Evidence log left-border colour per clue kind
Theme.CLUE = {
    direction = Color3.fromHex("8b9199"),
    fibre = Color3.fromHex("c3c8ce"),
    time = Color3.fromHex("37bcf0"),
    witness = Color3.fromHex("d9443f"),
    cold = Color3.fromHex("2b323c"),
}

Theme.TAP_MIN = 44 -- px, every touch target
Theme.NARROW_WIDTH = 500 -- px, Evidence collapses to two lines below this

return Theme
