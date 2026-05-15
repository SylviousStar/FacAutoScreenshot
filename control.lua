local basetracker = require("scripts.basetracker")
local gui = require("scripts.gui")
local l = require("scripts.logger")
local queue = require("scripts.queue")
local shooter = require("scripts.shooter")
local snip = require("scripts.snip")

local function loadDefaultsForPlayer(index)
    log(l.info("loading defaults for player " .. index))

    if not storage.auto[index] then
        l.info("storage.auto was nil")
        storage.auto[index] = {}
    end
    if not storage.auto[index].zoom then
        l.info("storage.auto.zoom was nil")
        storage.auto[index].zoom = {}
    end
    if not storage.auto[index].zoomLevel then
        l.info("storage.auto.zoomlevel was nil")
        storage.auto[index].zoomLevel = {}
    end

    if storage.auto[index].manualZoom == nil then storage.auto[index].manualZoom = false end
    log(l.info("manualZoom is " .. (storage.auto[index].manualZoom and "on" or "off")))

    if not storage.auto[index].manualZoomLevel then storage.auto[index].manualZoomLevel = 1 end
    log(l.info("storage.auto.manualZoomLevel is " .. storage.auto[index].manualZoomLevel))

    if storage.auto[index].interval == nil then storage.auto[index].interval = 10 * 60 * 60 end
    log(l.info("interval is " .. (storage.auto[index].interval / 60 / 60)) .. " min")

    if storage.auto[index].resX == nil then
        storage.auto[index].resolution_index = 3
        storage.auto[index].resX = 3840
        storage.auto[index].resY = 2160
    end

    log(l.info("resolution is " .. storage.auto[index].resX .. "x" .. storage.auto[index].resY))

    if storage.auto[index].singleScreenshot == nil then storage.auto[index].singleScreenshot = true end
    log(l.info("singleScreenshot is " .. (storage.auto[index].singleScreenshot and "on" or "off")))

    if storage.auto[index].splittingFactor == nil then storage.auto[index].splittingFactor = 1 end
    log(l.info("splittingFactor is " .. storage.auto[index].splittingFactor))

    if not storage.auto[index].doSurface then storage.auto[index].doSurface = {} end
    for _, surface in pairs(game.surfaces) do
        log(l.info("does surface " .. surface.name .. ": " ..
            (storage.auto[index].doSurface[surface.name] and "true" or "false")))
    end

    if not storage.snip[index] then
        l.info("storage.snip was nil")
        storage.snip[index] = {}
    end
    if not storage.snip[index].area then
        l.info("storage.snip.area was nil")
        storage.snip[index].area = {}
    end

    if storage.snip[index].showAltMode == nil then storage.snip[index].showAltMode = false end
    log(l.info("snip show alt mode is " .. (storage.snip[index].showAltMode and "true" or "false")))

    if storage.snip[index].showUI == nil then storage.snip[index].showUI = false end
    log(l.info("snip show ui is " .. (storage.snip[index].showUI and "true" or "false")))

    if storage.snip[index].showCursorBuildingPreview == nil then storage.snip[index].showCursorBuildingPreview = false end
    log(l.info("snip show cursor building preview is " ..
    (storage.snip[index].showCursorBuildingPreview and "true" or "false")))

    if storage.snip[index].useAntiAlias == nil then storage.snip[index].useAntiAlias = false end
    log(l.info("snip use anti alias is " .. (storage.snip[index].useAntiAlias and "true" or "false")))

    if not storage.snip[index].zoomLevel then storage.snip[index].zoomLevel = 1 end
    log(l.info("snip zoomlevel is " .. storage.snip[index].zoomLevel))

    if not storage.snip[index].output_format_index then storage.snip[index].output_format_index = 1 end
    log(l.info("snip output format index is " .. storage.snip[index].output_format_index))

    if not storage.snip[index].jpg_quality then storage.snip[index].jpg_quality = 100 end
    log(l.info("jpg quality is " .. storage.snip[index].jpg_quality))


    shooter.evaluateZoomForPlayerAndAllSurfaces(index)
end

local function initializePlayer(player)
    loadDefaultsForPlayer(player.index)
    queue.initialize(player.index)
    gui.initialize(player)
end

-- this method resets everything to a default state apart from already registered screenshots or user settings
local function initialize()
    log(l.info("initialize"))

    storage.verbose = settings.global["FAS-enable-debug"].value
    if not storage.auto then storage.auto = {} end
    if not storage.snip then storage.snip = {} end
    storage.tracker = {}
    storage.gui = {}
    storage.flowButton = {}
    if not storage.queue then storage.queue = {} end

    for _, surface in pairs(game.surfaces) do
        basetracker.initializeSurface(surface.name)
    end

    for _, player in pairs(game.connected_players) do
        log(l.info("found player: " .. player.name))
        initializePlayer(player)
    end

    queue.refreshNextScreenshotTimestamp()
end



--#region -~[[ EVENT HANDLERS ]]~-
local function on_init(event)
    log(l.info("on init triggered"))
    initialize()
end

local function on_configuration_changed(event)
    if event.mod_changes.FacAutoScreenshot_Updated then
        log(l.info("configuration of FAS changed"))
        initialize()
    end
end

local function on_runtime_mod_setting_changed(event)
    if event.setting_type == "runtime-global" then
        storage.verbose = settings.global["FAS-enable-debug"].value
        log(l.info("debug mode is now " .. (l.doD() and "on" or "off")))
    end
end

local function on_nth_tick(event)
    log(l.info("on nth tick"))
    -- if something was built in the last minute that should cause a recalc of all zoom levels
    if basetracker.checkForMinMaxChange() then
        shooter.evaluateZoomForAllPlayersAndAllSurfaces()
    end

    local newRegistrations = false
    for _, player in pairs(game.connected_players) do
        if l.doD then log(l.debug("player ", player.name, " with index ", player.index, " found")) end
        if l.doD then log(l.debug("do screenshot:   ", queue.doesAutoScreenshot(player.index))) end
        if l.doD then log(l.debug("interval:        ", storage.auto[player.index].interval)) end
        if l.doD then log(l.debug("singleScreenshot:", storage.auto[player.index].singleScreenshot)) end
        if l.doD then log(l.debug("tick:            ", game.tick)) end

        if queue.doesAutoScreenshot(player.index) and (event.tick % storage.auto[player.index].interval == 0) then
            queue.registerPlayerToQueue(player.index)
            newRegistrations = true
        end
    end

    if newRegistrations then queue.refreshNextScreenshotTimestamp() end
end

local function on_tick()
    if queue.hasAnyEntries() then
        -- shooter.renderNextQueueStep(queue.getNextStep())
        if queue.executeNextStep() then
            gui.setStatusValue()
        else
            gui.refreshStatusCountdown()
        end
    else
        if game.tick % 60 == 0 then
            gui.refreshStatusCountdown()
        end
    end
end

local function on_player_joined_game(event)
    log(l.info("player " .. event.player_index .. " joined"))
    initializePlayer(game.get_player(event.player_index))
    queue.refreshNextScreenshotTimestamp()
end

local function on_player_left_game(event)
    log(l.info("player " .. event.player_index .. " left"))
    queue.refreshNextScreenshotTimestamp()
end

local function on_player_cursor_stack_changed(event)
    log(l.info("on_player_cursor_stack_changed triggered for player " .. event.player_index))
    local index = event.player_index
    if storage.snip[index].doesSelection then
        local stack = game.get_player(index).cursor_stack
        if stack and (not stack.valid_for_read or stack.name ~= "FAS-selection-tool") then
            log(l.info("reverting to not selecting area"))
            storage.snip[index].doesSelection = false
            gui.unhighlightSelectAreaButton(index)
        end
    end
end

local function on_built_entity(event)
    local pos = event.entity.position
    local surface = event.entity.surface.name
    if l.doD then log(l.debug("entity built on surface", surface, "at pos:", pos.x, "x", pos.y)) end
    if basetracker.breaksCurrentLimits(pos, surface) then
        basetracker.evaluateMinMaxFromPosition(pos, surface)
    end
end




-- #region  gui event handlers
local handlers = {}

--  #region click handlers
function handlers.togglegui_click(event)
    gui.togglegui(event.player_index)
end

function handlers.gui_close_click(event)
    gui.togglegui(event.player_index)
end

function handlers.auto_content_collapse_click(event)
    log(l.info("auto_content_collapse was clicked by player " .. event.player_index))
    gui.toggle_auto_content_area(event.player_index)
end

-- TODO: have a list of zoom leveles for different surfaces
function handlers.surface_checkbox_click(event)
    log(l.info("surface_checkbox was triggered for player " .. event.player_index))
    storage.auto[event.player_index].doSurface[event.element.caption] = event.element.state

    if storage.auto[event.player_index].zoomLevel[event.element.caption] == nil then
        if l.doD then log(l.debug("Zoomlevel was nil when changing surface selection")) end
        shooter.evaluateZoomForPlayerAndAllSurfaces(event.player_index)
    end
    queue.refreshNextScreenshotTimestamp()
    gui.refreshStatusCountdown()
end

function handlers.auto_zoom_check_value_click(event)
    log(l.info(("auto zoom check value was changed for player " .. event.player_index)))
    local doesSingle = event.element.state
    storage.auto[event.player_index].manualZoom = not doesSingle
    storage.gui[event.player_index].auto_zoom_flow.visible = not doesSingle
end

function handlers.single_tick_value_click(event)
    log(l.info(("single tick value was changed for player " .. event.player_index)))
    local doesSingle = event.element.state
    storage.auto[event.player_index].singleScreenshot = doesSingle
    storage.gui[event.player_index].splitting_factor_flow.visible = not doesSingle
end

function handlers.area_content_collapse_click(event)
    log(l.info("area_content_collapse was clicked by player " .. event.player_index))
    gui.toggle_area_content_area(event.player_index)
end

function handlers.select_area_button_FAS_click(event)
    log(l.info("select area button was clicked by player " .. event.player_index))
    local index = event.player_index
    storage.snip[index].doesSelection = not storage.snip[index].doesSelection

    if storage.snip[index].doesSelection then
        gui.givePlayerSelectionTool(index)
        gui.highlightSelectAreaButton(index)
    else
        gui.clearPlayerCursorStack(index)
        gui.unhighlightSelectAreaButton(index)
    end
end

function handlers.delete_area_button_click(event)
    log(l.info("delete area button was clicked by player " .. event.player_index))
    snip.resetArea(event.player_index)
    snip.calculateEstimates(event.player_index)

    gui.resetAreaValues(event.player_index)
    gui.refreshEstimates(event.player_index)
    gui.refreshStartHighResScreenshotButton(event.player_index)
end

function handlers.daytime_switch_value_changed(event)
    log(l.info("daytime switch was switched for player " ..
    event.player_index .. " to state " .. event.element.switch_state))
    storage.snip[event.player_index].daytime_state = event.element.switch_state
end

function handlers.show_ui_value_click(event)
    log(l.info("show ui tickbox was clicked for player " .. event.player_index))
    storage.snip[event.player_index].showUI = event.element.state
    if l.doD then log(l.debug("snip show ui is " .. (storage.snip[event.player_index].showUI and "true" or "false"))) end
end

function handlers.alt_mode_value_click(event)
    log(l.info("show alt mode tickbox was clicked for player " .. event.player_index))
    storage.snip[event.player_index].showAltMode = event.element.state
    if l.doD then log(l.debug("snip show alt mode is " ..
        (storage.snip[event.player_index].showAltMode and "true" or "false"))) end
end

function handlers.show_cursor_building_preview_value_click(event)
    log(l.info("show cursor building preview tickbox was clicked for player " .. event.player_index))
    storage.snip[event.player_index].showCursorBuildingPreview = event.element.state
    if l.doD then log(l.debug("snip show cursor building preview is " ..
        (storage.snip[event.player_index].showCursorBuildingPreview and "true" or "false"))) end
end

function handlers.use_anti_alias_value_click(event)
    log(l.info("use anti alias tickbox was clicked for player " .. event.player_index))
    storage.snip[event.player_index].useAntiAlias = event.element.state
    if l.doD then log(l.debug("snip ue anti alias is " ..
        (storage.snip[event.player_index].useAntiAlias and "true" or "false"))) end
end

function handlers.start_area_screenshot_button_click(event)
    log(l.info("start high res screenshot button was pressed by player " .. event.player_index))
    shooter.renderAreaScreenshot(event.player_index)
end

--  #endregion click handlers

--  #region value changed handlers
function handlers.auto_zoom_slider_value_changed(event)
    log(l.info("auto zoom slider was moved"))
    local level = math.pow(2, event.element.slider_value)
    storage.gui[event.player_index].auto_zoom_value.text = tostring(level)
    storage.auto[event.player_index].manualZoomLevel = level
    shooter.evaluateZoomForPlayerAndAllSurfaces(event.player_index) -- update zoom level using manualZoomLevel
end

function handlers.splitting_factor_slider_value_changed(event)
    log(l.info("splitting factor was changed for player " .. event.player_index))
    local splittingFactor = math.pow(4, event.element.slider_value)
    storage.auto[event.player_index].splittingFactor = splittingFactor
    storage.gui[event.player_index].splitting_factor_value.text = tostring(splittingFactor)
end

function handlers.zoom_slider_value_changed(event)
    log(l.info("zoom slider was moved"))
    local level = math.pow(2, event.element.slider_value)
    storage.gui[event.player_index].zoom_value.text = tostring(level)
    storage.snip[event.player_index].zoomLevel = level
    snip.calculateEstimates(event.player_index)
    gui.refreshEstimates(event.player_index)
    gui.refreshStartHighResScreenshotButton(event.player_index)
end

function handlers.area_jpg_quality_slider_value_changed(event)
    log(l.info("quality slider was moved"))
    local level = event.element.slider_value
    storage.gui[event.player_index].area_jpg_quality_value.text = tostring(level)
    storage.snip[event.player_index].jpg_quality = level
end

--#endregion value changed handlers

--  #region text changed handlers
function handlers.interval_value_text_changed(event)
    log(l.info("interval was changed for player " .. event.player_index))
    local suggestion = tonumber(event.text)
    if suggestion == nil then return end
    if suggestion < 1 or suggestion > 60 then
        event.element.text = tostring(storage.auto[event.player_index].interval / 3600)
        return
    end

    storage.auto[event.player_index].interval = suggestion * 60 * 60

    queue.refreshNextScreenshotTimestamp()
    gui.refreshStatusCountdown()
end

function handlers.area_output_name_text_changed(event)
    log(l.info("area output name changed"))
    storage.snip[event.player_index].outputName = event.element.text
end

--#endregion text changed handlers

--  #region selection handlers
function handlers.auto_resolution_value_selection(event)
    log(l.info("resolution setting was changed for player " ..
    event.player_index .. " with index " .. event.element.selected_index
    ))
    local resolution_index = event.element.selected_index
    if resolution_index == 1 then
        storage.auto[event.player_index].resolution_index = 1
        storage.auto[event.player_index].resX = 15360;
        storage.auto[event.player_index].resY = 8640;
    elseif resolution_index == 2 then
        storage.auto[event.player_index].resolution_index = 2
        storage.auto[event.player_index].resX = 7680;
        storage.auto[event.player_index].resY = 4320;
    elseif resolution_index == 3 then
        storage.auto[event.player_index].resolution_index = 3
        storage.auto[event.player_index].resX = 3840
        storage.auto[event.player_index].resY = 2160
    elseif resolution_index == 4 then
        storage.auto[event.player_index].resolution_index = 4
        storage.auto[event.player_index].resX = 1920
        storage.auto[event.player_index].resY = 1080
    elseif resolution_index == 5 then
        storage.auto[event.player_index].resolution_index = 5
        storage.auto[event.player_index].resX = 1280
        storage.auto[event.player_index].resY = 720
    else
        log(l.warn("could not match resolution index " .. resolution_index))
    end
    storage.auto[event.player_index].zoom = {}
    storage.auto[event.player_index].zoomLevel = {}
    shooter.evaluateZoomForPlayerAndAllSurfaces(event.player_index)
end

function handlers.area_output_format_selection(event)
    log(l.info("area output format changed"))
    storage.snip[event.player_index].output_format_index = event.element.selected_index
    storage.gui[event.player_index].area_jpg_quality_flow.visible = event.element.selected_index == 2
    gui.refreshEstimates(event.player_index)
end

--  #endregion selection handlers

-- #endregion gui event handlers


-- #region gui event handler picker
local function callHandler(event, suffix)
    local handlerMethod

    if string.find(event.element.name, "surface_checkbox") then
        handlerMethod = handlers["surface_checkbox_click"]
    else
        -- handler methods have to be called the same as the element that shall trigger them
        handlerMethod = handlers[event.element.name .. suffix]
    end

    -- if a handler method exists the gui press was for an element of this mod
    if handlerMethod then
        handlerMethod(event)
    else
        log(l.warn("Couldn't find handler method " .. event.element.name .. suffix))
    end
end

local function on_gui_click(event)
    log(l.info("on_gui_click triggered with element name " .. event.element.name))
    callHandler(event, "_click")
end

local function on_gui_value_changed(event)
    log(l.info("on_gui_value_changed triggered with element name " .. event.element.name))
    callHandler(event, "_value_changed")
end

local function on_gui_text_changed(event)
    log(l.info("on_gui_text changed triggered with element name " .. event.element.name))
    callHandler(event, "_text_changed")
end

local function on_gui_selection_state_changed(event)
    log(l.info("on_gui_selection_state_changed event triggered with element name " .. event.element.name))
    callHandler(event, "_selection")
end

local function on_gui_switch_state_changed(event)
    log(l.info("on_gui_switch_state_changed event triggered with element name " .. event.element.name))
    callHandler(event, "_value_changed")
end
-- #endregion gui event handler picker


-- #region shortcuts handlers
local function handleAreaChange(index, new_area)
    snip.calculateArea(index, new_area)
    snip.calculateEstimates(index)

    if storage.gui[index] then
        gui.refreshAreaValues(index)
        gui.refreshEstimates(index)
        gui.refreshStartHighResScreenshotButton(index)
    end
end

function on_player_selected_area(event)
    --game.print("on_player_selected_area: ".. serpent.block(event))

    if storage.snip[event.player_index].doesSelection then
        handleAreaChange(event.player_index, event.area)
    end
end

local function on_selection_toggle(event)
    log(l.info("selection toggle shortcut was triggered by player " .. event.player_index))
    handlers.select_area_button_FAS_click(event)

    if not storage.snip[event.player_index].doesSelection and storage.snip[event.player_index].area.width then
        shooter.renderAreaScreenshot(event.player_index)
    end
end

local function on_delete_area(event)
    handlers.delete_area_button_click(event)
end

local function on_toggle_gui(event)
    handlers.togglegui_click(event)
end
-- #endregion


-- #region surfaces
local function on_pre_surface_deleted(event)
    log(l.info("surface " .. game.get_surface(event.surface_index).name .. " deleted"))

    -- delete entries of deleted surface
    for _, player in pairs(game.players) do
        if storage.auto[player.index] ~= nil then
            local name = game.get_surface(event.surface_index).name
            if storage.auto[player.index].doSurface[name] ~= nil then
                storage.auto[player.index].doSurface[name] = nil
            end

            -- if the surface was in queue for a screenshot
            if storage.queue[player.index] and storage.queue[player.index][name] then
                queue.remove(player.index, name)
            end

            -- if there was an area selection on the surface
            if storage.snip[player.index].surface_name == name then
                snip.resetArea(player.index)
            end
        end
    end

    gui.initializeAllConnectedPlayers(queue.hasAnyEntries())
end

local function on_surface_created(event)
    log(l.info("surface " .. game.get_surface(event.surface_index).name .. "created"))
    gui.initializeAllConnectedPlayers(queue.hasAnyEntries())
    basetracker.initializeSurface(game.get_surface(event.surface_index).name)
    shooter.evaluateZoomForAllPlayersAndSurface(game.get_surface(event.surface_index).name)
end

local function on_surface_imported(event)
    log(l.info("surface " .. event.original_name .. " imported with name " .. game.get_surface(event.surface_index).name))

    gui.initializeAllConnectedPlayers(queue.hasAnyEntries())
    basetracker.initializeSurface(game.get_surface(event.surface_index).name)
    shooter.evaluateZoomForAllPlayersAndSurface(game.get_surface(event.surface_index).name)
end

local function on_surface_renamed(event)
    log(l.info("surface " .. event.old_name .. " renamed to " .. event.new_name))
    for _, playerData in pairs(storage.auto) do
        if playerData.doSurface[event.old_name] ~= nil then
            playerData.doSurface[event.new_name] = playerData.doSurface[event.old_name]
            playerData.doSurface[event.old_name] = nil
        end
    end

    for _, player in pairs(game.players) do
        if storage.snip[player.index].surface_name == event.old_name then
            storage.snip[player.index].surface_name = event.new_name
        end
    end

    gui.initializeAllConnectedPlayers(queue.hasAnyEntries())
    shooter.evaluateZoomForAllPlayersAndSurface(game.get_surface(event.surface_index).name)
    basetracker.on_surface_renamed(event)
end
--#endregion


--#endregion


--#region -~[[ EVENT REGISTRATION ]]~-
script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

script.on_nth_tick(3600, on_nth_tick)
script.on_event(defines.events.on_tick, on_tick)

script.on_event(defines.events.on_player_joined_game, on_player_joined_game)
script.on_event(defines.events.on_player_left_game, on_player_left_game)
script.on_event(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_player_selected_area, on_player_selected_area)

-- gui events
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
script.on_event(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)

-- shortcuts
script.on_event("FAS-selection-toggle-shortcut", on_selection_toggle)
script.on_event("FAS-delete-area-shortcut", on_delete_area)
script.on_event("FAS-toggle-GUI", on_toggle_gui)

-- surfaces
script.on_event(defines.events.on_pre_surface_deleted, on_pre_surface_deleted)
script.on_event(defines.events.on_surface_created, on_surface_created)
script.on_event(defines.events.on_surface_imported, on_surface_imported)
script.on_event(defines.events.on_surface_renamed, on_surface_renamed)
--#endregion
