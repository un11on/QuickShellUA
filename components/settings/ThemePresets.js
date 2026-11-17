.pragma library

// Curated additions for the Appearance gallery. Keeping preset data outside
// AppearancePage avoids turning the UI component into a 250-entry data file.

var _semantic = {
    "Cyber / Neon":       ["#42f5a7", "#ffe66d", "#ff5c8a"],
    "Ice / Arctic":       ["#66e3c4", "#ffd166", "#ff7b8b"],
    "Ocean / Abyss":      ["#3dd6b0", "#f5c76a", "#ff7085"],
    "Midnight / Space":   ["#55d6be", "#e8c56a", "#ff6f91"],
    "Violet / Amethyst":  ["#62d6a8", "#f4ca64", "#ff7894"],
    "Crimson / Ruby":     ["#64d68b", "#f5bf58", "#ff5d6c"],
    "Emerald / Forest":   ["#48d597", "#e8c45b", "#f16d7a"],
    "Amber / Gold":       ["#73cf8d", "#ffc857", "#ee6677"],
    "Graphite / Industrial": ["#55d6b3", "#e6bf67", "#f06f7d"],
    "Synthwave / Future": ["#4fe0b6", "#ffd166", "#ff668c"]
}

function _normal(name, category, bg, surf, acc, acc2, text, textSub, border, opacity) {
    var sem = _semantic[category]
    return {
        name: name, category: category, presetType: "normal",
        bg: bg, surf: surf, acc: acc, acc2: acc2,
        text: text, textSub: textSub, border: border,
        success: sem[0], warning: sem[1], error: sem[2],
        op: opacity || 0.88, gradEnabled: false
    }
}

function _gradient(name, category, bg, surf, acc, acc2, text, textSub, border,
                   c1, c2, c3, intensity, applySurface) {
    var sem = _semantic[category]
    return {
        name: name, category: category, presetType: "gradient",
        bg: bg, surf: surf, acc: acc, acc2: acc2,
        text: text, textSub: textSub, border: border,
        success: sem[0], warning: sem[1], error: sem[2], op: 0.90,
        gradEnabled: true, gradC1: c1, gradC2: c2, gradC3: c3 || "",
        gradInt: intensity || 1.0, gradDir: "horizontal",
        gradApplyBg: true, gradApplySurf: applySurface === true
    }
}

var normalPresets = [
    // Cyber / Neon
    _normal("Neon Ronin", "Cyber / Neon", "#080b12", "#121c2a", "#00e5ff", "#ff3cac", "#e8fbff", "#8bb8c7", "#234055", 0.90),
    _normal("Circuit Bloom", "Cyber / Neon", "#0b0710", "#211126", "#ff4fd8", "#39ffb6", "#ffeafa", "#c69abd", "#4d2850", 0.89),
    _normal("Quantum Lime", "Cyber / Neon", "#071008", "#132616", "#b6ff35", "#00d9a6", "#efffdc", "#a7c98a", "#315137", 0.90),
    _normal("Laser District", "Cyber / Neon", "#10070c", "#28101d", "#ff315f", "#31c8ff", "#ffe7ed", "#c59aa7", "#54243b", 0.89),
    _normal("Chrome Pulse", "Cyber / Neon", "#080d11", "#18242d", "#d9f3ff", "#00b8ff", "#eef8fc", "#93aab6", "#344852", 0.91),
    _normal("Digital Orchid", "Cyber / Neon", "#0e0815", "#241333", "#d45cff", "#48d7ff", "#f7eaff", "#b99ac9", "#4b2b61", 0.88),
    _normal("Plasma Grid", "Cyber / Neon", "#070a16", "#111d36", "#537bff", "#ff4db8", "#e8edff", "#929fc6", "#293b69", 0.90),
    _normal("Voltage Noir", "Cyber / Neon", "#090909", "#1d1a12", "#ffe44d", "#ff7a1a", "#fff8d9", "#c9ba83", "#4a4121", 0.92),
    _normal("Pixel Reactor", "Cyber / Neon", "#06110f", "#102924", "#00ffc6", "#8e6bff", "#ddfff7", "#84bfb1", "#20554b", 0.90),
    _normal("Ultraviolet Wire", "Cyber / Neon", "#0b0614", "#1d1030", "#9f55ff", "#ff5fd1", "#f2e8ff", "#b59bc8", "#42275f", 0.89),

    // Ice / Arctic
    _normal("Polar Glass", "Ice / Arctic", "#07131b", "#102733", "#a8edff", "#55bde8", "#effcff", "#a6c8d4", "#294c5c", 0.86),
    _normal("Arctic Signal", "Ice / Arctic", "#07101e", "#10203b", "#65c7ff", "#c4f4ff", "#eaf7ff", "#9ebbd0", "#284567", 0.88),
    _normal("Frostbyte", "Ice / Arctic", "#09121a", "#172633", "#74f0e2", "#7aa8ff", "#ecfffd", "#9fc8c5", "#31505b", 0.88),
    _normal("Cryo Chamber", "Ice / Arctic", "#050d14", "#0d1c29", "#43d9ff", "#6f8fff", "#e2f8ff", "#87aabd", "#203b50", 0.91),
    _normal("Winter Circuit", "Ice / Arctic", "#0c1118", "#1b2732", "#b8dcff", "#69a8e8", "#f2f7fc", "#aab8c7", "#384b5d", 0.87),
    _normal("Icebound Steel", "Ice / Arctic", "#0b1015", "#1e282f", "#9fd7e8", "#8099b2", "#edf5f7", "#a4b3ba", "#3b4a52", 0.90),
    _normal("Boreal Night", "Ice / Arctic", "#051516", "#0c2b2b", "#55e6c1", "#66bfff", "#e6fff9", "#8cc8bd", "#21524f", 0.88),
    _normal("Frozen Quartz", "Ice / Arctic", "#100f1b", "#242239", "#c2b8ff", "#8ddcff", "#f5f2ff", "#b2aacb", "#484365", 0.87),
    _normal("Snowblind Core", "Ice / Arctic", "#0d151b", "#202f39", "#e3f7ff", "#89c7dc", "#f7fcff", "#b5c7cf", "#415762", 0.86),
    _normal("Permafrost Blue", "Ice / Arctic", "#07101a", "#10223a", "#4f9cff", "#7ee8ff", "#e8f2ff", "#91abc7", "#29466d", 0.90),

    // Ocean / Abyss
    _normal("Abyssal Lantern", "Ocean / Abyss", "#020c12", "#071d29", "#18c7d9", "#71f5d4", "#dcfbff", "#7fb1bd", "#164050", 0.91),
    _normal("Mariana Code", "Ocean / Abyss", "#020810", "#061726", "#1677ff", "#00c9c8", "#e0efff", "#7795b3", "#163454", 0.92),
    _normal("Trench Sapphire", "Ocean / Abyss", "#03091a", "#0a1734", "#3d73ff", "#56d8ff", "#e4eaff", "#8495be", "#20366b", 0.90),
    _normal("Biolume Depths", "Ocean / Abyss", "#03110f", "#082824", "#36f2b3", "#16a8c7", "#ddfff5", "#83bcae", "#195047", 0.89),
    _normal("Pelagic Night", "Ocean / Abyss", "#061117", "#102630", "#49b8d1", "#8de3ed", "#e2f7fb", "#8baab2", "#28505b", 0.89),
    _normal("Nautilus Core", "Ocean / Abyss", "#091013", "#1d2929", "#e0b66a", "#4bbcae", "#f4eee2", "#aaa28f", "#454b40", 0.88),
    _normal("Deep Current", "Ocean / Abyss", "#031018", "#09283a", "#00a6e8", "#00dfc4", "#ddf7ff", "#79aabd", "#16506b", 0.91),
    _normal("Atlantic Void", "Ocean / Abyss", "#02070d", "#0a151f", "#468faf", "#82c6d9", "#e5f0f5", "#7f98a3", "#233a47", 0.93),
    _normal("Coral Shadow", "Ocean / Abyss", "#100b12", "#281a26", "#ff758f", "#4dd7c8", "#ffecef", "#c19da5", "#543441", 0.88),
    _normal("Tidal Monolith", "Ocean / Abyss", "#071013", "#172326", "#70b7be", "#9ee4d8", "#e8f3f2", "#96aaa8", "#35494a", 0.90),

    // Midnight / Space
    _normal("Event Horizon", "Midnight / Space", "#020207", "#0c0b17", "#6c63ff", "#f064c8", "#eeeeff", "#8f8daa", "#282545", 0.94),
    _normal("Void Observatory", "Midnight / Space", "#03050a", "#0c1420", "#67a5ff", "#b28cff", "#e8f0ff", "#8798b2", "#23334d", 0.92),
    _normal("Comet Wake", "Midnight / Space", "#070812", "#15172b", "#7fe7ff", "#ffb15c", "#eefcff", "#9eafc1", "#30375a", 0.89),
    _normal("Dark Matter", "Midnight / Space", "#030303", "#111116", "#8e7dff", "#6ad7c5", "#ededf4", "#8c8c9d", "#292935", 0.95),
    _normal("Eclipse Station", "Midnight / Space", "#09070c", "#1d1724", "#d88cff", "#ff765e", "#f6eefa", "#aa9aad", "#423348", 0.90),
    _normal("Cosmic Dust", "Midnight / Space", "#0d0b12", "#211c2a", "#c29bd8", "#78a5c8", "#f0ebf4", "#a69dac", "#463b50", 0.88),
    _normal("Pulsar Night", "Midnight / Space", "#040718", "#0c1535", "#3878ff", "#e552ff", "#e8edff", "#8795c1", "#20366d", 0.92),
    _normal("Orion Terminal", "Midnight / Space", "#040b09", "#0b1d17", "#5be3ad", "#7ea6ff", "#e3fff5", "#83aa9d", "#1f453a", 0.91),
    _normal("Moonless Orbit", "Midnight / Space", "#020407", "#091018", "#9ab6cc", "#627d98", "#ebf1f5", "#8495a1", "#20313e", 0.94),
    _normal("Astral Vault", "Midnight / Space", "#080714", "#18152b", "#ad84ff", "#55cbe8", "#f0eaff", "#a094bd", "#39315c", 0.90),

    // Violet / Amethyst
    _normal("Royal Amethyst", "Violet / Amethyst", "#11091a", "#27143a", "#b56cff", "#e3a0ff", "#f5eaff", "#b69bc9", "#4c2a67", 0.88),
    _normal("Violet Cathedral", "Violet / Amethyst", "#0e0a18", "#231831", "#8867d9", "#d6b4ff", "#f0eafa", "#a99bb9", "#463657", 0.89),
    _normal("Purple Singularity", "Violet / Amethyst", "#08040f", "#190a29", "#a100ff", "#ff4fd8", "#f5e4ff", "#b88bc7", "#42205e", 0.91),
    _normal("Mystic Aubergine", "Violet / Amethyst", "#150b15", "#2d192d", "#d07ac5", "#8cc8b5", "#f5e7f2", "#b29aaa", "#53354f", 0.87),
    _normal("Lavender Void", "Violet / Amethyst", "#0d0b16", "#211d31", "#b6a0ff", "#78c9e8", "#f2efff", "#aaa3c4", "#423d59", 0.88),
    _normal("Wisteria Night", "Violet / Amethyst", "#110d18", "#282034", "#a77bc8", "#e0a6bd", "#f2eaf6", "#ad9db6", "#4b3d56", 0.87),
    _normal("Arcane Plum", "Violet / Amethyst", "#160915", "#31142d", "#e04fae", "#9b7bff", "#fae8f5", "#bd97ad", "#5b2b50", 0.89),
    _normal("Imperial Iris", "Violet / Amethyst", "#0c0b1d", "#1d1b3d", "#6667d9", "#bd73e8", "#ececff", "#9a9bc4", "#373873", 0.90),
    _normal("Mauve Reactor", "Violet / Amethyst", "#130b12", "#2d1b2a", "#d48bb8", "#76d4c5", "#f5eaf1", "#b29ca9", "#543649", 0.87),
    _normal("Grape Nebula", "Violet / Amethyst", "#10071c", "#26103f", "#9345d6", "#f06ab3", "#f3e6ff", "#b092c6", "#4a2670", 0.89),

    // Crimson / Ruby
    _normal("Ruby Reactor", "Crimson / Ruby", "#150608", "#310d14", "#f23d5e", "#ff9472", "#ffe8ec", "#c89ba4", "#5d2230", 0.90),
    _normal("Scarlet Protocol", "Crimson / Ruby", "#110709", "#281116", "#d92d48", "#ff7188", "#fce7ea", "#bc969d", "#50232d", 0.90),
    _normal("Bloodstone Dark", "Crimson / Ruby", "#0e0707", "#231313", "#ad343e", "#d98a63", "#f3e6e4", "#a9908d", "#442828", 0.91),
    _normal("Garnet Forge", "Crimson / Ruby", "#14090a", "#2d1918", "#c84b50", "#e2a35f", "#f7e9e6", "#b89b96", "#55312f", 0.88),
    _normal("Crimson Circuit", "Crimson / Ruby", "#130508", "#300b13", "#ff234f", "#5ac8fa", "#ffe5eb", "#c9919e", "#5e1d2c", 0.91),
    _normal("Red Eclipse", "Crimson / Ruby", "#0a0608", "#1e1117", "#ea4c6a", "#885cff", "#fae9ed", "#ad939b", "#432832", 0.91),
    _normal("Cherry Armor", "Crimson / Ruby", "#17090f", "#321725", "#e75d86", "#d4a15f", "#fbe9ef", "#be9aa7", "#593044", 0.88),
    _normal("Carmine Night", "Crimson / Ruby", "#100609", "#260f17", "#c72c58", "#f27c97", "#f8e4ea", "#b58e9b", "#4d2133", 0.90),
    _normal("Rosefire Core", "Crimson / Ruby", "#16080b", "#34131a", "#ff5b6e", "#ffb15c", "#ffe9eb", "#c89c9f", "#622733", 0.89),
    _normal("Inferno Ruby", "Crimson / Ruby", "#180705", "#35100c", "#ff3d2e", "#ff9d3d", "#ffebe5", "#cb9d93", "#65271d", 0.90),

    // Emerald / Forest
    _normal("Emerald Canopy", "Emerald / Forest", "#06110c", "#10271b", "#35d98b", "#a3d95b", "#e2fbed", "#8eb5a0", "#24513a", 0.89),
    _normal("Moss Circuit", "Emerald / Forest", "#0a1008", "#1a2614", "#8fc45b", "#45c7a1", "#edf5e6", "#a0b092", "#394c30", 0.88),
    _normal("Jade Sentinel", "Emerald / Forest", "#06120f", "#0f2923", "#2ec4a0", "#7de08c", "#e0faf3", "#8db6aa", "#225348", 0.90),
    _normal("Pine Matrix", "Emerald / Forest", "#07100b", "#14241a", "#4fb477", "#84c95d", "#e6f3e9", "#91aa98", "#304a38", 0.89),
    _normal("Viridian Night", "Emerald / Forest", "#04110e", "#0b2923", "#00b894", "#4de3b0", "#dcfff5", "#7fb6a6", "#185044", 0.91),
    _normal("Fern Terminal", "Emerald / Forest", "#070d07", "#111d12", "#71d37b", "#b0cf63", "#e9f8e9", "#95ae96", "#2d4130", 0.91),
    _normal("Malachite Core", "Emerald / Forest", "#06120d", "#102b1e", "#20c76f", "#5ee0b2", "#e0fbee", "#82b398", "#20543a", 0.90),
    _normal("Rainforest Code", "Emerald / Forest", "#07120b", "#122b17", "#48d65f", "#29b8a2", "#e1f9e5", "#89b391", "#245332", 0.89),
    _normal("Basilisk Green", "Emerald / Forest", "#091005", "#1b260c", "#a2db3f", "#38c88d", "#effbdc", "#a4b989", "#3b4f20", 0.90),
    _normal("Woodland Signal", "Emerald / Forest", "#0b100a", "#1c261a", "#7fb06d", "#d0b866", "#edf2e9", "#a5afa0", "#3c4938", 0.88),

    // Amber / Gold
    _normal("Amber Forge", "Amber / Gold", "#151005", "#2d200a", "#ffbd38", "#e87431", "#fff4d8", "#c7ae7d", "#5a4318", 0.90),
    _normal("Golden Circuit", "Amber / Gold", "#120e05", "#28200c", "#e8c35a", "#51c8b0", "#faf3df", "#bbaa82", "#504521", 0.89),
    _normal("Brass Night", "Amber / Gold", "#100f0a", "#27241a", "#c7a85b", "#829d8b", "#f1eee4", "#aaa494", "#4c4636", 0.90),
    _normal("Saffron Terminal", "Amber / Gold", "#140f04", "#2e2108", "#f4b41f", "#80b951", "#fff2cf", "#c7a96e", "#5d4515", 0.91),
    _normal("Honeycomb Dark", "Amber / Gold", "#161105", "#30230b", "#f2c14e", "#d98d2b", "#fff5d9", "#c9b27f", "#60491b", 0.88),
    _normal("Bronze Reactor", "Amber / Gold", "#140b06", "#2b170d", "#c87941", "#e3b45b", "#f6e9df", "#b69a87", "#553020", 0.90),
    _normal("Solar Ochre", "Amber / Gold", "#171005", "#33230b", "#db9f2b", "#f2d16b", "#fcf1d8", "#c0aa78", "#624918", 0.89),
    _normal("Candlelight Code", "Amber / Gold", "#120d08", "#281d14", "#f0a85c", "#d7cf88", "#f9eee3", "#b8a28e", "#51402f", 0.87),
    _normal("Topaz Vault", "Amber / Gold", "#130d04", "#2c1d09", "#f5a524", "#69c7b0", "#fff1d6", "#c3a877", "#594015", 0.90),
    _normal("Desert Gold", "Amber / Gold", "#171108", "#302414", "#d6aa5c", "#9fbd73", "#f5eedf", "#b7aa91", "#5b4b31", 0.88),

    // Graphite / Industrial
    _normal("Titanium Shadow", "Graphite / Industrial", "#0c0f12", "#1c2329", "#aebcca", "#5ca7c8", "#eef2f5", "#969fa8", "#39444d", 0.91),
    _normal("Carbon Fiber", "Graphite / Industrial", "#090a0b", "#191b1d", "#d0d4d7", "#6d747a", "#eeeeef", "#95989b", "#34383b", 0.93),
    _normal("Graphene Core", "Graphite / Industrial", "#080b0d", "#151d21", "#72d1d8", "#9ca8b2", "#e6f1f2", "#899b9e", "#304248", 0.92),
    _normal("Gunmetal UI", "Graphite / Industrial", "#0c1115", "#1d2930", "#7f9daf", "#cf9e63", "#e8eef1", "#929fa6", "#3a4c56", 0.90),
    _normal("Steel Monolith", "Graphite / Industrial", "#101214", "#23282c", "#c2ccd2", "#758794", "#f0f2f3", "#9ca3a8", "#424a50", 0.90),
    _normal("Slate Machine", "Graphite / Industrial", "#0d1117", "#202936", "#82aaff", "#93a4b8", "#e8eef8", "#939eae", "#3d4a5e", 0.90),
    _normal("Tungsten Night", "Graphite / Industrial", "#0b0c0e", "#1d1f23", "#b2a58f", "#7c8997", "#ece9e4", "#9b9891", "#3d3d3e", 0.92),
    _normal("Chromium Dark", "Graphite / Industrial", "#090d10", "#172229", "#d3efff", "#55b8d6", "#eefaff", "#91aab5", "#304852", 0.91),
    _normal("Ash Terminal", "Graphite / Industrial", "#0e0e0d", "#20201d", "#b8c28a", "#7e9b88", "#eeeeea", "#9e9f94", "#3f4038", 0.91),
    _normal("Iron Protocol", "Graphite / Industrial", "#100d0d", "#251e1e", "#ba7373", "#9da8b3", "#f0e9e9", "#a59797", "#493939", 0.90),

    // Synthwave / Future
    _normal("Retro Laser", "Synthwave / Future", "#10091b", "#2a1740", "#ff4fb8", "#36d9ff", "#f8eaff", "#b69bc7", "#53306f", 0.89),
    _normal("VHS Horizon", "Synthwave / Future", "#120b18", "#2d1a35", "#f36fae", "#f6a84a", "#f8eaf3", "#b79aaa", "#57354f", 0.88),
    _normal("Arcade Midnight", "Synthwave / Future", "#070918", "#111d3b", "#3f7cff", "#ff4fd1", "#e8edff", "#8f9fc3", "#293e73", 0.91),
    _normal("Synth City", "Synthwave / Future", "#0d0718", "#221037", "#c94fff", "#00d6d6", "#f5e8ff", "#ad91c2", "#462668", 0.89),
    _normal("Cassette Neon", "Synthwave / Future", "#130b0f", "#2c1a24", "#ff6e8a", "#7bdff2", "#faecef", "#b99ca3", "#573443", 0.88),
    _normal("Future Console", "Synthwave / Future", "#050d0f", "#0e2427", "#00e6b8", "#5b9dff", "#e0fff9", "#82afa7", "#1d4a4e", 0.91),
    _normal("Vector Sunset", "Synthwave / Future", "#170b12", "#35172b", "#ff706d", "#b45cff", "#ffecee", "#c29ca6", "#653147", 0.88),
    _normal("Vapor Grid", "Synthwave / Future", "#0a0816", "#1c1730", "#73e9ff", "#d06cff", "#eefbff", "#a49bc0", "#39325a", 0.89),
    _normal("Analog Dream", "Synthwave / Future", "#141014", "#2a222a", "#d58fa5", "#81c7bd", "#f3ecef", "#aca1a6", "#4d424b", 0.87),
    _normal("Hyperdrive UI", "Synthwave / Future", "#05091a", "#0e1940", "#3178ff", "#7df9ff", "#e4edff", "#8599c4", "#203d7a", 0.92)
]

var gradientPresets = [
    // Cyber / Neon
    _gradient("Neon Fluxline", "Cyber / Neon", "#070a12", "#121a2b", "#00e5ff", "#ff4fc8", "#07111c", "#26102d", "#073540", 1.10, true),
    _gradient("Cyan Magenta Drive", "Cyber / Neon", "#090713", "#1c1430", "#55e6ff", "#ff5bbd", "#071624", "#2b102f", "#16254d", 1.08, true),
    _gradient("Acid Laser", "Cyber / Neon", "#071007", "#172715", "#b8ff36", "#00dfaa", "#071407", "#20320c", "#073533", 1.06, false),
    _gradient("Electric Sakura", "Cyber / Neon", "#110814", "#2a142c", "#ff64bd", "#55ccff", "#18091b", "#35143a", "#092d40", 1.05, true),
    _gradient("Prism Circuit", "Cyber / Neon", "#090a15", "#191d35", "#8b6cff", "#42e8dc", "#0b0e24", "#2a1540", "#07373b", 1.12, true),

    // Ice / Arctic
    _gradient("Aurora Iceflow", "Ice / Arctic", "#07131b", "#102a33", "#8eefff", "#5ce0bd", "#071824", "#10344a", "#15402f", 1.02, true),
    _gradient("Polar Horizon", "Ice / Arctic", "#08121d", "#162637", "#9bdcff", "#8fa7ff", "#0b1826", "#173552", "#242b53", 0.98, false),
    _gradient("Frozen Aurora", "Ice / Arctic", "#071519", "#102e31", "#73f1d0", "#71bfff", "#071a1a", "#10423a", "#16345c", 1.05, true),
    _gradient("Glacier Prism", "Ice / Arctic", "#0b111c", "#1e2638", "#c2c8ff", "#79dcff", "#11162a", "#2b2448", "#123d55", 0.96, true),
    _gradient("Cryo Dawn", "Ice / Arctic", "#0b171d", "#1c3138", "#b9efff", "#72d7c6", "#0c1d27", "#254257", "#1c4b43", 0.94, false),

    // Ocean / Abyss
    _gradient("Abyss Current", "Ocean / Abyss", "#020b12", "#061e2b", "#16bce1", "#36e0bd", "#020d17", "#06304a", "#064035", 1.08, true),
    _gradient("Blue Trench", "Ocean / Abyss", "#020817", "#07152f", "#3d70ff", "#48cbff", "#020a1c", "#112a5a", "#07435c", 1.06, true),
    _gradient("Biolume Tide", "Ocean / Abyss", "#03110f", "#0b2924", "#37efb2", "#1ba6d1", "#041711", "#0b4537", "#073551", 1.04, true),
    _gradient("Atlantic Storm", "Ocean / Abyss", "#071018", "#172935", "#6da9c7", "#8be1e8", "#0a1720", "#253a4b", "#164451", 0.98, false),
    _gradient("Deep Reef", "Ocean / Abyss", "#071013", "#18272a", "#48d6c5", "#ff758f", "#06191b", "#123c3d", "#43222e", 1.02, true),

    // Midnight / Space
    _gradient("Nebula Passage", "Midnight / Space", "#050511", "#121027", "#9b6dff", "#f05cc6", "#070719", "#26153c", "#3d1538", 1.08, true),
    _gradient("Eventide Orbit", "Midnight / Space", "#040711", "#111a2b", "#5e99ff", "#c278ff", "#050b18", "#17365b", "#342052", 1.04, true),
    _gradient("Cosmic Ribbon", "Midnight / Space", "#070814", "#191a31", "#78dfff", "#ff9b64", "#091021", "#1b3c55", "#4b2630", 1.02, false),
    _gradient("Blackstar Halo", "Midnight / Space", "#020204", "#0c0c12", "#beb5ff", "#6688aa", "#020204", "#161424", "#102634", 1.12, true),
    _gradient("Lunar Plasma", "Midnight / Space", "#08060e", "#1c1524", "#df8dff", "#ff7460", "#0b0713", "#342041", "#4a1f27", 1.05, true),

    // Violet / Amethyst
    _gradient("Amethyst Veil", "Violet / Amethyst", "#100918", "#241537", "#ba76ff", "#e59aff", "#130b20", "#34204e", "#401d47", 1.00, true),
    _gradient("Violet Mirage", "Violet / Amethyst", "#0c0a18", "#211b34", "#9c7be8", "#65d0dc", "#101026", "#342c55", "#16434b", 0.98, false),
    _gradient("Royal Nebula", "Violet / Amethyst", "#0b0715", "#221038", "#934ce8", "#ff5fb5", "#100820", "#35155a", "#4a153c", 1.06, true),
    _gradient("Plum Aurora", "Violet / Amethyst", "#130b14", "#2b192d", "#d47dc0", "#68c8b4", "#1b0e1d", "#422443", "#173d37", 0.96, true),
    _gradient("Orchid Nightfall", "Violet / Amethyst", "#0f0917", "#261537", "#c85fff", "#6d9cff", "#140b22", "#3c1e55", "#1a2f5d", 1.04, true),

    // Crimson / Ruby
    _gradient("Ruby Horizon", "Crimson / Ruby", "#14070a", "#2e1017", "#f04a65", "#ff9b62", "#1b080b", "#49151d", "#4a2418", 1.03, true),
    _gradient("Blood Aurora", "Crimson / Ruby", "#100608", "#251015", "#d53150", "#825fff", "#17070a", "#3e111c", "#241b4c", 1.05, true),
    _gradient("Scarlet Ember", "Crimson / Ruby", "#150806", "#30150f", "#ff5038", "#ffb14f", "#1d0907", "#4c1d12", "#4a3310", 1.06, false),
    _gradient("Carmine Plasma", "Crimson / Ruby", "#13070d", "#2e1122", "#e33f78", "#4dc8e8", "#1b0812", "#48152e", "#123b4a", 1.04, true),
    _gradient("Rose Inferno", "Crimson / Ruby", "#16080d", "#341425", "#ff6685", "#e79b4d", "#200a12", "#502034", "#4a2b14", 1.02, true),

    // Emerald / Forest
    _gradient("Emerald Aurora", "Emerald / Forest", "#05110d", "#0e2920", "#35dc9a", "#75d85a", "#061711", "#124333", "#2e4315", 1.02, true),
    _gradient("Forest Mist", "Emerald / Forest", "#09110a", "#1a291b", "#80c77d", "#6bbeb5", "#0d180e", "#2a412c", "#17423f", 0.94, false),
    _gradient("Jade Current", "Emerald / Forest", "#04120f", "#0b2b25", "#29c8a3", "#58d27c", "#061916", "#10483d", "#1c4527", 1.04, true),
    _gradient("Malachite Night", "Emerald / Forest", "#06110c", "#11271a", "#20c66f", "#49bccc", "#07180f", "#16422a", "#103947", 1.06, true),
    _gradient("Viridian Glow", "Emerald / Forest", "#06120e", "#102c24", "#00bd91", "#b1d64c", "#071a15", "#124a3b", "#354817", 1.03, true),

    // Amber / Gold
    _gradient("Golden Dusk", "Amber / Gold", "#140f06", "#2d210d", "#f3c34f", "#df7442", "#1c1408", "#4b3613", "#4d2016", 1.00, true),
    _gradient("Amber Horizon", "Amber / Gold", "#150e05", "#30200a", "#ffb72e", "#69c5ab", "#1d1206", "#50330d", "#174239", 1.02, true),
    _gradient("Brass Ember", "Amber / Gold", "#110f0a", "#282419", "#c6a65c", "#b36a43", "#18160e", "#413b25", "#3f2218", 0.96, false),
    _gradient("Topaz Night", "Amber / Gold", "#130c04", "#2c1c08", "#f2a72a", "#7e8fff", "#1b1005", "#4a2b0b", "#212858", 1.04, true),
    _gradient("Solar Furnace", "Amber / Gold", "#170c04", "#32170a", "#ff8b24", "#ffd05c", "#200e04", "#50230b", "#4a3a11", 1.07, true),

    // Graphite / Industrial
    _gradient("Titanium Sheen", "Graphite / Industrial", "#0b1013", "#1c272d", "#b8cbd5", "#62a9c5", "#0e1519", "#2d3c44", "#173c4b", 0.96, true),
    _gradient("Carbon Aurora", "Graphite / Industrial", "#080a0b", "#191d1f", "#8bd4ca", "#8f7fd4", "#0b0d0f", "#283236", "#292348", 1.00, true),
    _gradient("Gunmetal Ice", "Graphite / Industrial", "#0b1015", "#1d2931", "#8fcce3", "#8c9fb2", "#0d161d", "#2c404d", "#27313d", 0.98, false),
    _gradient("Chrome Night", "Graphite / Industrial", "#080c0f", "#172126", "#d9edf5", "#4db6d0", "#0a1014", "#293840", "#123843", 1.02, true),
    _gradient("Steel Ember", "Graphite / Industrial", "#100d0d", "#251f1f", "#ba8a7a", "#849dad", "#171111", "#3c2d2b", "#263944", 0.97, true),

    // Synthwave / Future
    _gradient("Synth Sunset", "Synthwave / Future", "#100918", "#29163c", "#ff55bd", "#ff9851", "#160b20", "#431b50", "#4f2614", 1.06, true),
    _gradient("Retro Wavefront", "Synthwave / Future", "#090a19", "#181f3a", "#4f8cff", "#ff53cd", "#0d1025", "#253c64", "#471846", 1.08, true),
    _gradient("VHS Aurora", "Synthwave / Future", "#120b14", "#2b1b2e", "#ed78ad", "#5fd7cb", "#1a0e1c", "#442744", "#17463f", 0.99, false),
    _gradient("Arcade Horizon", "Synthwave / Future", "#070918", "#111c3b", "#3979ff", "#ab5cff", "#0a0d22", "#183661", "#341d54", 1.09, true),
    _gradient("Future Pulse", "Synthwave / Future", "#050d10", "#0e2529", "#00dfb8", "#557fff", "#071519", "#104044", "#172d5a", 1.05, true)
]
