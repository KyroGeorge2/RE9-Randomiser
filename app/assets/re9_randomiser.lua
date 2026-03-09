-- ============================================================
--  RE9 Item Randomiser  |  REFramework autorun script
--  Seed file: reframework/data/re9_randomiser/seed.json
--  Strategy: hook app.Inventory.mergeOrAdd — fires first on all world pickups (confirmed via sweep log)
-- ============================================================

local MOD       = "[RE9-RAND]"
local SEED_PATH = "re9_randomiser/seed.json"

local seed_data     = nil
local id_by_name    = {}
local substitutions = {}
local swap_count    = 0
local init_done     = false
local hook_installed = false
local _is_adding    = false
local pending_swaps = {}
local reroll_pool   = {}
local given_items   = {}
local given_keys    = {}

-- Item ID prefixes that should re-randomize every pickup (not fixed by seed)
-- Default quantities for randomised replacements
local item_default_qty = {
    ["it40_00_000"] = 15,  -- Handgun Ammo
    ["it40_01_000"] = 6,   -- Shotgun Shells
    ["it40_02_000"] = 4,   -- 12.7x55 Ammo
    ["it40_03_000"] = 20,  -- Machine Gun Ammo
    ["it40_05_000"] = 5,   -- Rifle Ammo
    ["it50_00_002"] = 3,   -- Scrap
    ["it50_00_006"] = 2,   -- Rare Metal
    ["it50_00_014"] = 2,   -- Gunpowder (Large)
    ["it50_00_018"] = 1,   -- Empty Injector
    ["it00_00_000"] = 1,   -- Med Injector (variant)
    ["it00_01_000"] = 1,   -- Med Injector
    ["it20_00_000"] = 2,   -- Hand Grenade
    ["it20_00_002"] = 2,   -- Molotov
    ["it20_00_003"] = 1,   -- Empty Bottle
    ["it20_00_004"] = 1,   -- Stacked Grenade
    ["it20_00_005"] = 2,   -- Acid Bottle
}
local function default_qty(id_str) return item_default_qty[id_str] or 1 end

-- Known-good consumable IDs (always re-randomised every pickup)
local safe_consumables = {
    ["it00_00_000"]=true,                                          -- Med Injector (variant)
    ["it00_01_000"]=true,                                          -- Med Injector
    ["it20_00_000"]=true, ["it20_00_002"]=true,                    -- Grenade, Molotov
    ["it20_00_003"]=true, ["it20_00_004"]=true, ["it20_00_005"]=true,
    ["it40_00_000"]=true, ["it40_01_000"]=true, ["it40_02_000"]=true,
    ["it40_03_000"]=true, ["it40_05_000"]=true,
    -- it40_20_000, it40_20_001, it40_30_000 removed — no description, Leon-only ghosts
    ["it50_00_002"]=true, ["it50_00_006"]=true,
    ["it50_00_014"]=true, ["it50_00_018"]=true,
}

-- Known-good weapon IDs
local safe_weapons = {
    ["it10_00_005"]=true, ["it10_00_006"]=true,
    ["it10_01_000"]=true, ["it10_01_002"]=true, ["it10_01_003"]=true,
    ["it10_02_000"]=true,
    ["it10_03_000"]=true, ["it10_03_001"]=true, ["it10_03_003"]=true,
    ["it10_04_000"]=true,
    ["it10_05_000"]=true, ["it10_05_001"]=true, ["it10_05_002"]=true,
    ["it10_20_001"]=true, ["it10_20_003"]=true, ["it10_20_005"]=true,
    ["it10_20_006"]=true, ["it10_20_007"]=true, ["it10_20_008"]=true,
}

local function is_always_random(id_str)
    return id_str and safe_consumables[id_str] == true
end

local function is_weapon_or_part(id_str)
    return id_str and safe_weapons[id_str] == true
end

-- Items that are NEVER randomized when picked up (but can still appear as replacements)
local function is_protected_original(id_str)
    if not id_str then return true end
    if id_str:match("^it60_") then return true end   -- all key items — never swap originals
    if id_str:match("^it10_10_") then return true end -- story melee weapons
    if id_str == "it10_02_000" then return true end    -- Requiem pistol (starting weapon / segment grant)
    if id_str == "it99_05_001" then return true end    -- Flashlight (segment grant)
    if id_str:match("^it99_06_") then return true end  -- Blood collectors (Grace mechanic, never swap)
    if id_str:match("^it70_") then return true end    -- weapon parts/attachments — never swap originals
    return false
end

-- Items that are NEVER given as replacements
local function is_blacklisted(id_str)
    if not id_str then return true end
    if id_str:match("^it60_99_") then return true end   -- ghost/placeholder key items
    if id_str:match("^it10_10_") then return true end   -- story melee weapons
    -- ghost herbs — no description, broken
    if id_str == "it40_20_000" or id_str == "it40_20_001" or id_str == "it40_30_000" then return true end
    -- it99_02_: steroids/stabilizer/unknowns — Grace-only permanent upgrades, don't randomise
    if id_str:match("^it99_02_") then return true end
    -- it99_05_: unknown
    if id_str:match("^it99_05_") then return true end
    -- it99_06_: blood collectors and devices — some freeze the game
    if id_str:match("^it99_06_") then return true end
    -- it99_07_: charms — Grace-only, risky
    if id_str:match("^it99_07_") then return true end
    -- it99_50_: keep only known-safe ones (trackers already in safe pool)
    -- blacklist unknowns and rejected items
    local it99_50_blacklist = {
        ["it99_50_000"]=true, ["it99_50_004"]=true,
        ["it99_50_011"]=true, ["it99_50_012"]=true, ["it99_50_013"]=true,
    }
    if it99_50_blacklist[id_str] then return true end
    return false
end
local frame_count = 0

local swap_log  = {}
local MAX_LOG   = 20

local AcquireOptions_Default = nil
local StockEventType_Default = nil
pcall(function()
    local o = sdk.find_type_definition("app.Inventory.AcquireItemOptions")
    if o then AcquireOptions_Default = o:get_field("Default"):get_data(nil) end
    local e = sdk.find_type_definition("app.ItemStockChangedEventType")
    if e then StockEventType_Default = e:get_field("Default"):get_data(nil) end
end)

local function tcount(t)
    local n = 0; for _ in pairs(t) do n = n + 1 end; return n
end

local function log_swap(msg)
    table.insert(swap_log, 1, msg)
    if #swap_log > MAX_LOG then table.remove(swap_log) end
    print(MOD .. " " .. msg)
end

local function get_inventory()
    local gui_td = sdk.find_type_definition("app.GuiUtil")
    if not gui_td then return nil end
    local m = gui_td:get_method("getInventory")
    if not m then return nil end
    local ok, inv = pcall(function() return m:call(nil) end)
    return ok and inv or nil
end

-- Check if inventory can hold an item, reroll if not
local function resolve_item(id_obj, orig_id_str)
    local inv = get_inventory()
    if not inv or not id_obj then return id_obj end

    local ok, can = pcall(function()
        return inv:call("canContain(app.ItemID)", id_obj)
    end)
    if ok and can then return id_obj end  -- compatible, use as-is

    -- Incompatible — pick random compatible item from pool
    if #reroll_pool == 0 then return id_obj end

    -- Shuffle a few random candidates until we find a compatible one
    local attempts = math.min(20, #reroll_pool)
    for _ = 1, attempts do
        local candidate = reroll_pool[math.random(#reroll_pool)]
        if candidate and candidate.id_obj then
            local ok2, can2 = pcall(function()
                return inv:call("canContain(app.ItemID)", candidate.id_obj)
            end)
            if ok2 and can2 then
                log_swap(string.format("  reroll: %s incompatible → using %s", orig_id_str, candidate.name))
                return candidate.id_obj, candidate.name
            end
        end
    end

    return id_obj  -- give up, use original replacement
end

local function give_item(item_id_obj, count)
    local inv = get_inventory()
    if not inv or not item_id_obj then return false end
    local d = sdk.create_instance("app.ItemStockData")
    if not d then return false end
    d = d:add_ref()
    d:call(".ctor(app.ItemID, System.Int32)", item_id_obj, count or 1)
    _is_adding = true
    pcall(function()
        inv:call(
            "mergeOrAdd(app.ItemAmountData, System.Boolean, app.Inventory.AcquireItemOptions, app.ItemStockChangedEventType)",
            d, true, AcquireOptions_Default, StockEventType_Default
        )
    end)
    _is_adding = false
    return true
end

local function build_item_id_map()
    local td = sdk.find_type_definition("app.ItemID")
    if not td then print(MOD .. " ERROR: app.ItemID not found"); return end
    local count = 0
    for _, f in ipairs(td:get_fields()) do
        if f:is_static() and f:get_type() == td then
            local name = f:get_name()
            local ok, id_obj = pcall(function() return f:get_data(nil) end)
            if ok and id_obj then
                id_by_name[name] = id_obj
                count = count + 1
            end
        end
    end
    print(MOD .. " ItemID map: " .. count .. " entries")
end

local function load_seed()
    log.info(MOD .. " load_seed called, id_by_name size=" .. tcount(id_by_name))
    local ok, data = pcall(json.load_file, SEED_PATH)
    if not ok or type(data) ~= "table" then
        print(MOD .. " Could not load: " .. SEED_PATH)
        seed_data = nil; substitutions = {}; return false
    end
    seed_data = data
    substitutions = {}
    swap_count = 0
    swap_log = {}
    local loaded, skipped = 0, 0
    for orig_name, repl_name in pairs(data.substitutions or {}) do
        local orig_obj = id_by_name[orig_name]
        local repl_obj = id_by_name[repl_name]
        if orig_obj and repl_obj then
            local tok, orig_str = pcall(function() return orig_obj:call("ToString") end)
            local key = (tok and orig_str and orig_str ~= "") and orig_str or orig_name
            substitutions[key] = { id_obj = repl_obj, name = repl_name }
            loaded = loaded + 1
        else
            skipped = skipped + 1
        end
    end
    -- Build reroll pool from hardcoded safe whitelists only
    reroll_pool = {}
    local consumable_pool = {}
    local weapon_pool = {}
    for name, id_obj in pairs(id_by_name) do
        if safe_consumables[name] then
            table.insert(consumable_pool, { id_obj = id_obj, name = name })
        elseif safe_weapons[name] then
            table.insert(weapon_pool, { id_obj = id_obj, name = name })
        end
    end
    for _, s in ipairs(consumable_pool) do table.insert(reroll_pool, s) end
    local weapon_slots = math.max(1, math.floor(#consumable_pool * 0.15 / 0.85))
    for i = 1, math.min(weapon_slots, #weapon_pool) do
        table.insert(reroll_pool, weapon_pool[i])
    end
    -- Debug: print what prefixes we actually found
    local prefix_counts = {}
    for name, _ in pairs(id_by_name) do
        local p = name:match("^(it%d%d)")
        if p then prefix_counts[p] = (prefix_counts[p] or 0) + 1 end
    end
    local prefix_str = ""
    for p, c in pairs(prefix_counts) do prefix_str = prefix_str .. p .. "=" .. c .. " " end
    log.info(MOD .. " ID prefixes: " .. prefix_str)
    log.info(string.format("%s Pool: %d consumables + %d weapons = %d total", MOD, #consumable_pool, math.min(weapon_slots, #weapon_pool), #reroll_pool))

    print(string.format("%s Loaded seed=%s run=%s subs=%d skipped=%d pool=%d",
        MOD, tostring(data.seed), tostring(data.run), loaded, skipped, #reroll_pool))
    return true
end

local function install_hook()
    if hook_installed then return end

    local inv_td = sdk.find_type_definition("app.Inventory")
    if not inv_td then print(MOD .. " ERROR: app.Inventory not found"); return end

    local last_swap_frame = {}  -- dedup: orig_id_str -> frame_count

    local hooked = 0
    for _, m in ipairs(inv_td:get_methods()) do
        if m:get_name() == "mergeOrAdd" then
            pcall(function()
                sdk.hook(m,
                    function(args)
                        if _is_adding then return sdk.PreHookResult.CALL_ORIGINAL end
                        if not seed_data or not next(substitutions) then return sdk.PreHookResult.CALL_ORIGINAL end

                        local ok1, arr = pcall(function() return sdk.to_managed_object(args[3]) end)
                        if not ok1 or not arr then return sdk.PreHookResult.CALL_ORIGINAL end

                        local ok_len, len = pcall(function() return arr:call("get_Length") end)
                        if not ok_len or not len or len == 0 then return sdk.PreHookResult.CALL_ORIGINAL end

                        for i = 0, len - 1 do
                            local ok2, item_data = pcall(function() return arr:call("GetValue(System.Int32)", i) end)
                            if not ok2 or not item_data then goto continue end

                            local ok3, id_obj = pcall(function() return item_data:call("get_ItemID") end)
                            if not ok3 or not id_obj then goto continue end

                            local ok4, id_str = pcall(function() return id_obj:call("ToString") end)
                            if not ok4 or not id_str or id_str == "" then goto continue end

                            -- Never randomise key items or story items
                            if is_protected_original(id_str) then goto continue end

                            -- Dedup: one swap per item ID per frame (prevents multi-overload dupes)
                            if last_swap_frame[id_str] == frame_count then goto continue end
                            last_swap_frame[id_str] = frame_count

                            -- Pick replacement: random for consumables, seeded for everything else
                            local final_id_obj, final_name
                            local inv = get_inventory()

                            -- Helper: pick a random compatible non-duplicate from pool
                            local function pick_from_pool()
                                for _ = 1, math.min(50, #reroll_pool) do
                                    local c = reroll_pool[math.random(#reroll_pool)]
                                    if c and c.id_obj and not is_blacklisted(c.name) then
                                        if is_weapon_or_part(c.name) and given_items[c.name] then
                                            -- skip already-given weapons
                                        elseif c.name and c.name:match("^it60_") and given_keys[c.name] then
                                            -- skip already-given key items
                                        else
                                            if inv then
                                                local ok_c, can = pcall(function() return inv:call("canContain(app.ItemID)", c.id_obj) end)
                                                if ok_c and can then return c end
                                            else
                                                return c
                                            end
                                        end
                                    end
                                end
                                return nil
                            end

                            if is_always_random(id_str) then
                                local c = pick_from_pool()
                                if c then final_id_obj = c.id_obj; final_name = c.name end
                            else
                                local sub = substitutions[id_str]
                                if sub and is_blacklisted(sub.name) then sub = nil end
                                if sub then
                                    final_id_obj = sub.id_obj
                                    final_name = sub.name
                                    local needs_reroll = false
                                    -- Already given this weapon? Reroll
                                    if is_weapon_or_part(final_name) and given_items[final_name] then
                                        needs_reroll = true
                                    -- Already given this key item? Reroll
                                    elseif final_name and final_name:match("^it60_") and given_keys[final_name] then
                                        needs_reroll = true
                                    -- Seed wants to give a weapon: only allow 15% of the time
                                    elseif is_weapon_or_part(final_name) and math.random(100) > 15 then
                                        needs_reroll = true
                                    -- Incompatible with current character? Reroll
                                    elseif inv then
                                        local ok_c, can = pcall(function() return inv:call("canContain(app.ItemID)", final_id_obj) end)
                                        if ok_c and not can then needs_reroll = true end
                                    end
                                    if needs_reroll then
                                        local c = pick_from_pool()
                                        if c then final_id_obj = c.id_obj; final_name = c.name end
                                    end
                                end
                            end

                            if final_id_obj then
                                local mutated = false
                                pcall(function() item_data:call("set_ItemID", final_id_obj); mutated = true end)
                                if not mutated then
                                    pcall(function() item_data:set_field("_itemID", final_id_obj); mutated = true end)
                                end
                                if mutated then
                                    local count = 1
                                    if is_always_random(id_str) then
                                        -- Use lookup quantity for the replacement item
                                        count = default_qty(final_name)
                                        pcall(function() item_data:call("set_Stock(System.Int32)", count) end)
                                        pcall(function() item_data:set_field("_Stock", count) end)
                                    else
                                        local ok5, amt = pcall(function() return item_data:call("get_Stock") end)
                                        if ok5 and type(amt) == "number" and amt > 0 then count = amt end
                                    end
                                    if is_weapon_or_part(final_name) then given_items[final_name] = true end
                                    if final_name and final_name:match("^it60_") then given_keys[final_name] = true end
                                    table.insert(pending_swaps, { orig_id_str = id_str, repl = { id_obj = final_id_obj, name = final_name }, count = count })
                                end
                            end

                            ::continue::
                        end
                        return sdk.PreHookResult.CALL_ORIGINAL
                    end,
                    function(retval) return retval end
                )
            end)
            hooked = hooked + 1
        end
    end

    if hooked > 0 then
        hook_installed = true
        print(MOD .. " Hooked mergeOrAdd x" .. hooked)
    else
        print(MOD .. " ERROR: failed to hook mergeOrAdd")
    end
end

re.on_frame(function() frame_count = frame_count + 1 end)

re.on_frame(function()
    if init_done then return end
    init_done = true
    pcall(build_item_id_map)
    if next(id_by_name) then
        pcall(load_seed)
        pcall(install_hook)
    end
end)

re.on_frame(function()
    if #pending_swaps == 0 or _is_adding then return end
    local swap = table.remove(pending_swaps, 1)
    if not swap then return end


    swap_count = swap_count + 1
    log_swap(string.format("Swap #%d: %s → %s (x%d)",
        swap_count, swap.orig_id_str, swap.repl.name, swap.count))
end)


-- ============================================================
--  Race Mode — death tracking + stats.json writer
-- ============================================================
local STATS_PATH        = "re9_randomiser/stats.json"
local race_deaths       = 0
local race_start        = nil
local last_stats_write  = 0
local last_gameover_count = -1  -- poll-based death detection

local function get_race_time()
    if not race_start then return 0 end
    return os.clock() - race_start
end

local function write_stats()
    local t = os.clock()
    if t - last_stats_write < 3 then return end
    last_stats_write = t
    local ok, err = pcall(function()
        json.dump_file(STATS_PATH, { deaths = race_deaths, time = math.floor(get_race_time()) })
    end)
    if not ok then log.info(MOD .. " write_stats error: " .. tostring(err)) end
end

-- Hook requestGameOver — should only fire on actual player death
local last_death_frame = -9999
local DEATH_DEBOUNCE_FRAMES = 300

local _hooked_death = pcall(function()
    sdk.hook(
        sdk.find_type_definition("app.GameOverManager"):get_method("requestGameOver"),
        function(args)
            if frame_count - last_death_frame < DEATH_DEBOUNCE_FRAMES then return end
            last_death_frame = frame_count
            race_deaths = race_deaths + 1
            log.info(MOD .. " Death #" .. race_deaths .. " recorded (requestGameOver, frame " .. frame_count .. ")")
            write_stats()
        end,
        function(retval) return retval end
    )
end)
if _hooked_death then
    log.info(MOD .. " Death hook: requestGameOver installed")
else
    log.info(MOD .. " Death hook: requestGameOver FAILED")
end

re.on_frame(function()
    if swap_count > 0 and race_start == nil then
        race_start = os.clock()
        log.info(MOD .. " Race timer started")
    end
    if race_start then write_stats() end
end)


re.on_draw_ui(function()
    if not imgui.tree_node("RE9 Item Randomiser") then return end

    if seed_data then
        imgui.text_colored("● Seed active", 0xff00dd44)
        imgui.text("  Seed:  " .. tostring(seed_data.seed))
        imgui.text("  Run:   " .. tostring(seed_data.run))
        imgui.text("  Subs:  " .. tcount(substitutions))
        imgui.text("  Swaps: " .. tostring(swap_count))
    else
        imgui.text_colored("● No seed loaded", 0xff4444ff)
    end

    imgui.text("Hook: " .. (hook_installed and "mergeOrAdd ✓" or "NOT installed ✗"))
    imgui.separator()
    imgui.text_colored("Race stats:", 0xffffaa00)
    imgui.text("  Deaths: " .. tostring(race_deaths))
    imgui.text("  Time:   " .. string.format("%.1fs", get_race_time()))
    imgui.text("  Timer:  " .. (race_start and "running" or "not started"))

    if imgui.button("Reload seed.json") then
        seed_data = nil; substitutions = {}; swap_count = 0; swap_log = {}; reroll_pool = {}; given_items = {}; given_keys = {}; race_deaths = 0; race_start = nil
        if not next(id_by_name) then pcall(build_item_id_map) end
        pcall(load_seed)
    end

    if next(swap_log) then
        imgui.separator()
        imgui.text("Recent swaps:")
        for _, s in ipairs(swap_log) do
            imgui.text_colored(s, 0xff44ff44)
        end
    end

    imgui.tree_pop()
end)