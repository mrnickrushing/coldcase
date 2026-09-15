--!strict
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
        Arcade = {
            {
                mesh = "rbxassetid://75644288111699",
                texture = "rbxassetid://97724069988079",
                size = { 4.152, 5.75, 3.6 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector
            },
        },
        Bed = {
            {
                mesh = "rbxassetid://133168580542351",
                texture = "rbxassetid://72987987399468",
                size = { 4.354, 3.64, 6.761 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- headboard was on the LookVector; yaw so it goes to the wall when placed against one
            },
        },
        Fridge = {
            {
                mesh = "rbxassetid://96189130846574",
                texture = "rbxassetid://111237659133998",
                size = { 3.784, 6.023, 3.64 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector
            },
        },
        KitchenCounter = {
            {
                mesh = "rbxassetid://93222515445109",
                texture = "rbxassetid://105309894009260",
                size = { 5.892, 4.13, 2.88 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        Plant = {
            {
                mesh = "rbxassetid://94832069745947",
                texture = "rbxassetid://135058173165674",
                size = { 3.12, 5.142, 2.706 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        SofaRed = {
            {
                mesh = "rbxassetid://78037400018845",
                texture = "rbxassetid://133152419617955",
                size = { 7.315, 3.75, 3.606 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z (same as Sofa); yaw so the front sits on the LookVector
            },
        },
        Television = {
            {
                mesh = "rbxassetid://129309935866534",
                texture = "rbxassetid://127703656257339",
                size = { 5.141, 4.385, 1.92 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        VendingMachine = {
            {
                mesh = "rbxassetid://127956295487071",
                texture = "rbxassetid://117083845430330",
                size = { 3.286, 6.527, 2.86 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector
            },
        },
        Anchor = {
            {
                mesh = "rbxassetid://87953592929340",
                texture = "rbxassetid://140311026644992",
                size = { 5.2, 7.166, 1.139 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
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
        Bollard = {
            {
                mesh = "rbxassetid://112005433202084",
                texture = "rbxassetid://120061702938543",
                size = { 3.6, 2.585, 1.357 },
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
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector
            },
        },
        CardCatalog = {
            {
                mesh = "rbxassetid://81502207570669",
                texture = "rbxassetid://99073321844485",
                size = { 3.523, 6, 2.053 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector
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
        DiningChair = {
            {
                mesh = "rbxassetid://124726580082152",
                texture = "rbxassetid://70451604468626",
                size = { 1.886, 4.41, 2.2 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        DiningTable = {
            {
                mesh = "rbxassetid://107155759963458",
                texture = "rbxassetid://86281546539406",
                size = { 7.601, 3.5, 4.181 },
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
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector
            },
        },
        Fireplace = {
            {
                mesh = "rbxassetid://70483067887992",
                texture = "rbxassetid://103792877460129",
                size = { 6.67, 10.178, 3.9 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        Globe = {
            {
                mesh = "rbxassetid://70940447597940",
                texture = "rbxassetid://138337555138035",
                size = { 2.485, 4.5, 2.215 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        GrandPiano = {
            {
                mesh = "rbxassetid://113757172663055",
                texture = "rbxassetid://117760481093595",
                size = { 6.304, 7, 7.134 },
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
        LobsterTraps = {
            {
                mesh = "rbxassetid://105127299725558",
                texture = "rbxassetid://113671801025258",
                size = { 3.679, 4, 2.577 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        RopeCoil = {
            {
                mesh = "rbxassetid://70903728877654",
                texture = "rbxassetid://110386620385551",
                size = { 3.182, 1.5, 3.278 },
                offset = { 0, 0, 0 },
                rot = { 0, 0, 0 },
            },
        },
        Sofa = {
            {
                mesh = "rbxassetid://130895510519413",
                texture = "rbxassetid://104031401316478",
                size = { 9.159, 3.771, 4.375 },
                offset = { 0, 0, 0 },
                rot = { 0, math.pi, 0 }, -- mesh front was on +Z; yaw so the front sits on the LookVector like every other prop
            },
        },
        WritingDesk = {
            {
                mesh = "rbxassetid://129332194573127",
                texture = "rbxassetid://110957675256373",
                size = { 4.029, 4.5, 2.496 },
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
