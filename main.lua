local j1l1jil1i=Path2DControlPoint.new(UDim2.new(0,0,0,0))
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local args = ...
if type(args) == "table" and args.Username then
	shared.ValidatedUsername = args.Username
end

if type(args) == "table" and args.Closet then
	getgenv().Closet = true
elseif getgenv().Closet == nil then
	getgenv().Closet = false
end

getgenv().isSkidPaid = true

local _realLoadstring = clonefunction(loadstring)
local vape
local loadstring = function(...)
	local res, err = _realLoadstring(...)
	if err and vape then
		vape:CreateNotification('Fuzzynuts', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end

local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))

local function downloadFile(path, func)
	if not isfile(path) then
		local res
		local success = false
		for attempt = 1, 3 do
			local suc, result = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/toodiesjamming-stack/Fuzzynuts/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
			end)
			if suc and result ~= '404: Not Found' then
				res = result
				success = true
				break
			end
			task.wait(1)
		end
		if not success then
			error('Failed to download ' .. path .. ' after 3 attempts')
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function migrateProfiles()
	if isfile('newvape/profiles/migrated_placeid.txt') then return end
	local oldId = tostring(game.GameId)
	local newId = tostring(game.PlaceId)
	if oldId == newId then
		pcall(writefile, 'newvape/profiles/migrated_placeid.txt', 'done')
		return
	end
	local suffix = oldId .. '.txt'
	for _, path in ipairs(listfiles('newvape/profiles')) do
		local name = path:gsub('\\', '/')
		if name:sub(-#suffix) == suffix then
			local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
			if not isfile(newPath) then
				pcall(function() writefile(newPath, readfile(path)) end)
			end
		end
	end
	if isfolder('newvape/profiles/premade') then
		for _, path in ipairs(listfiles('newvape/profiles/premade')) do
			local name = path:gsub('\\', '/')
			if name:sub(-#suffix) == suffix then
				local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
				if not isfile(newPath) then
					pcall(function() writefile(newPath, readfile(path)) end)
				end
			end
		end
	end
	pcall(writefile, 'newvape/profiles/migrated_placeid.txt', 'done')
end
pcall(migrateProfiles)

local function finishLoading()
	vape.Init = nil
	if not vape.Load then
		warn('[Fuzzynuts] vape.Load is nil skipping load')
		return
	end
	vape:Load()
	vape:Clean(task.spawn(function()
		repeat
			pcall(vape.Save, vape)
			task.wait(10)
		until vape.Loaded == nil
	end))
	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				loadstring(game:HttpGet('https://raw.githubusercontent.com/toodiesjamming-stack/Fuzzynuts/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n' .. teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "' .. shared.VapeCustomProfile .. '"\n' .. teleportScript
			end
			if shared.ValidatedUsername then
				teleportScript = 'shared.ValidatedUsername = "' .. shared.ValidatedUsername .. '"\n' .. teleportScript
			end
			local _ok, _err = pcall(function() vape:Save() end)
			if not _ok then warn('[Fuzzynuts] save failed before teleport: ' .. tostring(_err)) toclipboard(_err) end
			queue_on_teleport(teleportScript)
		end
	end))
	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			local name = shared.ValidatedUsername and ('wsg, ' .. shared.ValidatedUsername .. ' :D ') or 'welcome '
			vape:CreateNotification('[Fuzzynuts] Finished Loading', name .. (vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press ' .. table.concat(vape.Keybind, ' + '):upper() .. ' to open GUI'), 5)
		end
	end
end

local ASSETS_NEW = {
	'blockedtab.png', 'blockedicon.png', 'blatanticon.png',
	'bindbkg.png', 'bind.png', 'back.png', 'arrowmodule.png',
	'allowedtab.png', 'allowedicon.png', 'alert.png', 'add.png',
	'combaticon.png', 'colorpreview.png', 'closemini.png', 'close.png',
	'blurnotif.png', 'blur.png',
	'dots.png', 'discord.png', 'customsettings.png', 'edit.png',
	'expandicon.png', 'worldicon.png', 'warning.png', 'vape.png',
	'utilityicon.png', 'textvape.png', 'textv4.png', 'textguiicon.png',
	'targetstab.png', 'targetplayers2.png', 'targetplayers1.png',
	'targetnpc2.png', 'targetnpc1.png', 'targetinfoicon.png',
	'search.png', 'rendertab.png', 'rendericon.png', 'rangearrow.png',
	'range.png', 'rainbow_4.png', 'rainbow_3.png', 'rainbow_2.png',
	'rainbow_1.png', 'radaricon.png', 'profilesicon.png', 'pin.png',
	'overlaystab.png', 'overlaysicon.png', 'notification.png',
	'module.png', 'miniicon.png', 'legittab.png', 'legit.png',
	'inventoryicon.png', 'info.png', 'guivape.png', 'guiv4.png',
	'guisliderrain.png', 'guislider.png', 'guisettings.png',
	'friendstab.png', 'expandup.png', 'expandright.png',
	'guiicon.png', 'settingsicon.png', 'checkbox.png', 'barlogo.png'
}
local ASSETS_OLD = {
	'worldicon.png', 'utilityicon.png', 'textvape.png', 'textv4.png',
	'textguiicon.png', 'targetinfoicon.png', 'settingsicon.png',
	'search.png', 'rendericon.png', 'profilesicon.png', 'pin.png',
	'info.png', 'guiicon.png', 'friendsicon.png', 'combaticon.png',
	'checkbox.png', 'blatanticon.png', 'barlogo.png'
}
local ASSETS_RISE = {
	'productsans.json', 'Icon-3.ttf', 'Icon-1.ttf', 'slice.png',
	'SF-Pro-Rounded-Regular.otf', 'SF-Pro-Rounded-Medium.otf', 'SF-Pro-Rounded-Light.otf'
}
local ASSETS_WURST = {
	'wurst_128.png', 'triangle.png'
}

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/' .. gui) then
	makefolder('newvape/assets/' .. gui)
end

for _, name in ipairs(ASSETS_NEW) do pcall(downloadFile, 'newvape/assets/new/' .. name) end
for _, name in ipairs(ASSETS_OLD) do pcall(downloadFile, 'newvape/assets/old/' .. name) end
for _, name in ipairs(ASSETS_RISE) do pcall(downloadFile, 'newvape/assets/rise/' .. name) end
for _, name in ipairs(ASSETS_WURST) do pcall(downloadFile, 'newvape/assets/wurst/' .. name) end

local guiSource = downloadFile('newvape/guis/' .. gui .. '.lua')
local guiFunc, guiErr = _realLoadstring(guiSource, 'gui')
if not guiFunc then
	local errMsg = tostring(guiErr)
	local lineNum = errMsg:match(':(%d+):')
	local context = ''
	if lineNum then
		local n = tonumber(lineNum)
		local lines = guiSource:split('\n')
		local from = math.max(1, n - 2)
		local to   = math.min(#lines, n + 2)
		local parts = {}
		for i = from, to do
			local marker = i == n and '>>> ' or '    '
			table.insert(parts, marker .. i .. ': ' .. (lines[i] or ''))
		end
		context = '\n\nContext:\n' .. table.concat(parts, '\n')
	end
	error('[Fuzzynuts] syntax error in ' .. gui .. '.lua' .. '\n' .. errMsg .. context)
end
vape = guiFunc()
if not vape then
	error('[Fuzzynuts] GUI returned nil file may be corrupted try deleting newvape/guis/' .. gui .. '.lua and reinjecting.')
end
if not vape.Load then
	if delfile then pcall(function() delfile('newvape/guis/' .. gui .. '.lua') end) end
	error('[Fuzzynuts] gui file corrupted (missing load) reinject..')
end
shared.vape = vape
task.wait(0.1)

if getgenv().Closet then
	local LogService = cloneref(game:GetService('LogService'))
	local originals = {}
	local function hook(funcName)
		if typeof(getgenv()[funcName]) == 'function' then
			local original = hookfunction(getgenv()[funcName], function() end)
			originals[funcName] = original
		end
	end
	hook('print')
	hook('warn')
	hook('error')
	hook('info')
	pcall(function() LogService:ClearOutput() end)
	local conn = LogService.MessageOut:Connect(function() LogService:ClearOutput() end)
	getgenv()._vape_log_connection = conn
	getgenv()._vape_originals = originals
end

if not shared.VapeIndependent then
	_realLoadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	local gameFileId = (game.GameId == 2619619496) and (game.PlaceId == 6872265039 and 6872265039 or 6872274481) or game.PlaceId
	if isfile('newvape/games/' .. gameFileId .. '.lua') then
		_realLoadstring(downloadFile('newvape/games/' .. gameFileId .. '.lua'), tostring(gameFileId))(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/toodiesjamming-stack/Fuzzynuts/' .. readfile('newvape/profiles/commit.txt') .. '/games/' .. gameFileId .. '.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				_realLoadstring(downloadFile('newvape/games/' .. gameFileId .. '.lua'), tostring(gameFileId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
