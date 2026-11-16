-- scarred.cc full menu preview on scoot-new (hevji/scoot-new)
-- Static visual preview: mirrors kicia's tab/subtab/section layout with the
-- real setting names, but nothing is wired to the game. Selections print.
-- Run while Rivals is open and the cosmetics catalogs fill from the game.

local LoadTick = os.clock()

local Library

if isfile("scoot_library.lua") then
    Library = loadstring(readfile("scoot_library.lua"))()
else
    -- raw.githubusercontent's CDN ignores query strings, so "main" can serve
    -- a stale blob for minutes after a push; resolve the head SHA via the
    -- (uncached) API and fetch by pin instead
    local Head = "main"

    pcall(function()
        Head = game:HttpGet("https://api.github.com/repos/hevji/scoot-new/commits/main"):match('^.-"sha"%s*:%s*"(%x+)"')
    end)

    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/hevji/scoot-new/" .. Head .. "/Library.lua?t=" .. tostring(math.floor(os.clock() * 1e6))))()
end

local Window = Library:Window({
    Logo = "77218680285262",
    LogoImage = Library:GetImage("ScarredLogo"),
    FadeTime = 0.3,
})

local Watermark = Library:Watermark("scarred.cc | preview")
local KeybindList = Library:KeybindList()

local function note(...)
    print("[preview]", ...)
end

-- ===========================================================================
-- game data for the cosmetics catalogs
-- ===========================================================================

local NONE = "None"
local cosmeticCosmetics = nil
local weapons = {}
local skinsByWeapon = {}
local wraps = {}
local charms = {}
local finishers = {}

pcall(function()
    local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 10)
    local cosmeticLibrary = require(modules.CosmeticLibrary)
    local cosmetics = cosmeticLibrary.Cosmetics

    cosmeticCosmetics = cosmetics

    for name, meta in pairs(cosmetics) do
        local cosmeticType = type(meta) == "table" and meta.Type or nil

        if cosmeticType == "Skin" and type(meta.ItemName) == "string" then
            skinsByWeapon[meta.ItemName] = skinsByWeapon[meta.ItemName] or {}
            table.insert(skinsByWeapon[meta.ItemName], name)
        elseif cosmeticType == "Wrap" then
            table.insert(wraps, name)
        elseif cosmeticType == "Charm" then
            table.insert(charms, name)
        elseif cosmeticType == "Finisher" then
            table.insert(finishers, name)
        end
    end

    for weapon in pairs(skinsByWeapon) do
        table.insert(weapons, weapon)
    end
    table.sort(weapons)
end)

if #weapons == 0 then
    weapons = { "Burst Rifle", "Revolver", "Medkit", "Spear", "Flashbang", "Crossbow" }
    skinsByWeapon = {
        ["Burst Rifle"] = { "Pine Burst", "Aqua Burst", "Keyst Rifle" },
        ["Revolver"] = { "Desert Eagle", "Boneclaw Revolver", "Glorious Revolver" },
        ["Medkit"] = { "Glorious Medkit", "Bucket of Candy", "Ice Cream" },
        ["Spear"] = { "Plunger", "Studio Light", "Fork" },
        ["Flashbang"] = { "Pixel Flashbang", "Glorious Flashbang", "Skullbang" },
        ["Crossbow"] = { "Glorious Crossbow", "Crossbone", "Pixel Crossbow" },
    }
    wraps = { "Hazard Wrap", "Stripe Wrap" }
    charms = { "Season 0", "Diamond Charm" }
    finishers = { "Diamond Hands", "Head Pop" }
    Library:Notification("Preview", "Could not read the game catalog, using sample data", 6)
end

table.sort(wraps)
table.sort(charms)
table.sort(finishers)
for _, list in pairs(skinsByWeapon) do
    table.sort(list)
end

-- icon images for the clickable grids: guns from ItemLibrary, cosmetics from
-- CosmeticLibrary (some wraps/charms ship without images -> name-only tiles)
local weaponIcons = {}
local cosmeticImages = {}

pcall(function()
    local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 10)
    local itemLibrary = require(modules.ItemLibrary)

    for name, data in pairs(itemLibrary.Items) do
        if type(data) == "table" and type(data.Image) == "string" then
            weaponIcons[name] = data.Image
        end
    end
end)

pcall(function()
    local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 10)
    local cosmeticLibrary = require(modules.CosmeticLibrary)

    for name, meta in pairs(cosmeticLibrary.Cosmetics) do
        if type(meta) == "table" and type(meta.Image) == "string" then
            cosmeticImages[name] = meta.Image
        end
    end
end)

local selections = {}

local function getSelection(weapon)
    selections[weapon] = selections[weapon] or {}
    return selections[weapon]
end

-- ===========================================================================
-- 3D preview models for wraps and charms (same recipe kicia's catalog uses)
-- ===========================================================================

local WrapBase = nil -- base wrap model once found, false once looked up missing
local WrapTextures = nil
local CharmsFolder = nil

local function previewAssets()
    if WrapBase == nil then
        local ok, assets = pcall(function()
            local ps = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")

            return ps and ps:FindFirstChild("Assets")
        end)

        if ok and assets then
            local misc = assets:FindFirstChild("Misc")

            WrapBase = misc and misc:FindFirstChild("Wrap") or false
            WrapTextures = assets:FindFirstChild("WrapTextures")
            CharmsFolder = assets:FindFirstChild("Charms")
        else
            WrapBase = false
        end
    end

    if WrapBase == false then
        return nil
    end

    return WrapBase
end

-- preview-side port of kicia's wrap renderer: parts tagged "Wrappable" carry a
-- WrapGroup attribute, repainted from CosmeticLibrary.Cosmetics[name].WrapGroups
local function recordWrapParts(model)
    local records = {}
    local descendants = model:GetDescendants()

    table.insert(descendants, model)

    for _, inst in ipairs(descendants) do
        if inst:HasTag("Wrappable") then
            local group = inst:GetAttribute("WrapGroup")

            if type(group) == "number" then
                local props

                if inst:IsA("BasePart") then
                    props = {
                        Material = inst.Material,
                        MaterialVariant = inst.MaterialVariant,
                        Color = inst.Color,
                        Transparency = inst.Transparency,
                        Reflectance = inst.Reflectance,
                    }

                    if inst:IsA("MeshPart") then
                        props.TextureID = inst.TextureID
                    end
                elseif inst:IsA("Decal") then
                    props = { Transparency = inst.Transparency }
                else
                    continue
                end

                records[inst] = {
                    WrapGroup = group,
                    IgnoreTransparency = inst:GetAttribute("IgnoreTransparency") == true,
                    IgnoreMaterial = inst:GetAttribute("IgnoreMaterial") == true,
                    OriginalProps = props,
                    Cleanup = {},
                }
            end
        end
    end

    return records
end

local function resetWrap(records)
    for inst, record in pairs(records) do
        for prop, value in pairs(record.OriginalProps) do
            inst[prop] = value
        end

        for _, child in ipairs(record.Cleanup) do
            child:Destroy()
        end

        record.Cleanup = {}
    end
end

local function applyWrap(records, wrapName, inverted)
    resetWrap(records)

    if wrapName == "RANDOM_COSMETIC" or cosmeticCosmetics == nil then
        return
    end

    local meta = cosmeticCosmetics[wrapName]
    local wrapGroups = meta and meta.WrapGroups

    if wrapGroups == nil then
        return
    end

    for inst, record in pairs(records) do
        local group = record.WrapGroup

        if inverted then
            if group == 1 then
                group = 2
            elseif group == 2 then
                group = 1
            end
        end

        local cfg = wrapGroups[group] or {}

        if inst:IsA("BasePart") then
            inst.Color = cfg.Color or inst.Color
            inst.Reflectance = cfg.Reflectance or inst.Reflectance

            if not record.IgnoreTransparency then
                inst.Transparency = cfg.Transparency or inst.Transparency
            end

            if not record.IgnoreMaterial then
                if cfg.Material then
                    inst.Material = cfg.Material
                end

                inst.MaterialVariant = cfg.MaterialVariant or inst.MaterialVariant
            end

            if inst:IsA("MeshPart") then
                inst.TextureID = ""
            end

            if cfg.Textures and WrapTextures then
                local container = WrapTextures:FindFirstChild(cfg.Textures)

                if container then
                    for _, child in ipairs(container:GetChildren()) do
                        local clone = child:Clone()

                        clone.Parent = inst
                        table.insert(record.Cleanup, clone)
                    end
                end
            end
        elseif inst:IsA("Decal") and not record.IgnoreTransparency then
            inst.Transparency = cfg.Transparency or inst.Transparency
        end
    end
end

local function applyWrapTo(model, wrapName, inverted)
    applyWrap(recordWrapParts(model), wrapName, inverted)
end

-- charm model straight off kicia's tile builder: Primary child becomes
-- PrimaryPart, the Hook child is menu wiring and gets dropped
local function charmModel(charmName)
    if previewAssets() == nil or CharmsFolder == nil then
        return nil
    end

    local model = CharmsFolder:FindFirstChild(charmName)

    if model == nil then
        return nil
    end

    local clone = model:Clone()

    if clone:IsA("Model") then
        local primary = clone:FindFirstChild("Primary")

        if primary and primary:IsA("BasePart") then
            clone.PrimaryPart = primary
        end

        clone:PivotTo(CFrame.identity)

        local hook = clone:FindFirstChild("Hook")

        if hook then
            hook:Destroy()
        end
    end

    return clone
end

local function wrapModel(wrapName)
    if previewAssets() == nil then
        return nil
    end

    local clone = WrapBase:Clone()

    clone:PivotTo(CFrame.identity)
    applyWrapTo(clone, wrapName, false)

    return clone
end

-- ===========================================================================
-- combat
-- ===========================================================================

local CombatPage = Window:Page({ Name = "Combat", SubPages = true })

do
    do -- aimbot
        local AimbotSubPage = CombatPage:SubPage({ Name = "Aimbot", Columns = 2 })

        local TargetingSection = AimbotSubPage:Section({ Name = "Targeting", Side = 1 }) do
            TargetingSection:Toggle({
                Name = "Enable Aimbot",
                Flag = "Cbg/Aimbot/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Cbg/Aimbot/Key",
                Mode = "Toggle",
                Callback = note,
            })

            TargetingSection:Dropdown({
                Name = "Target Bones",
                Flag = "Cbg/Aimbot/Bones",
                Items = { "Head", "Torso", "Random" },
                Multi = true,
                Default = { "Head" },
                Callback = note,
            })

            TargetingSection:Slider({
                Name = "Random Bone Chance",
                Flag = "Cbg/Aimbot/RandomPercent",
                Min = 0,
                Max = 100,
                Suffix = "%",
                Default = 0,
                Decimals = 1,
                Callback = note,
            })

            TargetingSection:Toggle({
                Name = "Prioritize Hackers",
                Flag = "Cbg/Aimbot/PrioritizeHackers",
                Default = false,
                Callback = note,
            })
        end

        local FoVSection = AimbotSubPage:Section({ Name = "Targeting FOV", Side = 2 }) do
            local circle = FoVSection:Toggle({
                Name = "Show Targeting Circle",
                Flag = "Cbg/Aimbot/FoVCircle",
                Default = true,
                Callback = note,
            })
            circle:Colorpicker({
                Name = "Color",
                Flag = "Cbg/Aimbot/FoVColor",
                Default = Library.Theme.Accent,
                Alpha = 0,
                Callback = note,
            })

            FoVSection:Slider({
                Name = "Radius",
                Flag = "Cbg/Aimbot/FoVRadius",
                Min = 1,
                Max = 600,
                Suffix = "px",
                Default = 120,
                Decimals = 1,
                Callback = note,
            })

            FoVSection:Slider({
                Name = "Thickness",
                Flag = "Cbg/Aimbot/FoVThickness",
                Min = 0,
                Max = 25,
                Default = 2,
                Decimals = 1,
                Callback = note,
            })

            FoVSection:Toggle({
                Name = "Filled",
                Flag = "Cbg/Aimbot/FoVFill",
                Default = false,
                Callback = note,
            })

            FoVSection:Toggle({
                Name = "Animated",
                Flag = "Cbg/Aimbot/FoVAnimated",
                Default = false,
                Callback = note,
            })

            FoVSection:Toggle({
                Name = "Follow Target",
                Flag = "Cbg/Aimbot/FoVFollow",
                Default = false,
                Callback = note,
            })
        end
    end

    do -- silent aim
        local SilentAimSubPage = CombatPage:SubPage({ Name = "Silent Aim", Columns = 2 })

        local SilentSection = SilentAimSubPage:Section({ Name = "Silent Aim", Side = 1 }) do
            SilentSection:Toggle({
                Name = "Enabled",
                Flag = "Cbg/Silent/Enabled",
                Default = false,
                Callback = note,
            })

            local fov = SilentSection:Toggle({
                Name = "FoV Circle",
                Flag = "Cbg/Silent/FoVCircle",
                Default = false,
                Callback = note,
            })
            fov:Colorpicker({
                Name = "Color",
                Flag = "Cbg/Silent/FoVColor",
                Default = Library.Theme.Accent,
                Alpha = 0,
                Callback = note,
            })
            fov:Colorpicker({
                Name = "Outline",
                Flag = "Cbg/Silent/FoVOutline",
                Default = Color3.fromRGB(0, 0, 0),
                Alpha = 0,
                Callback = note,
            })

            SilentSection:Dropdown({
                Name = "Bone",
                Flag = "Cbg/Silent/Bone",
                Items = { "Head", "Torso", "Random" },
                Multi = false,
                Default = "Head",
                Callback = note,
            })

            SilentSection:Slider({
                Name = "Radius",
                Flag = "Cbg/Silent/FoVRadius",
                Min = 1,
                Max = 500,
                Suffix = "px",
                Default = 75,
                Decimals = 1,
                Callback = note,
            })

            SilentSection:Toggle({
                Name = "Wall Check",
                Flag = "Cbg/Silent/WallCheck",
                Default = true,
                Callback = note,
            })

            SilentSection:Toggle({
                Name = "Team Check",
                Flag = "Cbg/Silent/TeamCheck",
                Default = true,
                Callback = note,
            })

            SilentSection:Toggle({
                Name = "Death Check",
                Flag = "Cbg/Silent/DeathCheck",
                Default = true,
                Callback = note,
            })
        end
    end

    do -- ragebot
        local RagebotSubPage = CombatPage:SubPage({ Name = "Ragebot", Columns = 2 })

        local ActivationSection = RagebotSubPage:Section({ Name = "Activation", Side = 1 }) do
            ActivationSection:Toggle({
                Name = "Enable Ragebot",
                Flag = "Cbg/Rage/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Cbg/Rage/Key",
                Mode = "Toggle",
                Callback = note,
            })

            ActivationSection:Toggle({
                Name = "Utilize Health Lead",
                Flag = "Cbg/Rage/HealthLead",
                Default = false,
                Callback = note,
            })

            for _, slot in { "Primary", "Secondary", "Melee" } do
                ActivationSection:Toggle({
                    Name = slot .. " Enabled",
                    Flag = "Cbg/Rage/Weapon" .. slot,
                    Default = true,
                    Callback = note,
                })
            end
        end

        local TargetingSection = RagebotSubPage:Section({ Name = "Targeting", Side = 2 }) do
            TargetingSection:Dropdown({
                Name = "Ragebot Mode",
                Flag = "Cbg/Rage/Mode",
                Items = { "Normal", "Kicia Counter", "OOB Bait" },
                Multi = false,
                Default = "Normal",
                Callback = note,
            })

            TargetingSection:Slider({
                Name = "Bait Height",
                Flag = "Cbg/Rage/Standoff",
                Min = 1,
                Max = 30,
                Default = 6,
                Decimals = 0.5,
                Callback = note,
            })

            TargetingSection:Toggle({
                Name = "Prioritize Hackers",
                Flag = "Cbg/Rage/PrioritizeHackers",
                Default = false,
                Callback = note,
            })

            TargetingSection:Slider({
                Name = "Stability",
                Flag = "Cbg/Rage/Stability",
                Min = 0,
                Max = 1.5,
                Default = 0.35,
                Decimals = 0.001,
                Callback = note,
            })

            TargetingSection:Slider({
                Name = "Shoot Frames",
                Flag = "Cbg/Rage/ShootFrames",
                Min = 1,
                Max = 5,
                Default = 2,
                Decimals = 1,
                Callback = note,
            })
        end
    end

    do -- fire assist
        local FireAssistSubPage = CombatPage:SubPage({ Name = "Fire Assist", Columns = 2 })

        local TriggerbotSection = FireAssistSubPage:Section({ Name = "Triggerbot", Side = 1 }) do
            TriggerbotSection:Toggle({
                Name = "Enabled",
                Flag = "Cbg/Trigger/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Cbg/Trigger/Key",
                Mode = "Toggle",
                Callback = note,
            })

            TriggerbotSection:Slider({
                Name = "Delay",
                Flag = "Cbg/Trigger/Delay",
                Min = 0,
                Max = 500,
                Suffix = "ms",
                Default = 0,
                Decimals = 1,
                Callback = note,
            })

            TriggerbotSection:Toggle({
                Name = "Target Entities",
                Flag = "Cbg/Trigger/Entities",
                Default = false,
                Callback = note,
            })
        end

        local FlickbotSection = FireAssistSubPage:Section({ Name = "Flickbot", Side = 2 }) do
            FlickbotSection:Toggle({
                Name = "Enabled",
                Flag = "Cbg/Flick/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Cbg/Flick/Key",
                Mode = "Toggle",
                Callback = note,
            })

            FlickbotSection:Slider({
                Name = "Flick Speed",
                Flag = "Cbg/Flick/Speed",
                Min = 1,
                Max = 50,
                Default = 20,
                Decimals = 1,
                Callback = note,
            })
        end
    end

    do -- weapon handling
        local WeaponSubPage = CombatPage:SubPage({ Name = "Weapon Handling", Columns = 2 })

        local AimSection = WeaponSubPage:Section({ Name = "Aim & Fire", Side = 1 }) do
            AimSection:Toggle({
                Name = "Reduce Recoil",
                Flag = "Cbg/Wpn/Recoil",
                Default = false,
                Callback = note,
            })
            AimSection:Slider({
                Name = "Recoil Reduction",
                Flag = "Cbg/Wpn/RecoilPct",
                Min = 0,
                Max = 100,
                Suffix = "%",
                Default = 50,
                Decimals = 1,
                Callback = note,
            })

            AimSection:Toggle({
                Name = "Remove Spread",
                Flag = "Cbg/Wpn/NoSpread",
                Default = false,
                Callback = note,
            })

            AimSection:Toggle({
                Name = "Automatic Fire",
                Flag = "Cbg/Wpn/Automatic",
                Default = false,
                Callback = note,
            })

            AimSection:Toggle({
                Name = "Aim Speed Override",
                Flag = "Cbg/Wpn/AimSpeed",
                Default = false,
                Callback = note,
            })
            AimSection:Slider({
                Name = "Aim Speed",
                Flag = "Cbg/Wpn/AimSpeedPct",
                Min = 50,
                Max = 500,
                Suffix = "%",
                Default = 100,
                Decimals = 1,
                Callback = note,
            })
        end

        local CooldownSection = WeaponSubPage:Section({ Name = "Cooldowns", Side = 1 }) do
            for _, name in { "Fire", "Aim", "Melee", "Dash" } do
                local State = false
                local Slider

                CooldownSection:Toggle({
                    Name = name .. " Cooldown Override",
                    Flag = "Cbg/Wpn/Cd" .. name,
                    Default = false,
                    Callback = function(Value)
                        State = Value
                        note(Value)

                        if Slider then
                            Slider:SetVisibility(Value)
                        end
                    end,
                })

                Slider = CooldownSection:Slider({
                    Name = name .. " Cooldown",
                    Flag = "Cbg/Wpn/Cd" .. name .. "Pct",
                    Min = 0,
                    Max = 100,
                    Suffix = "%",
                    Default = 50,
                    Decimals = 1,
                    Callback = note,
                })

                Slider:SetVisibility(State)
            end
        end

        local MeleeSection = WeaponSubPage:Section({ Name = "Melee", Side = 2 }) do
            MeleeSection:Toggle({
                Name = "Always Backstab",
                Flag = "Cbg/Wpn/Backstab",
                Default = false,
                Callback = note,
            })

            MeleeSection:Toggle({
                Name = "Extend Melee Range",
                Flag = "Cbg/Wpn/MeleeRange",
                Default = false,
                Callback = note,
            })
            MeleeSection:Slider({
                Name = "Range",
                Flag = "Cbg/Wpn/MeleeRangeStuds",
                Min = 5,
                Max = 20,
                Default = 8,
                Decimals = 1,
                Callback = note,
            })
        end

        local GrenadeSection = WeaponSubPage:Section({ Name = "Grenades", Side = 2 }) do
            GrenadeSection:Toggle({
                Name = "Fuse Override",
                Flag = "Cbg/Wpn/Fuse",
                Default = false,
                Callback = note,
            })
            GrenadeSection:Dropdown({
                Name = "Explode On",
                Flag = "Cbg/Wpn/FuseOn",
                Items = { "Impact", "Throw" },
                Multi = false,
                Default = "Impact",
                Callback = note,
            })
            GrenadeSection:Toggle({
                Name = "Remove Fuse",
                Flag = "Cbg/Wpn/NoFuse",
                Default = false,
                Callback = note,
            })
        end
    end

    do -- extra
        local ExtraSubPage = CombatPage:SubPage({ Name = "Extra", Columns = 2 })

        local EntitiesSection = ExtraSubPage:Section({ Name = "Entities", Side = 1 }) do
            EntitiesSection:Toggle({
                Name = "Include Entities",
                ToolTip = {
                    Name = "Include Entities",
                    Description = "Target and show NPC entities (zombies, dummies) everywhere",
                },
                Flag = "Cbg/Extra/IncludeEntities",
                Default = false,
                Callback = note,
            })

            EntitiesSection:Textbox({
                Name = "Entity Exclusions",
                Flag = "Cbg/Extra/Exclusions",
                Placeholder = "Comma separated names",
                Finished = true,
                Callback = note,
            })
        end
    end
end

-- ===========================================================================
-- cosmetics
-- ===========================================================================

local CosmeticsPage = Window:Page({ Name = "Cosmetics", SubPages = true })

do
    do -- presets
        local PresetsSubPage = CosmeticsPage:SubPage({ Name = "Presets", Columns = 2 })

        local PresetsSection = PresetsSubPage:Section({ Name = "Cosmetic Presets", Side = 1 }) do
            PresetsSection:Textbox({
                Name = "Preset Name",
                Flag = "Cos/PresetName",
                Placeholder = "my skin combo",
                Finished = true,
                Callback = note,
            })

            PresetsSection:Button():Add("Save Preset", function()
                note("saved preset")
            end)

            PresetsSection:Searchbox({
                Name = "Load Preset",
                Flag = "Cos/PresetLoad",
                Items = { "default", "tryhard" },
                Multi = false,
                Default = "default",
                Callback = note,
            })

            PresetsSection:Button():Add("Delete Preset", function()
                note("deleted preset")
            end)
        end

        local AutoSection = PresetsSubPage:Section({ Name = "Automation", Side = 2 }) do
            AutoSection:Toggle({
                Name = "Auto Load Preset",
                Flag = "Cos/PresetAutoLoad",
                Default = false,
                Callback = note,
            })

            AutoSection:Toggle({
                Name = "Auto Save Preset",
                Flag = "Cos/PresetAutoSave",
                Default = false,
                Callback = note,
            })
        end
    end

    -- UI-only for now: selections are stored locally, engine wiring comes later
    local ALL_KEY = "All Weapons"

    do -- overview
        local OverviewSubPage = CosmeticsPage:SubPage({ Name = "Overview", Columns = 2 })

        local RuntimeSection = OverviewSubPage:Section({ Name = "Cosmetic Runtime", Side = 1 }) do
            RuntimeSection:Toggle({
                Name = "Enable Cosmetic Changes",
                Flag = "Cos/RuntimeEnabled",
                Default = true,
                Callback = note,
            })

            RuntimeSection:Toggle({
                Name = "Use Custom Loadout",
                ToolTip = {
                    Name = "Custom Loadout",
                    Description = "Applies the choices from the Skins, Wraps, Charms and Finishers tabs.",
                },
                Flag = "Cos/LoadoutEnabled",
                Default = true,
                Callback = note,
            })

            RuntimeSection:Button():Add("Reroll Random Cosmetics", function()
                note("rerolled all RANDOM_COSMETIC selections")
            end)
        end

        local CommunitySection = OverviewSubPage:Section({ Name = "Community", Side = 2 }) do
            CommunitySection:Toggle({
                Name = "Share Skins",
                Flag = "Cos/ShareSkins",
                Default = false,
                Callback = note,
            })

            CommunitySection:Toggle({
                Name = "Show Active Cosmetics",
                Flag = "Cos/ShowActive",
                Default = false,
                Callback = note,
            })
        end
    end

    -- per-slot weapon state: skins target a single gun, the other slots
    -- default to "All Weapons" like kicia's own Apply To dropdown
    local pageWeapon = {
        Skins = weapons[1],
        Wraps = ALL_KEY,
        Charms = ALL_KEY,
        Finishers = ALL_KEY,
    }

    -- kicia's tile camera recipes: FOV 25, fixed yaw/pitch, model pivoted to
    -- origin (wrap zooms to z=1, charm to z=0.3)
    local WRAP_TILE_CAMERA = CFrame.Angles(0, 3.4906585039886591, 0)
        * CFrame.Angles(-0.26179938779914941, 0, 0)
        * CFrame.new(0, 0, 1)

    local CHARM_TILE_CAMERA = CFrame.Angles(0, 3.62836073281, 0)
        * CFrame.Angles(-0.26179938779914941, 0, 0)
        * CFrame.new(0, 0, 0.3)

    local function renderModelTile(model, cameraCFrame)
        return function(Target)
            local viewport = Instance.new("ViewportFrame")

            viewport.Size = UDim2.fromScale(1, 1)
            viewport.Position = UDim2.fromScale(0.5, 0.5)
            viewport.AnchorPoint = Vector2.new(0.5, 0.5)
            viewport.BackgroundTransparency = 1
            viewport.Parent = Target.Content

            local camera = Instance.new("Camera")

            camera.FieldOfView = 25
            camera.CFrame = cameraCFrame
            camera.Parent = viewport
            viewport.CurrentCamera = camera

            model.Parent = viewport
            Target.HideImage()
        end
    end

    local function tileRender(slotKey, itemName)
        return function(Target)
            local model = slotKey == "Wrap" and wrapModel(itemName) or charmModel(itemName)

            if model == nil then
                return
            end

            renderModelTile(model, slotKey == "Wrap" and WRAP_TILE_CAMERA or CHARM_TILE_CAMERA)(Target)
        end
    end

    -- tile previews build one model per frame so the menu never stalls on
    -- ~140 clones at once
    local BuildQueue = {}

    local function tileRender(slotKey, itemName)
        return function(Target)
            table.insert(BuildQueue, { Target = Target, Slot = slotKey, Name = itemName })
        end
    end

    task.spawn(function()
        while true do
            local Job = table.remove(BuildQueue, 1)

            if Job and Job.Target.Content.Parent then
                local model = Job.Slot == "Wrap" and wrapModel(Job.Name) or charmModel(Job.Name)

                if model then
                    renderModelTile(
                        model,
                        Job.Slot == "Wrap" and WRAP_TILE_CAMERA or CHARM_TILE_CAMERA
                    )(Job.Target)
                end
            end

            task.wait()
        end
    end)

    -- one catalog subpage per cosmetic slot; all four share the same layout
    local function catalogSubPage(name, slotKey, itemsForWeapon, allowAll)
        local SubPage = CosmeticsPage:SubPage({ Name = name, Columns = 2 })
        local is3D = slotKey == "Wrap" or slotKey == "Charm"

        local CatalogSection = SubPage:Section({ Name = name, Side = 1 })

        -- 3D preview for slots the game ships actual models for (wraps, charms)
        local PreviewViewport = nil

        local CurrentLabel = nil

        local function updateLabel()
            if CurrentLabel == nil then
                return
            end

            local weapon = pageWeapon[name]
            local current = getSelection(weapon)[slotKey]

            CurrentLabel:SetText("Current: " .. tostring(current or "none") .. "  |  " .. weapon)
        end

        local CatalogGrid = nil

        CatalogSection:Textbox({
            Name = "Search",
            Flag = "Cos/" .. slotKey .. "/Search",
            Placeholder = "type to filter...",
            Callback = function(Value)
                if CatalogGrid then
                    CatalogGrid:Filter(Value)
                end
            end,
        })

        CatalogGrid = CatalogSection:IconGrid({
            Name = "Select " .. name,
            Height = 330,
            CellSize = is3D and 92 or 72,
            Callback = function(Value)
                if Value then
                    local weapon = pageWeapon[name]

                    getSelection(weapon)[slotKey] = Value
                    updateLabel()
                    note(weapon, string.lower(slotKey), "->", Value)

                    if PreviewViewport then
                        if slotKey == "Wrap" then
                            if previewAssets() then
                                PreviewViewport:SetModel(WrapBase, function(clone)
                                    applyWrapTo(clone, Value, false)
                                end)
                            else
                                note("wrap assets not loaded for", Value)
                            end
                        else
                            local model = charmModel(Value)

                            if model then
                                PreviewViewport:SetModel(model)
                            else
                                note("no 3D model for", Value)
                            end
                        end

                        PreviewViewport:SetDistance(0.75)
                        PreviewViewport:SetAutoRotate(true)
                    end
                end
            end,
        })

        local SelectionSection = SubPage:Section({ Name = "Selection", Side = 2 }) do
            CurrentLabel = SelectionSection:Label("Current: none")

            local function fillGrid()
                local weapon = pageWeapon[name]
                local gridItems = {}

                for _, itemName in ipairs(itemsForWeapon(weapon)) do
                    local item = { Name = itemName, Image = cosmeticImages[itemName] or "" }

                    if slotKey == "Wrap" or slotKey == "Charm" then
                        item.Render = tileRender(slotKey, itemName)
                    end

                    gridItems[#gridItems + 1] = item
                end

                local function applyItems()
                    CatalogGrid:SetItems(gridItems)

                    local current = getSelection(weapon)[slotKey]

                    if current and CatalogGrid.Tiles[current] then
                        CatalogGrid:Set(current)
                    end

                    updateLabel()
                end

                -- wrapping ~60 gun clones is heavy; let the menu paint first
                if slotKey == "Wrap" or slotKey == "Charm" then
                    task.defer(applyItems)
                else
                    applyItems()
                end
            end

            SelectionSection:Dropdown({
                Name = "Apply To",
                Flag = "Cos/" .. slotKey .. "/Weapon",
                Items = allowAll and { ALL_KEY, unpack(weapons) } or weapons,
                Multi = false,
                Default = pageWeapon[name],
                Callback = function(Value)
                    if Value == nil or Value == pageWeapon[name] then
                        return
                    end

                    pageWeapon[name] = Value

                    -- only the skin catalog depends on the weapon; re-filling
                    -- the wrap/charm grids would needlessly rebuild 3D tiles
                    if slotKey == "Skin" then
                        fillGrid()
                    else
                        updateLabel()
                    end

                    note("applying", string.lower(name), "to", Value)
                end,
            })

            SelectionSection:Button():Add("Clear Selection", function()
                local weapon = pageWeapon[name]

                CatalogGrid:Clear()
                getSelection(weapon)[slotKey] = nil
                updateLabel()
                note("cleared", string.lower(name), "for", weapon)
            end)

            fillGrid()
        end

        if is3D then
            local PreviewSection = SubPage:Section({ Name = "Preview", Side = 2 }) do
                PreviewViewport = PreviewSection:Viewport({
                    Name = "3D Preview",
                    Height = 480,
                })
            end
        end
    end

    catalogSubPage("Skins", "Skin", function(weapon)
        return skinsByWeapon[weapon] or {}
    end, false)

    catalogSubPage("Wraps", "Wrap", function()
        return wraps
    end, true)

    catalogSubPage("Charms", "Charm", function()
        return charms
    end, true)

    catalogSubPage("Finishers", "Finisher", function()
        return finishers
    end, true)
end

-- ===========================================================================
-- player
-- ===========================================================================

local PlayerPage = Window:Page({ Name = "Player", SubPages = true })

do
    do -- movement
        local MovementSubPage = PlayerPage:SubPage({ Name = "Movement", Columns = 2 })

        local GroundSection = MovementSubPage:Section({ Name = "Ground", Side = 1 }) do
            GroundSection:Toggle({
                Name = "Walk Speed",
                Flag = "Pl/Move/WalkSpeed",
                Default = false,
                Callback = note,
            })
            GroundSection:Slider({
                Name = "Multiplier",
                Flag = "Pl/Move/WalkSpeedMult",
                Min = 1,
                Max = 10,
                Default = 1,
                Decimals = 0.01,
                Callback = note,
            })

            GroundSection:Toggle({
                Name = "Sliding",
                Flag = "Pl/Move/Sliding",
                Default = false,
                Callback = note,
            })
            GroundSection:Slider({
                Name = "Multiplier",
                Flag = "Pl/Move/SlidingMult",
                Min = 1,
                Max = 10,
                Default = 1,
                Decimals = 0.01,
                Callback = note,
            })

            GroundSection:Toggle({
                Name = "Noclip",
                Flag = "Pl/Move/Noclip",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Pl/Move/NoclipKey",
                Mode = "Toggle",
                Callback = note,
            })

            GroundSection:Toggle({
                Name = "Auto Strafe",
                Flag = "Pl/Move/AutoStrafe",
                Default = false,
                Callback = note,
            })
            GroundSection:Slider({
                Name = "Speed",
                Flag = "Pl/Move/AutoStrafeSpeed",
                Min = 1,
                Max = 200,
                Default = 50,
                Decimals = 1,
                Callback = note,
            })
        end

        local AirSection = MovementSubPage:Section({ Name = "Air", Side = 2 }) do
            AirSection:Toggle({
                Name = "Jump Power",
                Flag = "Pl/Move/JumpPower",
                Default = false,
                Callback = note,
            })
            AirSection:Slider({
                Name = "Multiplier",
                Flag = "Pl/Move/JumpPowerMult",
                Min = 0.1,
                Max = 10,
                Default = 1,
                Decimals = 0.01,
                Callback = note,
            })

            AirSection:Toggle({
                Name = "Flight",
                Flag = "Pl/Move/Flight",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Pl/Move/FlightKey",
                Mode = "Toggle",
                Callback = note,
            })
            AirSection:Slider({
                Name = "Speed",
                Flag = "Pl/Move/FlightSpeed",
                Min = 25,
                Max = 500,
                Default = 100,
                Decimals = 1,
                Callback = note,
            })

            AirSection:Toggle({
                Name = "Infinite Double Jumps",
                Flag = "Pl/Move/InfDoubleJumps",
                Default = false,
                Callback = note,
            })

            AirSection:Toggle({
                Name = "Long Jump",
                Flag = "Pl/Move/LongJump",
                Default = false,
                Callback = note,
            })
            AirSection:Dropdown({
                Name = "Mode",
                Flag = "Pl/Move/LongJumpMode",
                Items = { "Under Feet", "Camera Look" },
                Multi = false,
                Default = "Under Feet",
                Callback = note,
            })
            AirSection:Slider({
                Name = "Force",
                Flag = "Pl/Move/LongJumpForce",
                Min = 0,
                Max = 300,
                Default = 120,
                Decimals = 1,
                Callback = note,
            })
            AirSection:Slider({
                Name = "Upward Velocity",
                Flag = "Pl/Move/LongJumpUp",
                Min = 0,
                Max = 200,
                Default = 60,
                Decimals = 1,
                Callback = note,
            })
        end

        local AntiAimSection = MovementSubPage:Section({ Name = "Anti-Aim", Side = 1 }) do
            AntiAimSection:Toggle({
                Name = "Enabled",
                Flag = "Pl/AntiAim/Enabled",
                Default = false,
                Callback = note,
            })

            AntiAimSection:Dropdown({
                Name = "Yaw Mode",
                Flag = "Pl/AntiAim/Yaw",
                Items = { "None", "Reverse", "Random", "Extended Random", "Custom" },
                Multi = false,
                Default = "None",
                Callback = note,
            })

            AntiAimSection:Dropdown({
                Name = "Pitch Mode",
                Flag = "Pl/AntiAim/Pitch",
                Items = { "None", "Upside Down", "Random", "Extended Random", "Custom" },
                Multi = false,
                Default = "None",
                Callback = note,
            })

            AntiAimSection:Slider({
                Name = "Custom Yaw",
                Flag = "Pl/AntiAim/YawCustom",
                Min = -360,
                Max = 360,
                Default = 0,
                Decimals = 1,
                Callback = note,
            })

            AntiAimSection:Slider({
                Name = "Custom Pitch",
                Flag = "Pl/AntiAim/PitchCustom",
                Min = -360,
                Max = 360,
                Default = 0,
                Decimals = 1,
                Callback = note,
            })
        end
    end

    do -- movement recorder
        local RecorderSubPage = PlayerPage:SubPage({ Name = "Movement Recorder", Columns = 2 })

        local RecordSection = RecorderSubPage:Section({ Name = "Recording", Side = 1 }) do
            RecordSection:Toggle({
                Name = "Record Movement",
                Flag = "Pl/Rec/Record",
                Default = false,
                Callback = note,
            })

            RecordSection:Textbox({
                Name = "Recording Name",
                Flag = "Pl/Rec/Name",
                Placeholder = "route1",
                Finished = true,
                Callback = note,
            })
        end

        local PlaybackSection = RecorderSubPage:Section({ Name = "Playback", Side = 2 }) do
            PlaybackSection:Searchbox({
                Name = "Recording",
                Flag = "Pl/Rec/Library",
                Items = { "route1", "route2" },
                Multi = false,
                Default = "route1",
                Callback = note,
            })

            local buttons = PlaybackSection:Button()
            buttons:Add("Play", function()
                note("playing recording")
            end)
            buttons:Add("Stop", function()
                note("stopped playback")
            end)
            buttons:Add("Delete", function()
                note("deleted recording")
            end)
        end
    end

    do -- character
        local CharacterSubPage = PlayerPage:SubPage({ Name = "Character", Columns = 2 })

        local AnimationsSection = CharacterSubPage:Section({ Name = "Animation Player", Side = 1 }) do
            AnimationsSection:Searchbox({
                Name = "Animation",
                Flag = "Pl/Char/Animation",
                Items = { "Dance 1", "Dance 2", "Backflip" },
                Multi = false,
                Default = "Dance 1",
                Callback = note,
            })

            local buttons = AnimationsSection:Button()
            buttons:Add("Play", function()
                note("playing animation")
            end)
            buttons:Add("Stop", function()
                note("stopping animation")
            end)
        end

        local AppearanceSection = CharacterSubPage:Section({ Name = "Character Appearance", Side = 2 }) do
            local body = AppearanceSection:Toggle({
                Name = "Body Color",
                Flag = "Pl/Char/BodyColor",
                Default = false,
                Callback = note,
            })
            body:Colorpicker({
                Name = "Color",
                Flag = "Pl/Char/BodyColorValue",
                Default = Color3.fromRGB(255, 255, 255),
                Alpha = 0,
                Callback = note,
            })

            AppearanceSection:Toggle({
                Name = "Invisible Character",
                Flag = "Pl/Char/Invisible",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Pl/Char/InvisibleKey",
                Mode = "Toggle",
                Callback = note,
            })
        end
    end

    do -- identity spoofing
        local IdentitySubPage = PlayerPage:SubPage({ Name = "Identity Spoofing", Columns = 2 })

        local DeviceSection = IdentitySubPage:Section({ Name = "Device Spoof", Side = 1 }) do
            DeviceSection:Toggle({
                Name = "Spoof Device",
                Flag = "Pl/Id/DeviceSpoof",
                Default = false,
                Callback = note,
            })

            DeviceSection:Dropdown({
                Name = "Device",
                Flag = "Pl/Id/Device",
                Items = { "PC", "Console", "Mobile" },
                Multi = false,
                Default = "PC",
                Callback = note,
            })
        end

        local SpooferSection = IdentitySubPage:Section({ Name = "Player Spoofer", Side = 2 }) do
            SpooferSection:Toggle({
                Name = "Spoof Display Name",
                Flag = "Pl/Id/DisplayName",
                Default = false,
                Callback = note,
            })

            SpooferSection:Textbox({
                Name = "Spoofed Name",
                Flag = "Pl/Id/DisplayNameValue",
                Placeholder = "new name",
                Finished = true,
                Callback = note,
            })
        end
    end
end

-- ===========================================================================
-- automation
-- ===========================================================================

local AutomationPage = Window:Page({ Name = "Automation", SubPages = true })

do
    do -- match flow
        local MatchFlowSubPage = AutomationPage:SubPage({ Name = "Match Flow", Columns = 2 })

        local QueueSection = MatchFlowSubPage:Section({ Name = "Auto Queue", Side = 1 }) do
            QueueSection:Toggle({
                Name = "Auto Queue",
                Flag = "Aut/Queue/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Aut/Queue/Key",
                Mode = "Toggle",
                Callback = note,
            })

            QueueSection:Dropdown({
                Name = "Game Mode",
                Flag = "Aut/Queue/Mode",
                Items = { "1v1", "2v2", "Party" },
                Multi = false,
                Default = "1v1",
                Callback = note,
            })
        end

        local MapVoteSection = MatchFlowSubPage:Section({ Name = "Auto Map Vote", Side = 1 }) do
            MapVoteSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Vote/Enabled",
                Default = false,
                Callback = note,
            })

            MapVoteSection:Dropdown({
                Name = "Map",
                Flag = "Aut/Vote/Map",
                Items = { "Crossroads", "Foundry", "Bunker" },
                Multi = false,
                Default = "Crossroads",
                Callback = note,
            })
        end

        local BanSection = MatchFlowSubPage:Section({ Name = "Auto Weapon Ban", Side = 2 }) do
            BanSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Ban/Enabled",
                Default = false,
                Callback = note,
            })

            BanSection:Dropdown({
                Name = "Banned Weapons",
                Flag = "Aut/Ban/Weapons",
                Items = { "Katana", "Sniper", "Burst Rifle" },
                Multi = true,
                Callback = note,
            })
        end

        local RespawnSection = MatchFlowSubPage:Section({ Name = "Auto Respawn", Side = 2 }) do
            RespawnSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Respawn/Enabled",
                Default = false,
                Callback = note,
            })

            RespawnSection:Slider({
                Name = "Delay",
                Flag = "Aut/Respawn/Delay",
                Min = 0,
                Max = 10,
                Suffix = "s",
                Default = 0,
                Decimals = 0.1,
                Callback = note,
            })
        end
    end

    do -- auto loadout
        local LoadoutSubPage = AutomationPage:SubPage({ Name = "Auto Loadout", Columns = 2 })

        local LoadoutSection = LoadoutSubPage:Section({ Name = "Loadouts", Side = 1 }) do
            LoadoutSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Loadout/Enabled",
                Default = false,
                Callback = note,
            })

            LoadoutSection:Dropdown({
                Name = "Primary",
                Flag = "Aut/Loadout/Primary",
                Items = { "Burst Rifle", "Revolver", "AK" },
                Multi = false,
                Default = "Burst Rifle",
                Callback = note,
            })

            LoadoutSection:Dropdown({
                Name = "Secondary",
                Flag = "Aut/Loadout/Secondary",
                Items = { "Revolver", "Spear", "Medkit" },
                Multi = false,
                Default = "Revolver",
                Callback = note,
            })
        end
    end

    do -- in-match automation
        local InMatchSubPage = AutomationPage:SubPage({ Name = "In-Match Automation", Columns = 2 })

        local PickupSection = InMatchSubPage:Section({ Name = "Auto Pickup", Side = 1 }) do
            PickupSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Pickup/Enabled",
                Default = false,
                Callback = note,
            })
        end

        local AntiKatanaSection = InMatchSubPage:Section({ Name = "Anti Katana", Side = 1 }) do
            AntiKatanaSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Katana/Enabled",
                Default = false,
                Callback = note,
            })
        end

        local TripmineSection = InMatchSubPage:Section({ Name = "Subspace Tripmines", Side = 2 }) do
            TripmineSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Trip/Enabled",
                Default = false,
                Callback = note,
            })
        end
    end

    do -- detection
        local DetectionSubPage = AutomationPage:SubPage({ Name = "Detection", Columns = 2 })

        local HackerSection = DetectionSubPage:Section({ Name = "Hacker Detector", Side = 1 }) do
            HackerSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Hack/Enabled",
                Default = false,
                Callback = note,
            })

            HackerSection:Dropdown({
                Name = "Action",
                Flag = "Aut/Hack/Action",
                Items = { "Notify", "Leave" },
                Multi = false,
                Default = "Notify",
                Callback = note,
            })
        end

        local ModSection = DetectionSubPage:Section({ Name = "Moderator Detector", Side = 2 }) do
            ModSection:Toggle({
                Name = "Enabled",
                Flag = "Aut/Mod/Enabled",
                Default = false,
                Callback = note,
            })

            ModSection:Dropdown({
                Name = "Action",
                Flag = "Aut/Mod/Action",
                Items = { "Notify", "Leave" },
                Multi = false,
                Default = "Notify",
                Callback = note,
            })
        end
    end
end

-- ===========================================================================
-- visuals
-- ===========================================================================

local VisualsPage = Window:Page({ Name = "Visuals", SubPages = true })

do
    do -- player esp
        local EspSubPage = VisualsPage:SubPage({ Name = "Player ESP", Columns = 2 })

        local MainSection = EspSubPage:Section({ Name = "Player ESP", Side = 1 }) do
            MainSection:Toggle({
                Name = "Enable ESP",
                Flag = "Vis/Esp/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Vis/Esp/Key",
                Mode = "Toggle",
                Callback = note,
            })

            MainSection:Dropdown({
                Name = "Box Fit",
                Flag = "Vis/Esp/BoxFit",
                Items = { "Static", "Dynamic" },
                Multi = false,
                Default = "Dynamic",
                Callback = note,
            })

            local box = MainSection:Toggle({
                Name = "Box",
                Flag = "Vis/Esp/Box",
                Default = false,
                Callback = note,
            })
            box:Colorpicker({
                Name = "Color",
                Flag = "Vis/Esp/BoxColor",
                Default = Color3.fromRGB(255, 255, 255),
                Alpha = 0,
                Callback = note,
            })

            MainSection:Toggle({
                Name = "Health Bar",
                Flag = "Vis/Esp/HealthBar",
                Default = true,
                Callback = note,
            })

            MainSection:Toggle({
                Name = "Distance",
                Flag = "Vis/Esp/Distance",
                Default = true,
                Callback = note,
            })
        end

        local TextSection = EspSubPage:Section({ Name = "Text", Side = 2 }) do
            TextSection:Toggle({
                Name = "Use Display Names",
                Flag = "Vis/Esp/DisplayNames",
                Default = false,
                Callback = note,
            })

            TextSection:Dropdown({
                Name = "Font",
                Flag = "Vis/Esp/Font",
                Items = { "Plex", "Roboto", "Montserrat" },
                Multi = false,
                Default = "Plex",
                Callback = note,
            })

            TextSection:Slider({
                Name = "Font Size",
                Flag = "Vis/Esp/FontSize",
                Min = 8,
                Max = 32,
                Default = 14,
                Decimals = 1,
                Callback = note,
            })

            TextSection:Dropdown({
                Name = "Text Case",
                Flag = "Vis/Esp/TextCase",
                Items = { "Standard", "UPPERCASE", "lowercase" },
                Multi = false,
                Default = "Standard",
                Callback = note,
            })

            TextSection:Toggle({
                Name = "Scale With Distance",
                Flag = "Vis/Esp/DistanceScaling",
                Default = false,
                Callback = note,
            })
        end
    end

    do -- crosshair
        local CrosshairSubPage = VisualsPage:SubPage({ Name = "Crosshair", Columns = 2 })

        local CrosshairSection = CrosshairSubPage:Section({ Name = "Crosshair", Side = 1 }) do
            CrosshairSection:Toggle({
                Name = "Enabled",
                Flag = "Vis/Cross/Enabled",
                Default = false,
                Callback = note,
            }):Keybind({
                Flag = "Vis/Cross/Key",
                Mode = "Toggle",
                Callback = note,
            })

            CrosshairSection:Slider({
                Name = "Size",
                Flag = "Vis/Cross/Size",
                Min = 1,
                Max = 50,
                Default = 10,
                Decimals = 1,
                Callback = note,
            })

            CrosshairSection:Slider({
                Name = "Thickness",
                Flag = "Vis/Cross/Thickness",
                Min = 1,
                Max = 10,
                Default = 2,
                Decimals = 1,
                Callback = note,
            })

            CrosshairSection:Slider({
                Name = "Gap",
                Flag = "Vis/Cross/Gap",
                Min = 0,
                Max = 30,
                Default = 4,
                Decimals = 1,
                Callback = note,
            })

            local dot = CrosshairSection:Toggle({
                Name = "Dot",
                Flag = "Vis/Cross/Dot",
                Default = false,
                Callback = note,
            })
            dot:Colorpicker({
                Name = "Color",
                Flag = "Vis/Cross/Color",
                Default = Library.Theme.Accent,
                Alpha = 0,
                Callback = note,
            })
        end

        local MotionSection = CrosshairSubPage:Section({ Name = "Motion & Effects", Side = 2 }) do
            MotionSection:Toggle({
                Name = "Spin",
                Flag = "Vis/Cross/Spin",
                Default = false,
                Callback = note,
            })
            MotionSection:Slider({
                Name = "Spin Speed",
                Flag = "Vis/Cross/SpinSpeed",
                Min = 0,
                Max = 360,
                Suffix = "deg/s",
                Default = 90,
                Decimals = 1,
                Callback = note,
            })

            MotionSection:Toggle({
                Name = "Follow Target",
                Flag = "Vis/Cross/Follow",
                Default = false,
                Callback = note,
            })
        end
    end

    do -- weapon visuals
        local WeaponSubPage = VisualsPage:SubPage({ Name = "Weapon Visuals", Columns = 2 })

        local PositionSection = WeaponSubPage:Section({ Name = "Viewmodel Position", Side = 1 }) do
            for _, axis in { "X", "Y", "Z" } do
                PositionSection:Slider({
                    Name = axis,
                    Flag = "Vis/Viewmodel/" .. axis,
                    Min = -5,
                    Max = 5,
                    Default = 0,
                    Decimals = 0.01,
                    Callback = note,
                })
            end
        end

        local ChamsSection = WeaponSubPage:Section({ Name = "Chams & Tracers", Side = 2 }) do
            local arms = ChamsSection:Toggle({
                Name = "Arms Chams",
                Flag = "Vis/Viewmodel/ArmsChams",
                Default = false,
                Callback = note,
            })
            arms:Colorpicker({
                Name = "Color",
                Flag = "Vis/Viewmodel/ArmsColor",
                Default = Library.Theme.Accent,
                Alpha = 0,
                Callback = note,
            })

            local held = ChamsSection:Toggle({
                Name = "Held Item Chams",
                Flag = "Vis/Viewmodel/HeldChams",
                Default = false,
                Callback = note,
            })
            held:Colorpicker({
                Name = "Color",
                Flag = "Vis/Viewmodel/HeldColor",
                Default = Color3.fromRGB(255, 100, 100),
                Alpha = 0,
                Callback = note,
            })

            ChamsSection:Toggle({
                Name = "Wireframe",
                Flag = "Vis/Viewmodel/Wireframe",
                Default = false,
                Callback = note,
            })

            ChamsSection:Toggle({
                Name = "Bullet Tracers",
                Flag = "Vis/Viewmodel/Tracers",
                Default = false,
                Callback = note,
            })
        end
    end

    do -- camera & screen
        local CameraSubPage = VisualsPage:SubPage({ Name = "Camera & Screen", Columns = 2 })

        local FovSection = CameraSubPage:Section({ Name = "Camera FOV", Side = 1 }) do
            FovSection:Toggle({
                Name = "Enable Camera FOV",
                Flag = "Vis/Cam/FovEnabled",
                Default = false,
                Callback = note,
            })
            FovSection:Slider({
                Name = "Field of View",
                Flag = "Vis/Cam/Fov",
                Min = 30,
                Max = 120,
                Default = 70,
                Decimals = 1,
                Callback = note,
            })
        end

        local ThirdPersonSection = CameraSubPage:Section({ Name = "Third Person", Side = 1 }) do
            ThirdPersonSection:Toggle({
                Name = "Enabled",
                Flag = "Vis/Cam/ThirdPerson",
                Default = false,
                Callback = note,
            })
            ThirdPersonSection:Slider({
                Name = "Distance",
                Flag = "Vis/Cam/ThirdPersonDistance",
                Min = 4,
                Max = 30,
                Default = 10,
                Decimals = 1,
                Callback = note,
            })
        end

        local OverlaysSection = CameraSubPage:Section({ Name = "Gameplay Overlays", Side = 2 }) do
            for _, name in { "Flashbang Effect", "Burn Effect", "ADS Vignette", "Scope Overlay", "Hitmarker" } do
                OverlaysSection:Toggle({
                    Name = "Hide " .. name,
                    Flag = "Vis/Cam/Hide" .. name,
                    Default = false,
                    Callback = note,
                })
            end
        end

        local StretchedSection = CameraSubPage:Section({ Name = "Stretched Resolution", Side = 2 }) do
            StretchedSection:Toggle({
                Name = "Enabled",
                Flag = "Vis/Cam/Stretched",
                Default = false,
                Callback = note,
            })
            StretchedSection:Slider({
                Name = "Width",
                Flag = "Vis/Cam/StretchedWidth",
                Min = 400,
                Max = 1920,
                Default = 1280,
                Decimals = 1,
                Callback = note,
            })
            StretchedSection:Slider({
                Name = "Height",
                Flag = "Vis/Cam/StretchedHeight",
                Min = 300,
                Max = 1080,
                Default = 720,
                Decimals = 1,
                Callback = note,
            })
        end
    end

    do -- sound esp
        local SoundSubPage = VisualsPage:SubPage({ Name = "Sound ESP", Columns = 2 })

        local SoundSection = SoundSubPage:Section({ Name = "Sound ESP", Side = 1 }) do
            SoundSection:Toggle({
                Name = "Enabled",
                Flag = "Vis/Sound/Enabled",
                Default = false,
                Callback = note,
            })

            SoundSection:Slider({
                Name = "Max Distance",
                Flag = "Vis/Sound/MaxDistance",
                Min = 10,
                Max = 500,
                Suffix = "st",
                Default = 150,
                Decimals = 1,
                Callback = note,
            })

            SoundSection:Toggle({
                Name = "Show Loudness",
                Flag = "Vis/Sound/Loudness",
                Default = true,
                Callback = note,
            })
        end
    end
end

-- ===========================================================================
-- world
-- ===========================================================================

local WorldPage = Window:Page({ Name = "World", SubPages = true })

do
    do -- lighting
        local LightingSubPage = WorldPage:SubPage({ Name = "Lighting", Columns = 2 })

        local TimeSection = LightingSubPage:Section({ Name = "Time & Exposure", Side = 1 }) do
            TimeSection:Toggle({
                Name = "Lighting Override",
                Flag = "Wld/Light/Override",
                Default = false,
                Callback = note,
            })

            TimeSection:Slider({
                Name = "Clock Time",
                Flag = "Wld/Light/ClockTime",
                Min = 0,
                Max = 24,
                Default = 12,
                Decimals = 0.1,
                Callback = note,
            })

            TimeSection:Slider({
                Name = "Exposure",
                Flag = "Wld/Light/Exposure",
                Min = -5,
                Max = 5,
                Default = 0,
                Decimals = 0.1,
                Callback = note,
            })

            TimeSection:Toggle({
                Name = "Shadows",
                Flag = "Wld/Light/Shadows",
                Default = true,
                Callback = note,
            })
        end

        local ToneSection = LightingSubPage:Section({ Name = "Tone & Color", Side = 1 }) do
            ToneSection:Toggle({
                Name = "Color Correction",
                Flag = "Wld/Light/ColorCorrection",
                Default = false,
                Callback = note,
            })

            ToneSection:Slider({
                Name = "Saturation",
                Flag = "Wld/Light/Saturation",
                Min = -1,
                Max = 1,
                Default = 0,
                Decimals = 0.01,
                Callback = note,
            })
        end

        local EffectsSection = LightingSubPage:Section({ Name = "Light Effects", Side = 2 }) do
            EffectsSection:Toggle({
                Name = "Bloom",
                Flag = "Wld/Light/Bloom",
                Default = false,
                Callback = note,
            })

            EffectsSection:Toggle({
                Name = "Sun Rays",
                Flag = "Wld/Light/SunRays",
                Default = false,
                Callback = note,
            })

            EffectsSection:Toggle({
                Name = "Motion Blur",
                Flag = "Wld/Light/MotionBlur",
                Default = false,
                Callback = note,
            })
        end

        local AtmosphereSection = LightingSubPage:Section({ Name = "Atmosphere", Side = 2 }) do
            AtmosphereSection:Toggle({
                Name = "Atmosphere",
                Flag = "Wld/Light/Atmosphere",
                Default = false,
                Callback = note,
            })
            AtmosphereSection:Slider({
                Name = "Density",
                Flag = "Wld/Light/Density",
                Min = 0,
                Max = 1,
                Default = 0.3,
                Decimals = 0.01,
                Callback = note,
            })
            AtmosphereSection:Slider({
                Name = "Haze",
                Flag = "Wld/Light/Haze",
                Min = 0,
                Max = 1,
                Default = 0,
                Decimals = 0.01,
                Callback = note,
            })
        end
    end

    do -- sky & weather
        local SkySubPage = WorldPage:SubPage({ Name = "Sky & Weather", Columns = 2 })

        local SkyboxSection = SkySubPage:Section({ Name = "Skybox", Side = 1 }) do
            SkyboxSection:Dropdown({
                Name = "Skybox",
                Flag = "Wld/Sky/Skybox",
                Items = { "Default", "Night", "Sunset", "Space" },
                Multi = false,
                Default = "Default",
                Callback = note,
            })
        end

        local SoundSection = SkySubPage:Section({ Name = "Ambient Sound", Side = 1 }) do
            SoundSection:Toggle({
                Name = "Enable Ambient Sound",
                Flag = "Wld/Sky/Ambience",
                Default = false,
                Callback = note,
            })

            SoundSection:Dropdown({
                Name = "Preset",
                Flag = "Wld/Sky/Preset",
                Items = { "Rain", "Wind", "Forest" },
                Multi = false,
                Default = "Rain",
                Callback = note,
            })

            SoundSection:Slider({
                Name = "Volume",
                Flag = "Wld/Sky/Volume",
                Min = 0,
                Max = 10,
                Default = 1,
                Decimals = 0.01,
                Callback = note,
            })
        end

        local WeatherSection = SkySubPage:Section({ Name = "Weather", Side = 2 }) do
            WeatherSection:Toggle({
                Name = "Weather Override",
                Flag = "Wld/Sky/Weather",
                Default = false,
                Callback = note,
            })

            WeatherSection:Dropdown({
                Name = "Weather",
                Flag = "Wld/Sky/WeatherType",
                Items = { "Clear", "Rain", "Snow", "Fog" },
                Multi = false,
                Default = "Clear",
                Callback = note,
            })
        end

        local LightningSection = SkySubPage:Section({ Name = "Lightning", Side = 2 }) do
            LightningSection:Toggle({
                Name = "Lightning",
                Flag = "Wld/Sky/Lightning",
                Default = false,
                Callback = note,
            })
        end
    end
end

-- ===========================================================================
-- settings
-- ===========================================================================

local SettingsPage = Library:CreateSettingsPage(Window, Watermark, KeybindList)

Library:Notification("Loaded!", "Menu took " .. string.format("%.4f", os.clock() - LoadTick) .. " seconds to load", 5)
