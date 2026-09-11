-- COLD CASE · uploaded mesh and texture ids for every generated model.
-- BuildAssets rebuilds ServerStorage.Cosmetics, ServerStorage.Props and
-- ReplicatedStorage.PetModels from this when the place file lacks them.
-- Sizes are in studs; offset and rot (radians, XYZ) are relative to the
-- model pivot. Regenerate from Studio if a model is replaced.
export type Mesh = {
    mesh: string,
    texture: string,
    size: { number },
    offset: { number }?,
    rot: { number }?,
    light: { colour: string, range: number, brightness: number }?,
}

return {
    weapons = {
        brassnine = {
            mesh = "rbxassetid://108206458805830",
            texture = "rbxassetid://126640794872061",
            size = { 0.459, 1.593, 1.9 },
        },
        cinder = {
            mesh = "rbxassetid://125092248110766",
            texture = "rbxassetid://77089134943295",
            size = { 0.575, 2.2, 0.265 },
        },
        coldsnap = {
            mesh = "rbxassetid://84490447749820",
            texture = "rbxassetid://129785326300390",
            size = { 0.477, 2.074, 2.2 },
        },
        copperhead = {
            mesh = "rbxassetid://74516282322282",
            texture = "rbxassetid://80602905847098",
            size = { 0.392, 1.366, 1.9 },
        },
        ember = {
            mesh = "rbxassetid://113813559655941",
            texture = "rbxassetid://98068305489691",
            size = { 2.2, 2.121, 2.182 },
        },
        gun = {
            mesh = "rbxassetid://99497904748563",
            texture = "rbxassetid://75706574655105",
            size = { 0.389, 1.415, 1.9 },
        },
        gutter = {
            mesh = "rbxassetid://79897853303508",
            texture = "rbxassetid://91949368797494",
            size = { 0.573, 2.175, 2.2 },
        },
        hoarfrost = {
            mesh = "rbxassetid://74649072319301",
            texture = "rbxassetid://98946457867995",
            size = { 0.371, 1.346, 1.9 },
        },
        hollow = {
            mesh = "rbxassetid://135992589874431",
            texture = "rbxassetid://129272277596964",
            size = { 0.348, 2.179, 2.2 },
        },
        ivory = {
            mesh = "rbxassetid://96009503068443",
            texture = "rbxassetid://108442685867863",
            size = { 0.381, 1.265, 1.9 },
        },
        knife = {
            mesh = "rbxassetid://96707756815759",
            texture = "rbxassetid://117097223763867",
            size = { 1.024, 2.2, 0.296 },
        },
        longnight = {
            mesh = "rbxassetid://130933857697507",
            texture = "rbxassetid://132826886174711",
            size = { 0.537, 2.171, 2.2 },
        },
        nightjar = {
            mesh = "rbxassetid://85432712942939",
            texture = "rbxassetid://95452662040102",
            size = { 0.269, 0.747, 1.9 },
        },
        nocturne = {
            mesh = "rbxassetid://96647008559609",
            texture = "rbxassetid://76021949723147",
            size = { 2.2, 2.07, 0.303 },
        },
        palefox = {
            mesh = "rbxassetid://118803523316487",
            texture = "rbxassetid://136452533255312",
            size = { 2.2, 2.073, 0.293 },
        },
        scrap = {
            mesh = "rbxassetid://74776883100991",
            texture = "rbxassetid://79902762939487",
            size = { 0.295, 1.083, 1.9 },
        },
        tallow = {
            mesh = "rbxassetid://92419886218037",
            texture = "rbxassetid://90913861096822",
            size = { 0.378, 1.823, 2.2 },
        },
        thealibi = {
            mesh = "rbxassetid://133294799991956",
            texture = "rbxassetid://129116981529801",
            size = { 0.32, 1.274, 1.9 },
        },
        verdict = {
            mesh = "rbxassetid://104562940252265",
            texture = "rbxassetid://130213897214203",
            size = { 0.831, 2.2, 0.252 },
        },
        vigil = {
            mesh = "rbxassetid://127847032336951",
            texture = "rbxassetid://112884123275691",
            size = { 0.664, 2.065, 2.2 },
        },
    },
    props = {
        Armchair = {
            {
                mesh = "rbxassetid://103467173016998",
                texture = "rbxassetid://134998004278943",
                size = { 2.707, 4.5, 2.65 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        Barrel = {
            {
                mesh = "rbxassetid://119033144172148",
                texture = "rbxassetid://110628497461653",
                size = { 3, 4.453, 2.986 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        Bookshelf = {
            {
                mesh = "rbxassetid://106837837535993",
                texture = "rbxassetid://115252584072521",
                size = { 5.82, 8.569, 2.5 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        CrateStack = {
            {
                mesh = "rbxassetid://136042536174718",
                texture = "rbxassetid://111988788802462",
                size = { 6.635, 6.252, 6 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        FilingCabinet = {
            {
                mesh = "rbxassetid://73281108668968",
                texture = "rbxassetid://139187268912317",
                size = { 2.6, 4.188, 2.711 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        GrandfatherClock = {
            {
                mesh = "rbxassetid://138911538445347",
                texture = "rbxassetid://96289013050309",
                size = { 2.039, 7.544, 1.6 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
    },
    pets = {
        moth = {
            {
                mesh = "rbxassetid://123138161561944",
                texture = "rbxassetid://102072444080902",
                size = { 0.999, 0.6, 0.277 },
                offset = { 0, 0, 0 },
                rot = { -3.142, 0, -3.142 },
            },
        },
        nightwatch = {
            {
                mesh = "rbxassetid://80912888996603",
                texture = "rbxassetid://139777021461199",
                size = { 0.761, 1.5, 0.644 },
                offset = { 0, 0, 0 },
                rot = { -3.142, 0, -3.142 },
                light = { colour = "ffc27a", range = 10, brightness = 1.2 },
            },
        },
        widowspeak = {
            {
                mesh = "rbxassetid://73829065145572",
                texture = "rbxassetid://77803477652418",
                size = { 1.244, 0.7, 1.211 },
                offset = { 0, 0, 0 },
                rot = { -3.142, 0, -3.142 },
            },
        },
    },
} :: {
    weapons: { [string]: Mesh },
    props: { [string]: { Mesh } },
    pets: { [string]: { Mesh } },
}
