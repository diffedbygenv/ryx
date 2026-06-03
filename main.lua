local _args = ...

local FuzzynutsErrorHandler = function(err)
	warn('═══════════════════════════════════════════')
	warn('  FUZZYNUTS ADVANCED ERROR HANDLER')
	warn('═══════════════════════════════════════════')
	warn('  Message: ' .. tostring(err))
	local trace = debug and debug.traceback and debug.traceback()
	if trace then
		warn('  Traceback:')
		for line in trace:gmatch('[^\r\n]+') do
			warn('    ' .. line)
		end
	end
	warn('═══════════════════════════════════════════')
end

local function fileExists(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
isfile = fileExists

local builtinDel = delfile
local function deleteFile(file)
	if builtinDel then
		local suc = pcall(builtinDel, file)
		if suc then return end
	end
	pcall(function()
		writefile(file, '')
	end)
end
delfile = deleteFile

local function HTTP(url, nocache)
	return game:HttpGet(url, nocache)
end
local function JSON(data)
	return game:GetService('HttpService'):JSONDecode(data)
end

local function downloadFile(path, func)
	if not isfile(path) then
		local commitHash = ''
		if fileExists('newvape/profiles/commit.txt') then
			commitHash = readfile('newvape/profiles/commit.txt')
		end
		local relativePath = select(1, path:gsub('newvape/', ''))
		local url = 'https://raw.githubusercontent.com/toodiesjamming-stack/Fuzzynuts/' .. commitHash .. '/' .. relativePath
		local suc, res = pcall(function()
			return HTTP(url, true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	local ok, files = pcall(listfiles, path)
	if not ok or type(files) ~= 'table' then return end
	for _, file in ipairs(files) do
		if file:find('loader') then continue end
		if fileExists(file) then
			local content = readfile(file)
			if content and content:find('This watermark is used to delete the file', 1, true) == 1 then
				deleteFile(file)
			end
		end
	end
end

for _, folder in ipairs({
	'newvape', 'newvape/games', 'newvape/profiles', 'newvape/profiles/premade',
	'newvape/assets', 'newvape/assets/rise', 'newvape/assets/new',
	'newvape/assets/old', 'newvape/assets/wurst',
	'newvape/libraries', 'newvape/guis'
}) do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

local function downloadPremadeProfiles(commit)
	if isfolder('newvape/profiles/premade') then
		for _, file in listfiles('newvape/profiles/premade') do
			pcall(function()
				if isfile(file) then
					delfile(file)
				end
			end)
		end
	else
		makefolder('newvape/profiles/premade')
	end

	local success, response = pcall(function()
		return HTTP('https://api.github.com/repos/toodiesjamming-stack/Fuzzynuts/contents/profiles/premade?ref=' .. commit)
	end)

	if success and response then
		local ok, files = pcall(function()
			return JSON(response)
		end)

		if ok and type(files) == 'table' then
			for _, file in pairs(files) do
				if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
					local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
					local fileId = (game.GameId == 2619619496) and game.GameId or game.PlaceId
					local filePath = 'newvape/profiles/premade/' .. baseName .. tostring(fileId) .. '.txt'
					local ds, dc = pcall(function()
						return HTTP(file.download_url, true)
					end)
					if ds and dc and dc ~= '404: Not Found' then
						writefile(filePath, dc)
					end
				end
			end
		end
	end
end

local LIBRARY_FILES = {
	'drawing.lua', 'entity.lua', 'hash.lua', 'performance.lua',
	'prediction.lua', 'utils.lua', 'vm.lua', 'XFunctions.lua'
}

local GUI_FILES = {
	'new.lua', 'old.lua', 'rise.lua', 'wurst.lua'
}

local ASSETS_RISE = {
	'productsans.json', 'Icon-3.ttf', 'Icon-1.ttf', 'slice.png',
	'SF-Pro-Rounded-Regular.otf', 'SF-Pro-Rounded-Medium.otf', 'SF-Pro-Rounded-Light.otf'
}

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

local ASSETS_WURST = {
	'wurst_128.png', 'triangle.png'
}

local function downloadAllModules(commit)
	for _, file in ipairs(LIBRARY_FILES) do
		pcall(downloadFile, 'newvape/libraries/' .. file)
	end

	for _, file in ipairs(GUI_FILES) do
		pcall(downloadFile, 'newvape/guis/' .. file)
	end

	for _, file in ipairs(ASSETS_RISE) do
		pcall(downloadFile, 'newvape/assets/rise/' .. file)
	end

	for _, file in ipairs(ASSETS_NEW) do
		pcall(downloadFile, 'newvape/assets/new/' .. file)
	end

	for _, file in ipairs(ASSETS_OLD) do
		pcall(downloadFile, 'newvape/assets/old/' .. file)
	end

	for _, file in ipairs(ASSETS_WURST) do
		pcall(downloadFile, 'newvape/assets/wurst/' .. file)
	end

	local success, response = pcall(function()
		return HTTP('https://api.github.com/repos/toodiesjamming-stack/Fuzzynuts/contents/games?ref=' .. commit)
	end)

	local gameFiles = {}
	if success and response then
		local ok, files = pcall(function()
			return JSON(response)
		end)
		if ok and type(files) == 'table' then
			for _, file in pairs(files) do
				if file.type == 'file' and file.name:match('%.lua$') then
					table.insert(gameFiles, file.name)
				end
			end
		end
	end

	if #gameFiles == 0 then
		table.insert(gameFiles, 'universal.lua')
	end

	for _, fileName in ipairs(gameFiles) do
		pcall(downloadFile, 'newvape/games/' .. fileName)
	end

	pcall(downloadFile, 'newvape/main.lua')
end

if not shared.VapeDeveloper then
	local commit = 'main'
	local ok, res = pcall(function()
		return HTTP('https://api.github.com/repos/toodiesjamming-stack/Fuzzynuts/commits/main', true)
	end)

	if ok and res then
		local h = res:match('"sha":"([a-f0-9]+)"')
		if h and #h == 40 then
			commit = h
		end
	end

	if commit ~= 'main' and (fileExists('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		pcall(function()
			if fileExists('newvape/guis/new.lua') then
				deleteFile('newvape/guis/new.lua')
			end
		end)
		wipeFolder('newvape/libraries')
		if isfolder('newvape/profiles/premade') then
			local ok2, premadeFiles = pcall(listfiles, 'newvape/profiles/premade')
			if ok2 and type(premadeFiles) == 'table' then
				for _, pf in ipairs(premadeFiles) do
					pcall(function()
						if isfile(pf) then
							deleteFile(pf)
						end
					end)
				end
			end
		end
	end

	writefile('newvape/profiles/commit.txt', commit)

	downloadAllModules(commit)
	pcall(downloadPremadeProfiles, commit)
end

local guiPriority = {'new', 'rise', 'wurst', 'old'}
for _, guiName in ipairs(guiPriority) do
	local guiPath = 'newvape/guis/' .. guiName .. '.lua'
	if fileExists(guiPath) then
		local success, mainapi = pcall(loadstring(readfile(guiPath), guiName), {
			Username = shared.ValidatedUsername or 'User'
		})
		if success and type(mainapi) == 'table' then
			shared.vape = mainapi
			shared.vape_running = true
			return mainapi
		else
			warn('[Fuzzynuts Error Handler] Failed to load GUI "' .. guiName .. '": ' .. tostring(mainapi))
		end
	end
end

error('[Fuzzynuts Error Handler] No GUI files were downloaded successfully. Check your internet connection.')
