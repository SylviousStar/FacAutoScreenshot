local l = require("logger")

local shooter = {}

--[[ Zoom Evalutation ]] --
function shooter.evaluateZoomForPlayer(index, surface)
	--prevents a specific bug with rocket rush scenario
	if storage.auto[index] == nil then
		log(l.warn("storage.auto[" .. index .. "] is nil. returning"))
		return
	end

	if l.doD then log(l.debug("ev zoom for player " .. index)) end
	if l.doD then log(l.debug("resX: " .. storage.auto[index].resX)) end
	if l.doD then log(l.debug("resY: " .. storage.auto[index].resY)) end
	if l.doD then log(l.debug("storage.tracker[" .. surface .. "].limitX: " .. storage.tracker[surface].limitX)) end
	if l.doD then log(l.debug("storage.tracker[" .. surface .. "].limitY: " .. storage.tracker[surface].limitY)) end
	if l.doD then log(l.debug("old zoom: " .. (storage.auto[index].zoom[surface] or "nil"))) end
	if l.doD then log(l.debug("zoomLevel: " .. (storage.auto[index].zoomLevel[surface] or "nil"))) end

	if not storage.auto[index].zoom[surface] then storage.auto[index].zoom[surface] = 1 end
	if not storage.auto[index].zoomLevel[surface] then storage.auto[index].zoomLevel[surface] = 1 end
	-- if not storage.auto[index].autoZoom[surface] then storage.auto[index].autoZoom[surface] = 1 end
	if not storage.auto[index].autoZoomLevel[surface] then storage.auto[index].autoZoomLevel[surface] = storage.auto[index].zoomLevel[surface] end
	if not storage.auto[index].manualZoomLevel[surface] then storage.auto[index].manualZoomLevel[surface] = storage.auto[index].zoomLevel[surface] end

	if not storage.auto[index].surfaceZoomToggle[surfacename] then
		-- restore auto zoom level if using auto zoom, should be same as zoom level unless manual zoom is activated
		storage.auto[index].zoomLevel[surface] = storage.auto[index].autoZoomLevel[surface]
		storage.auto[index].zoom[surface] = 1 / storage.auto[index].zoomLevel[surface]
		log(l.info("Adjusting zoom for player " ..
		index ..
		" on surface " ..
		surface ..
		" to " .. storage.auto[index].zoom[surface] .. " and zoomlevel to " .. storage.auto[index].zoomLevel[surface]))
	else 
		storage.auto[index].zoomLevel[surface] = storage.auto[index].manualZoomLevel[surface]
		storage.auto[index].zoom[surface] = 1 / storage.auto[index].zoomLevel[surface]
		log(l.info("Adjusting zoom for player " ..
		index ..
		" on surface " ..
		surface ..
		" to " .. storage.auto[index].zoom[surface] .. " and zoomlevel to " .. storage.auto[index].zoomLevel[surface] ..
		" (Manual zoom)"))
		return
	end

	-- 7680					storage.auto.resX
	-- -------- = 0,3		------------------ = zoom
	-- 800  32				leftRight resTiles
	local zoomX = storage.auto[index].resX / (storage.tracker[surface].limitX * 2 * 32)
	local zoomY = storage.auto[index].resY / (storage.tracker[surface].limitY * 2 * 32)

	local newZoom = zoomX
	if zoomX > zoomY then
		newZoom = zoomY
	end

	local oldZoom = storage.auto[index].zoom[surface]
	while newZoom < storage.auto[index].zoom[surface] and storage.auto[index].zoomLevel[surface] < 32 do
		storage.auto[index].zoomLevel[surface] = storage.auto[index].zoomLevel[surface] + 1
		storage.auto[index].zoom[surface] = 1 / storage.auto[index].zoomLevel[surface]
		log(l.info("Adjusting zoom for player " ..
		index ..
		" on surface " ..
		surface ..
		" to " .. storage.auto[index].zoom[surface] .. " and zoomlevel to " .. storage.auto[index].zoomLevel[surface]))
	end
	if oldZoom > storage.auto[index].zoom[surface] then
		log(l.info("Adjusted zoom for player " ..
		index .. " from " .. oldZoom .. " to " .. storage.auto[index].zoom[surface]))
		if (storage.auto[index].zoom[surface] == 32) then
			log(l.warn("Player " .. index .. " reached maximum zoomlevel"))
			game.print("FAS: Player " ..
			index ..
			" reached maximum zoom level of 32. No further zooming out possible. Entities exceeding the screenshot limits will not be shown on the screenshots!")
		end
	end

	if not not storage.auto[index].surfaceZoomToggle[surfacename] then
		-- store auto calculated zoom level to be retored if manual zoom is deactivated
		storage.auto[index].autoZoomLevel[surface] = storage.auto[index].zoomLevel[surface]
		-- storage.auto[index].autoZoom[surface] = 1 / storage.auto[index].zoomLevel[surface]
	end

	if storage.gui[index] then
		-- Update gui to reflect latest auto zoom level, only runs if manual zoom is disabled
		storage.gui[index]["surface_zoom_value_" .. surface].text = tostring(storage.auto[index].zoomLevel[surface]) -- TODO: Change this to lists
		storage.gui[index]["surface_zoom_slider_" .. surface].slider_value = storage.auto[index].zoomLevel[surface]
	end
end

function shooter.evaluateZoomForPlayerAndAllSurfaces(index)
	for _, surface in pairs(game.surfaces) do
		shooter.evaluateZoomForPlayer(index, surface.name)
	end
end

function shooter.evaluateZoomForAllPlayersAndSurface(surface)
	for _, player in pairs(game.connected_players) do
		shooter.evaluateZoomForPlayer(player.index, surface)
	end
end

function shooter.evaluateZoomForAllPlayersAndAllSurfaces()
	log(l.info("ev zoom for all players"))
	for _, player in pairs(game.connected_players) do
		shooter.evaluateZoomForPlayerAndAllSurfaces(player.index)
	end
end

--[[ Screenshotting ]] --
local function buildPath(folder, title, format)
	return "./screenshots/" .. game.default_map_gen_settings.seed .. "/" .. folder .. title .. format
end


function shooter.renderAutoSingleScreenshot(index, specs)
	if l.doD then log(l.debug("rendering auto screenshot as single screenshot")) end
	if l.doD then log(l.debug("index:   " .. index)) end
	if l.doD then log(l.debug("surface: " .. specs.surface)) end
	if l.doD then log(l.debug("res:     " .. specs.resX .. "x " .. specs.resY .. "y")) end
	if l.doD then log(l.debug("zoom:    " .. specs.zoom)) end
	game.take_screenshot {
		resolution = { specs.resX, specs.resY },
		position = { 0, 0 },
		zoom = specs.zoom,
		surface = specs.surface,
		daytime = 0,
		water_tick = 0,
		by_player = index,
		path = buildPath("auto_singleTick_" .. specs.surface .. "/", "screenshot" .. game.tick, ".png"),
		hide_clouds = settings.get_player_settings(index)["Hide-clouds"].value,
		hide_fog = settings.get_player_settings(index)["Hide-fog"].value
	}
end

function shooter.renderAutoScreenshotFragment(index, fragment)
	local posX = fragment.startpos.x + fragment.stepsize.x * fragment.offset.x
	local posY = fragment.startpos.y + fragment.stepsize.y * fragment.offset.y

	if l.doD then log(l.debug("rendering next auto screenshot fragment")) end
	if l.doD then log(l.debug("index:   " .. index)) end
	if l.doD then log(l.debug("surface: " .. fragment.surface)) end
	if l.doD then log(l.debug("res:     " .. fragment.res.x .. "x " .. fragment.res.y .. "y")) end
	if l.doD then log(l.debug("zoom:    " .. fragment.zoom)) end
	if l.doD then log(l.debug("pos:     " .. posX .. "x " .. posY .. "y")) end

	game.take_screenshot {
		resolution = fragment.res,
		position = { posX, posY },
		zoom = fragment.zoom,
		surface = fragment.surface,
		by_player = index,
		water_tick = 0,
		daytime = 0,
		path = buildPath("auto_split_" .. fragment.surface .. "/", fragment.title .. "_x" .. fragment.offset.x .. "_y" .. fragment.offset.y, ".png"),
		hide_clouds = settings.get_player_settings(index)["Hide-clouds"].value,
		hide_fog = settings.get_player_settings(index)["Hide-fog"].value
	}

	-- the first screenshot is the screenshot 0 0, therefore +1
	storage.auto.amount = fragment.offset.y * fragment.numberOfTiles + fragment.offset.x + 1
	storage.auto.total = fragment.numberOfTiles * fragment.numberOfTiles
end

function shooter.renderAreaScreenshot(index)
	log(l.info("shooter.renderAreaScreenshot was triggered"))
	if l.doD then
		log(l.debug("index:       " .. index))
		log(l.debug("area.top:    " .. storage.snip[index].area.top))
		log(l.debug("area.bottom: " .. storage.snip[index].area.bottom))
		log(l.debug("area.left:   " .. storage.snip[index].area.left))
		log(l.debug("area.right:  " .. storage.snip[index].area.right))
		log(l.debug("zoomlevel:   " .. storage.snip[index].zoomLevel))
		log(l.debug("daytime:     " .. (storage.snip[index].daytime_state or "none")))
		log(l.debug("show alt m.: " .. (storage.snip[index].showAltMode and "true" or "false")))
		log(l.debug("show ui:     " .. (storage.snip[index].showUI and "true" or "false")))
		log(l.debug("show cur b.: " .. (storage.snip[index].showCursorBuildingPreview and "true" or "false")))
		log(l.debug("use antial.: " .. (storage.snip[index].useAntiAlias and "true" or "false")))
		log(l.debug("output name: " .. (storage.snip[index].outputName or "screenshot")))
		log(l.debug("format:      " .. storage.snip[index].output_format_index))
		log(l.debug("jpg quality: " .. storage.snip[index].jpg_quality))
		log(l.debug("surface_name:" .. storage.snip[index].surface_name))
	end

	local width = storage.snip[index].area.right - storage.snip[index].area.left
	local heigth = storage.snip[index].area.bottom - storage.snip[index].area.top

	local zoom = 1 / storage.snip[index].zoomLevel
	local resX = math.floor(width * 32 * zoom)
	local resY = math.floor(heigth * 32 * zoom)
	local posX = storage.snip[index].area.left + width / 2
	local posY = storage.snip[index].area.top + heigth / 2

	local surface = game.surfaces[storage.snip[index].surface_name]

	local dstate = storage.snip[index].daytime_state
	if dstate == nil or dstate == "none" then
		dstate = surface.daytime
	elseif dstate == "left" then
		dstate = 0
	else
		dstate = 0.5
	end
	if l.doD then log(l.debug("dstate ended up being " .. dstate)) end

	local name = storage.snip[index].outputName
	if not name then name = "screenshot" end
	local format = "." .. (storage.snip[index].output_format_index == 1 and "png" or "jpg")
	local path = buildPath("area/", name .. "_" .. game.tick .. "_" .. resX .. "x" .. resY, format)

	game.take_screenshot {
		resolution = { resX, resY },
		position = { posX, posY },
		surface = surface,
		zoom = zoom,
		by_player = index,
		path = path,
		show_gui = storage.snip[index].showUI,
		show_entity_info = storage.snip[index].showAltMode,
		show_cursor_building_preview = storage.snip[index].showCursorBuildingPreview,
		anti_allias = storage.snip[index].useAntiAlias,
		daytime = dstate,
		quality = storage.snip[index].jpg_quality,
		hide_clouds = settings.get_player_settings(index)["Hide-clouds"].value,
		hide_fog = settings.get_player_settings(index)["Hide-fog"].value
	}
	game.get_player(index).print({ "FAS-did-screenshot", path })
end

return shooter
