--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local canDebug = true
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local proximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local isnetworkowner = isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/MaxlaserTech/CatV6/'..readfile('catrewrite/profiles/commit.txt')..'/'..select(1, path:gsub('catrewrite/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local rankCache = {}
local store = {
	lastHit = 0,
	attackReach = 0,
	attackReachUpdate = os.clock(),
	damageBlockFail = os.clock(),
	hand = {},
	rank = setmetatable({}, {
		__index = function(self, index)
			return {
				async = function()
					if rankCache[index] then
						return rankCache[index]
					end
					if index then
						local rank = bedwars.Client:Get('FetchRanks'):CallServer({index.UserId})
						if typeof(rank) == 'table' and rank[1] and rank[1].rankDivision then
							rankCache[index] = rank[1].rankDivision
							return rankCache[index]
						end
					end
					return nil
				end,
			}
		end
	}),
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	selfProjectiles = {},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
getgenv().store = store
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}
local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('catrewrite/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end
local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}
	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))
		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end
	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end
local function getBestArmor(slot)
	local closest, mag = nil, 0
	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}
		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)
			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end
	return closest
end
local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end
local function getItem(itemName, inv, find)
	for slot, item in (inv or store.inventory.inventory.items) do
		if find and item.itemType:find(itemName) or item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end
local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end
local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end
local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end
local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end
local function getStrength(plr)
	if not plr.Player then
		return 0
	end
	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end
	return strength
end
local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end
getgenv().getPlacedBlock = getPlacedBlock
local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end
local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))
	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end
	table.clear(blocks)
	return closest
end
local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end
local knockbackSpeed, knockbackBoost = 0, os.clock()
local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()
	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end
	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end
	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end
	return (20 + (knockbackBoost > os.clock() and knockbackSpeed or 0)) * (multi + 1)
end
getgenv().getSpeed = getSpeed
local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end
local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar
local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end
getgenv().hotbarSwitch = hotbarSwitch
local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end
local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end
local function notif(...) return vape:CreateNotification(...) end
local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end
local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end
local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end
getgenv().switchItem = switchItem
local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = os.clock() + timeout, nil
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < os.clock() then
			break
		end
		task.wait()
	until false
	return returned
end
local function waitForChildYield(obj, timeout, ...)
	local check, returned = os.clock(), obj
	for _, v in { ... } do
		if not returned then
			break
		end
		check = os.clock() + timeout
		repeat
			local new = returned:FindFirstChild(v)
			if new or os.clock() > check then
				returned = new
				break
			end
			task.wait()
		until false
	end
	return returned
end
local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end
	return true
end
local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState
local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end
local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end
local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}
local getBlockHits
local sortmethods, breakmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}, {
	Health = function(...)
		return getBlockHits(...)
	end,
	Distance = function(a)
		local pos = (entitylib.isAlive and (entitylib.character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
		return (pos - Vector3.new(a.Position.X, pos.Y, a.Position.Z)).Magnitude
	end,
}
run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') and not ent:HasTag('trainingRoomDummy') then
			return
		end
		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end
	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end
	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end
				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end
	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}
			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = os.clock(),
					Jumping = false,
					LandTick = os.clock(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}
				if plr == lplr then
					entity.AirTime = os.clock()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)
					if plr ~= nil then
						table.insert(entity.Connections, hum.AnimationPlayed:Connect(function(track)
							entitylib.Events.AnimationPlayed:Fire(plr, track)
						end))
					end
					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end
					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end
					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = os.clock()
										entity.Jumps += 1
										entity.LandTick = os.clock() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end
						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end
				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end
	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}
		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end
		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end
		return tab
	end
	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()
run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get, nil
	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta,
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BedwarsKitSkin = canDebug and debug.getupvalue(require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).getKitSkinMetadata, 1) or {},
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BlockSelector = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelector,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EnchantMeta = require(replicatedStorage.TS.enchant['enchant-meta']).EnchantMeta,
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SummonerKitBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance,
		StatusEffectUtil = require(replicatedStorage.TS['status-effect']['status-effect-util']).StatusEffectUtil,
		StatusEffectMeta = require(replicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType,
		SharedConstants = canDebug and require(replicatedStorage.TS['shared-constants']).CpsConstants or {},
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 7),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	getgenv().bedwars = bedwars
	store.enchants = setmetatable({}, {
		__index = function(self, plr)
			return {
				async = function()
					if plr and plr.Character then
						for i in plr.Character:GetAttributes() do
							if i:find('StatusEffect_') and not i:find('_stacks') then
								local name = bedwars.StatusEffectMeta[({i:gsub('StatusEffect_', '')})[1]]
								if bedwars.StatusEffectMeta[name] then
									name = bedwars.StatusEffectMeta[name]
									for num = 1, 3 do
										name = name:gsub('_%d', '')
									end
									if bedwars.EnchantMeta[name] then
										return bedwars.EnchantMeta[name].image
									end
								end
							end
						end
					end
					return nil
				end,
			}
		end
	})
	local function createMethodHook(object, method)
		local original = object[method]
		local hooks, order = {}, 0
		local wrapper
		local function sync()
			if #hooks > 0 then
				object[method] = wrapper
			elseif object[method] == wrapper then
				object[method] = original
			end
		end
		wrapper = function(...)
			local index = 0
			local function nextHook(...)
				index += 1
				local hook = hooks[index]
				if hook then
					return hook.Callback(nextHook, ...)
				end
				return original(...)
			end
			return nextHook(...)
		end
		return {
			Add = function(_, id, priority, callback)
				for i = #hooks, 1, -1 do
					if hooks[i].Id == id then
						table.remove(hooks, i)
					end
				end
				order += 1
				local entry = {
					Id = id,
					Priority = priority or 100,
					Order = order,
					Callback = callback,
				}
				table.insert(hooks, entry)
				table.sort(hooks, function(a, b)
					return a.Priority == b.Priority and a.Order < b.Order or a.Priority < b.Priority
				end)
				sync()
				return function()
					for i = #hooks, 1, -1 do
						if hooks[i] == entry then
							table.remove(hooks, i)
						end
					end
					sync()
				end
			end,
			Destroy = function()
				table.clear(hooks)
				sync()
			end,
		}
	end
	bedwars.ProjectileLaunchHook = createMethodHook(bedwars.ProjectileController, 'calculateImportantLaunchValues')
	vape:Clean(function()
		bedwars.ProjectileLaunchHook:Destroy()
	end)
	local function getproto(...)
		local success, res = pcall(debug.getproto, ...)
		return success and res or function() end
	end
	local remoteNames = {
		AfkStatus = getproto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = getproto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = getproto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = getproto(getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = getproto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = getproto(getproto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = getproto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = getproto(Knit.Controllers.ResetController.createBindable, 1),
		SpawnRaven = getproto(Knit.Controllers.RavenController.KnitStart, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}
	local packages = httpService:JSONDecode(downloadFile('catrewrite/profiles/packages.json'))	
	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end
	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' and packages.remotes[i] then
			remote = packages.remotes[i]
		end
		remotes[i] = remote
	end
	getgenv().remotes = remotes
	OldBreak = bedwars.BlockController.isBlockBreakable
	OldHit = bedwars.BlockBreaker.hitBlock
	bedwars.BlockBreaker.hitBlock = function(...)
		store.lastHit = os.clock()
		return OldHit(...)
	end
	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)
		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)
					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = os.clock() + 1
					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end
					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end
					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end
		return call
	end
	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)
		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end
		return OldBreak(self, breakTable, plr)
	end
	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')
	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end
	getBlockHits = function(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end
	local function calculatePath(target, blockpos, method, angle)
		if cache[blockpos] and cache[blockpos][4] > os.clock() then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}
		local head = 1
		for _ = 1, 10000 do
			local node = unvisited[head]
			if not node then break end
			head += 1
			visited[node[2]] = true
			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end
				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end
				if math.acos((gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):Dot(((block.Position - entitylib.character.RootPart.Position)* Vector3.new(1, 0, 1)).Unit)) > (math.rad(angle) / 2) then
					continue
				end
				local curdist = (method and method(block, side) or getBlockHits(block, side)) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end
		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end
		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path,
				os.clock() + (inputService.TouchEnabled and 9e9 or 1)
			}
			return pos, cost, path
		end
		return nil
	end
	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end
	bedwars.breakBlock = function(block, effects, anim, customHealthbar, visualise, sort, angle)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge, nil, nil, nil
		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3, sort, angle or 360)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end
		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end
			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = dblock.Name == 'gumdrop_bounce_pad' and 'stone' or bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if visualise then
						local hotbar = getHotbar(tool.tool)
						if hotbar then
							hotbarSwitch(hotbar)
						end
					else
						switchItem(tool.tool)
					end
				end
			end
			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end
			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = os.clock() + 1
						return
					end
					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)
						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end
					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)
			if effects then
				return pos, path, target
			end
		end
		return nil
	end
	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end
	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end
		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end
		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv
			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end
			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end
			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end
				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end
	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})
	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end
	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))
	vape:Clean(workspace.ChildAdded:Connect(function(projectile)
		task.delay(0, function()
			if projectile and projectile.Parent and entitylib.isAlive and projectile:GetAttribute('ProjectileShooter') == lplr.UserId then
				table.insert(store.selfProjectiles, projectile)
				projectile.Destroying:Once(function()
					local index = table.find(store.selfProjectiles, projectile)
					if index then
						table.remove(store.selfProjectiles, index)
					end
				end)
			end
		end)
	end))
	for _, event in {'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end
	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)
	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)
	task.delay(1, function()
		games:Increment()
	end)
	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			store.map = waitForChildYield(workspace, 9e9, 'Map', 'Worlds'):GetChildren()[1]
			mapname = store.map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			if store.map then
				vape:Clean(store.map.Blocks.ChildAdded:Connect(function(v)
					task.delay(0, function()
						if v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
							local data = {
								blockRef = {
									blockPosition = v.Position / 3,
								},
								player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId')),
							}
							for i, v in cache do
								if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
									table.clear(v[3])
									table.clear(v)
									cache[i] = nil
								end
							end
							vapeEvents.PlaceBlockEvent:Fire(data)
						end
					end)
				end))
			end
		end)
	end)
	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))
	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))
	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end
		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))
	task.spawn(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = {workspace:WaitForChild('Map', 9e9)}
		store.airRay = rayParams
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = workspace:Raycast((store.rootpart or entitylib.character.RootPart).Position, Vector3.new(0, -4.5, 0), rayParams) and os.clock() or entitylib.character.AirTime
			end
			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or os.clock()
				if (os.clock() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)
	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)
			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)
			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')
				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)
	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)
for _, v in {'Anti Ragdoll', 'Trigger Bot', 'Silent Aim', 'Auto Rejoin', 'Rejoin', 'Disabler', 'Timer', 'Server Hop', 'Mouse TP', 'Murder Mystery'} do
	vape:Remove(v)
end
local AntiFallDirection
local Fly
local LongJump
local Attacking
run(function()
    local AimAssist
    local AimMode
    local Mode
    local Targets
    local Sort
    local AimPart
    local AimSpeed
    local Shake
    local Distance
    local AngleSlider
    local StrafeIncrease
    local BlockBreak
    local KillauraTarget
    local ClickAim
    local Mouse
    local Limit
    local function ease(t)
    	return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
    end
    local cache = setmetatable({}, {__mode = "k"})
    local function getMousePosition()
    	if inputService.TouchEnabled then
    		return gameCamera.ViewportSize / 2
    	end
    	return inputService.GetMouseLocation(inputService)
    end
    local function getAim(ent)
    	if AimPart.Value == 'Closest' then
    		if not cache[ent.Character] then
    			cache[ent.Character] = ent.Character:GetChildren()
    		end
    		local localPosition, magnitude, part = getMousePosition(), 9e9, nil
    		for _, v in cache[ent.Character] do
    			if v and v.Parent and v:IsA('BasePart') then
    				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)
    				if vis then
    					local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude
    					if mag < magnitude then
    						magnitude = mag
    						part = v
    					end
    				end
    			end
    		end
    		if part then return part.Position end
    	end
    	return ent.RootPart.Position
    end
    local started, lasttarget = 0, nil
    local aimfuncs = {
    	Simple = function(localcframe, ent, fps)
    		local rng = Random.new()
    		local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0))
    		return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
    	end,
    	Adaptive = function(localcframe, ent, fps)
    		local prog, rng = ease(math.min(os.clock() - started, 1)), Random.new()
    		local speed = (AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)
    		return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
    	end
    }
    local function GetTarget()
    	if lasttarget then
    		local localPosition = entitylib.character.RootPart.Position
    		if not lasttarget or not lasttarget.RootPart or not lasttarget.Humanoid or not lasttarget.Humanoid.Health or lasttarget.Humanoid.Health <= 0 then
    			return false
    		end
    		if (localPosition - lasttarget.RootPart.Position).Magnitude > Distance.Value then
    			return false
    		end
    		if Targets.Walls.Enabled and entitylib.Wallcheck(localPosition, lasttarget.RootPart.Position, Targets.Walls.Enabled) then
    			return false
    		end
    		return lasttarget
    	end
    	return false
    end
    local function getAttackData()
    	if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (os.clock() - bedwars.SwordController.lastSwing) > 0.15 then return false end
    	if ClickAim.Enabled and (os.clock() - bedwars.SwordController.lastSwing) > 0.3 then return false end
    	if BlockBreak.Enabled and (os.clock() - store.lastHit) < 0.3 then return false end
    	if Limit.Enabled and store.hand.toolType ~= 'sword' then return false end
    	if (os.clock() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
    		local ent = GetTarget() or KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
    			Range = Distance.Value,
    			Part = 'RootPart',
    			Wallcheck = Targets.Walls.Enabled,
    			Players = Targets.Players.Enabled,
    			NPCs = Targets.NPCs.Enabled,
    			Sort = sortmethods[Sort.Value],
    		})
    		if ent then started = os.clock() end
    		lasttarget = ent
    	end
    	return lasttarget
    end
    AimAssist = vape.Categories.Combat:CreateModule({
    	Name = 'Aim Assist',
    	Function = function(callback)
    		if callback then
    			local rotate = 0
    			AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
    				if entitylib.isAlive then
    					entitylib.character.Humanoid.AutoRotate = os.clock() > rotate
    					local ent = getAttackData()
    					if ent then
    						local root = entitylib.character.RootPart
    						local delta = (ent.RootPart.Position - root.Position)
    						local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
    						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
    						if angle >= (math.rad(AngleSlider.Value) / 2) then return end
    						targetinfo.Targets[ent] = os.clock() + 1
    						local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
    						if AimMode.Value == 'First person' or AimMode.Value == 'Dynamic' and entitylib.character.Head.LocalTransparencyModifier == 1 then
    							gameCamera.CFrame = cframe
    						elseif AimMode.Value == 'Third person' or AimMode.Value == 'Dynamic' and entitylib.character.Head.LocalTransparencyModifier ~= 1 then
    							cframe, speed = aimfuncs[Mode.Value](root.CFrame, ent, dt)
    							entitylib.character.Humanoid.AutoRotate = false
    							root.CFrame = CFrame.lookAlong(root.Position, cframe.LookVector * Vector3.new(1, 0, 1))
    							rotate = os.clock() + 0.1
    						elseif AimMode.Value == 'Mouse' then
    							local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
    							local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
    							mousemoverel(pos.X, pos.Y)
    						end
    					end
    				end
    			end))
    		end
    	end,
    	Tooltip = 'Smoothly aims to closest valid target with sword'
    })
    local modes = {}
    for i in aimfuncs do table.insert(modes, i) end
    AimMode = AimAssist:CreateDropdown({
    	Name = 'Aim perspective',
    	List = {'First person', 'Third person', 'Mouse', 'Dynamic'},
    	Default = 'First person'
    })
    Mode = AimAssist:CreateDropdown({Name = 'Mode', List = modes, Default = modes[1]})
    Targets = AimAssist:CreateTargets({Players = true, Walls = true})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    ClickAim = AimAssist:CreateToggle({Name = 'Click aim', Default = true})
    Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
    StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
    BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
    KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
    AimSpeed = AimAssist:CreateSlider({Name = 'Aim speed', Min = 1, Max = 20, Default = 6})
    Distance = AimAssist:CreateSlider({Name = 'Distance', Min = 1, Max = 30, Default = 30})
    Shake = AimAssist:CreateSlider({Name = 'Shake', Min = 0, Max = 100, Default = 0})
    AngleSlider = AimAssist:CreateSlider({Name = 'Max angle', Min = 1, Max = 360, Default = 70})
    Limit = AimAssist:CreateToggle({Name = 'Limit to items'})
    Sort = AimAssist:CreateDropdown({Name = 'Target mode', List = methods, Default = 'Angle'})
    AimPart = AimAssist:CreateDropdown({Name = 'Target area', List = {'Center', 'Closest'}, Default = 'Center'})
end)
run(function()
    local AutoClicker, CPS, BlockCPS, Thread
    local function AutoClick()
    	if Thread then task.cancel(Thread) end
    	Thread = task.delay(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue(), function()
    		repeat
    			if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
    				local blockPlacer = bedwars.BlockPlacementController.blockPlacer
    				if store.hand.toolType == 'block' and blockPlacer then
    					if canDebug then
    						if inputService.TouchEnabled then
    							task.spawn(function()
    								blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
    							end)
    						else
    							if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
    								local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
    								if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
    									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
    								end
    							end
    						end
    					end
    				elseif store.hand.toolType == 'sword' then
    					bedwars.SwordController:swingSwordAtMouse(0.39)
    				end
    			end
    			task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
    		until not AutoClicker.Enabled
    	end)
    end
    AutoClicker = vape.Categories.Combat:CreateModule({
    	Name = 'Auto Clicker',
    	Function = function(callback)
    		if callback then
    			AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
    				if input.UserInputType == Enum.UserInputType.MouseButton1 then AutoClick() end
    			end))
    			AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
    				if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
    					task.cancel(Thread)
    					Thread = nil
    				end
    			end))
    		else
    			if Thread then
    				task.cancel(Thread)
    				Thread = nil
    			end
    		end
    	end
    })
    CPS = AutoClicker:CreateTwoSlider({Name = 'CPS', Min = 1, Max = 9, DefaultMin = 7, DefaultMax = 7})
    AutoClicker:CreateToggle({Name = 'Place Blocks', Default = true})
    BlockCPS = AutoClicker:CreateTwoSlider({Name = 'Block CPS', Min = 1, Max = 20, DefaultMin = 12, DefaultMax = 12, Darker = true})
end)
run(function()
    local BowAssist, Targets, Sort, Shake, Speed, Angle, FOV, Blacklist, Mouse, ThirdPerson, Projectiles
    local function ease(t) return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2 end
    local function findAim(localcframe, predicted, fps, started, offset)
    	local prog, rng = ease(math.min((os.clock() - started) / (1 / (Speed.Value * 0.5)), 1)), Random.new()
    	local speed = Speed.Value * prog
    	return localcframe:Lerp(CFrame.lookAt(localcframe.p, predicted + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, offset + ((rng:NextNumber() - 0.5) * Shake.Value * fps), (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
    end
    local launchHook, lasttarget, started = nil, nil, 0
    local function getAttackData()
    	if not entitylib.isAlive then return false end
    	if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) then return false end
    	if not store.hand.tool or not bedwars.ItemMeta[store.hand.tool.Name].projectileSource and store.hand.toolType ~= 'bow' then return false end
    	if Blacklist.Enabled and table.find(Projectiles.ListEnabled, store.hand.tool.Name == 'glue_trap' and 'gloop' or store.hand.tool.Name) then return false end
    	if (os.clock() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
    		local ent = entitylib.EntityMouse({Origin = entitylib.character.RootPart.Position, Range = FOV.Value, Part = 'RootPart', Wallcheck = Targets.Walls.Enabled, Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Sort = sortmethods[Sort.Value]})
    		if ent then started = os.clock() end
    		lasttarget = ent
    	end
    	return lasttarget
    end
    local rayCheck = RaycastParams.new()
    BowAssist = vape.Categories.Combat:CreateModule({
    	Name = 'Bow Assist',
    	Function = function(callback)
    		if callback then
    			local multi, predicted, lastpredicted = 0, nil, 0
    			local lastent, found, update = nil, 0, 0
    			launchHook = bedwars.ProjectileLaunchHook:Add('BowAssist', 10, function(nextLaunch, ...)
    				local res = nextLaunch(...)
    				local projmeta = select(2, ...)
    				multi = projmeta and (projmeta.velocityMultiplier + 2) or 0
    				if projmeta and os.clock() - update < 0.1 and lastent and lastent.RootPart then
    					local meta = projmeta:getProjectileMeta()
    					local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
    					predicted = prediction.SolveTrajectory(entitylib.character.RootPart.Position, (meta.launchVelocity or 100) * (1 - lplr:GetNetworkPing()), gravity, lastent.RootPart.Position, lastent.RootPart.Velocity, workspace.Gravity, entitylib.character.HipHeight, nil, rayCheck)
    					lastpredicted = os.clock()
    				else
    					predicted = nil
    				end
    				return res
    			end)
    			BowAssist:Clean(runService.PostSimulation:Connect(function(dt)
    				local ent = getAttackData()
    				if ent then
    					local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
    					local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
    					local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
    					if angle >= (math.rad(Angle.Value) / 2) then return end
    					if ent ~= lastent then found = os.clock() end
    					lastent, update = ent, os.clock()
    					if os.clock() - lastpredicted < 0.1 then
    						targetinfo.Targets[ent] = os.clock() + 1
    						local cframe, speed = findAim(gameCamera.CFrame, predicted or ent.RootPart.Position, dt, found, multi + ((entitylib.character.RootPart.Position.Y - ent.RootPart.Position.Y) / 7))
    						if inputService.MouseEnabled and entitylib.character.Head.LocalTransparencyModifier == 1 then
    							gameCamera.CFrame = cframe
    						elseif ThirdPerson.Enabled and inputService.MouseEnabled then
    							local viewport = gameCamera:WorldToViewportPoint(predicted)
    							local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
    							mousemoverel(pos.X, pos.Y)
    						end
    					end
    				end
    			end))
    		else
    			if launchHook then launchHook(); launchHook = nil end
    		end
    	end
    })
    Targets = BowAssist:CreateTargets({Players = true, Walls = true})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    Sort = BowAssist:CreateDropdown({Name = 'Target mode', List = methods, Default = 'Angle'})
    Speed = BowAssist:CreateSlider({Name = 'Aim speed', Min = 1, Max = 20, Default = 7})
    Angle = BowAssist:CreateSlider({Name = 'Max angle', Min = 1, Max = 360, Default = 120})
    Shake = BowAssist:CreateSlider({Name = 'Shake', Min = 1, Max = 100, Default = 5})
    FOV = BowAssist:CreateSlider({Name = 'FOV', Min = 1, Max = 1000, Default = 200})
    Mouse = BowAssist:CreateToggle({Name = 'Require mouse down', Default = inputService.KeyboardEnabled})
    ThirdPerson = BowAssist:CreateToggle({Name = 'Use mouse aim', Default = true})
    Blacklist = BowAssist:CreateToggle({Name = 'Use blacklist', Default = true})
    Projectiles = BowAssist:CreateTextList({Name = 'Blacklisted', Default = {'fireball', 'telepearl', 'gloop'}, Darker = true})
end)
run(function()
    local old
    vape.Categories.Combat:CreateModule({
        Name = 'No Click Delay',
        Function = function(callback)
            if callback then
                old = bedwars.SwordController.isClickingTooFast
                bedwars.SwordController.isClickingTooFast = function(self)
                    self.lastSwing = os.clock()
                    return false
                end
            else
                bedwars.SwordController.isClickingTooFast = old
            end
        end
    })
end)
run(function()
    if canDebug then
    	run(function()
    		local BlockReach, BlockRange, BreakReach, BreakRange, SwordReach, SwordRange, old
    		Reach = vape.Categories.Combat:CreateModule({
    			Name = 'Reach',
    			Function = function(callback)
    				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
    				if callback then
    					old = bedwars.BlockSelector.getMouseInfo
    					bedwars.BlockSelector.getMouseInfo = function(Self, Select, Args)
    						Args = Args or {}
    						if Select == 0 then
    							Args.range = BlockReach.Enabled and BlockRange.Value or 24
    						elseif Select == 1 then
    							Args.range = BreakReach.Enabled and BreakRange.Value or 18
    						end
    						return old(Self, Select, Args)
    					end
    				else
    					bedwars.BlockSelector.getMouseInfo = old
    					old = nil
    				end
    			end,
    		})
    		SwordReach = Reach:CreateToggle({
    			Name = 'Sword Reach', Default = true,
    			Function = function(callback)
    				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
    				pcall(function() SwordRange.Object.Visible = callback end)
    			end,
    		})
    		SwordRange = Reach:CreateSlider({
    			Name = 'Sword Range', Min = 1, Max = 18, Default = 18, Decimal = 5, Darker = true,
    			Function = function(val) bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4 end,
    		})
    		BlockReach = Reach:CreateToggle({Name = 'Placement Reach'})
    		BlockRange = Reach:CreateSlider({Name = 'Placement Range', Min = 1, Max = 60, Default = 18, Darker = true, Visible = false})
    		BreakReach = Reach:CreateToggle({Name = 'Break Reach'})
    		BreakRange = Reach:CreateSlider({Name = 'Break Range', Min = 1, Max = 30, Default = 30, Decimal = 5, Darker = true, Visible = false})
    	end)
    end
end)
run(function()
    local SilentAura, Targets, Speed, Range, Angle, Mode, Area, LegitAura, Mouse, NoSwing, Limit, SilentAim, SwingTime, Perfect
    local Show, Targetcolor, Attackcolor
    local function getAttackData()
        if not entitylib.isAlive then return false end
        if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (os.clock() - bedwars.SwordController.lastSwing) > 0.3 then return false end
        if LegitAura.Enabled and (os.clock() - bedwars.SwordController.lastSwing) > 0.3 then return false end
        if (lplr.Character:GetAttribute('StunnedUntilTime') or 0) - workspace:GetServerTimeNow() > 0 then return false end
        if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end
        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled and (store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid) then return false end
        return sword, meta
    end
    local cache = setmetatable({}, {__mode = "k"})
    local function getAim(ent)
        if Area.Value == 'Closest' then
            if not cache[ent.Character] then cache[ent.Character] = ent.Character:GetChildren() end
            local localPosition, magnitude, part = inputService.GetMouseLocation(inputService), 9e9, nil
            for _, v in cache[ent.Character] do
                if v and v.Parent and v:IsA('BasePart') then
                    local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)
                    if vis then
                        local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude
                        if mag < magnitude then magnitude, part = mag, v end
                    end
                end
            end
            if part then return part.Position end
        end
        return ent.RootPart.Position
    end
    local function ease(t) return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2 end
    local function findAim(localcframe, ent, fps, started)
        local prog, rng = ease(math.min((os.clock() - started) / (1 / (Speed.Value * 0.5)), 1)), Random.new()
        local speed = Speed.Value * prog
        return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * 15 * fps, (rng:NextNumber() - 0.5) * 15 * fps, (rng:NextNumber() - 0.5) * 15 * fps)), speed * fps), speed
    end
    local box = Instance.new('BoxHandleAdornment')
    box.AlwaysOnTop = true
    box.Size = Vector3.new(3, 5, 3)
    box.CFrame = CFrame.new(0, -0.5, 0)
    box.ZIndex = 0
    box.Parent = vape.gui
    SilentAura = vape.Categories.Combat:CreateModule({
        Name = 'Silent Aura',
        Tooltip = 'Automatically aims and attacks nearby target',
        Function = function(callback)
            if callback then
                local lastent, lastfound, foundat, lastattacked = nil, 0, os.clock(), os.clock()
                SilentAura:Clean(runService.PostSimulation:Connect(function(dt)
                    if entitylib.isAlive and os.clock() - lastfound < 0.5 then
                        targetinfo.Targets[lastent] = os.clock() + 0.5
                        entitylib.character.Humanoid.AutoRotate = not SilentAim.Enabled
                        local cframe, speed = findAim(gameCamera.CFrame, lastent, dt, foundat)
                        if SilentAim.Enabled then
                            entitylib.character.RootPart.CFrame = entitylib.character.RootPart.CFrame:Lerp(CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(lastent.RootPart.Position.X, entitylib.character.RootPart.Position.Y, lastent.RootPart.Position.Z)), (speed + 2) * dt)
                        else
                            gameCamera.CFrame = cframe
                        end
                    elseif entitylib.isAlive then
                        entitylib.character.Humanoid.AutoRotate = true
                    end
                end))
                local frames = 9e9
                repeat
                    task.wait()
                    local sword, meta = getAttackData()
                    if sword then
                        local localPosition = entitylib.character.RootPart.Position
                        local ent = entitylib.EntityPosition({Origin = localPosition, Range = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE + Range.Value, Wallcheck = Targets.Walls.Enabled or nil, Part = 'RootPart', Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Limit = 1, Sort = sortmethods[Mode.Value or 'Distance']})
                        local Slider = os.clock() - lastattacked < 0.1 and Attackcolor or Targetcolor
                        box.Adornee = Show.Enabled and ent and ent.RootPart or nil
                        box.Transparency = 1 - Slider.Opacity
                        box.Color3 = Color3.fromHSV(Slider.Hue, Slider.Sat, Slider.Value)
                        if ent then
                            if not store.hand or store.hand.tool ~= sword.tool then
                                local hotbar = getHotbar(sword.tool)
                                if hotbar then hotbarSwitch(hotbar) else continue end
                            end
                            if frames > 50 then frames = 0 end
                            frames += 1
                            local localfacing = (inputService.KeyboardEnabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector * Vector3.new(1, 0, 1)
                            local delta, flat = (ent.RootPart.Position - localPosition), ((ent.RootPart.Position - localPosition) * Vector3.new(1, 0, 1))
                            local facingdot = flat.Magnitude > 0 and localfacing.Magnitude > 0 and (localfacing / localfacing.Magnitude):Dot(flat / flat.Magnitude) or 0
                            if facingdot < math.cos(math.rad(Angle.Value) / 2) then continue end
                            if not LegitAura.Enabled and (os.clock() - bedwars.SwordController.lastSwing) >= (Perfect.Enabled and (meta.sword.attackSpeed or 0.11) or math.max(SwingTime.Value, 0.11)) then
                                bedwars.SwordController:playSwordEffect(meta, false)
                                bedwars.SwordController.lastSwing = os.clock()
                            end
                            if lastent ~= ent or facingdot < -0.5 then foundat = os.clock() end
                            lastent, lastfound = ent, os.clock()
                            if delta.Magnitude > bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE then continue end
                            lastattacked = os.clock()
                            local dir = CFrame.lookAt(localPosition, ent.RootPart.Position).LookVector
                            local pos = localPosition + dir * math.max(delta.Magnitude - 14.4, 0)
                            bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                            bedwars.Client:Get(remotes.AttackEntity):SendToServer({weapon = sword.tool, chargedAttack = {chargeRatio = 0}, entityInstance = ent.Character, validate = {raycast = {cameraPosition = {value = pos}, cursorDirection = {value = dir}}, targetPosition = {value = ent.RootPart.Position}, selfPosition = {value = pos}}})
                        else
                            lastfound, frames = 0, 0
                        end
                    else
                        box.Adornee = nil
                        lastfound, frames = 0, 0
                    end
                until not SilentAura.Enabled
            else
                if entitylib.isAlive then entitylib.character.Humanoid.AutoRotate = true end
                box.Adornee = nil
            end
        end
    })
    Targets = SilentAura:CreateTargets({Players = true, NPCs = true})
    Speed = SilentAura:CreateSlider({Name = 'Aim speed', Min = 1, Max = 10, Default = 6, Decimal = 5, Tooltip = 'How fast the Aura is going to aim'})
    SwingTime = SilentAura:CreateSlider({Name = 'Swing time', Darker = true, Visible = false, Min = 0, Max = 0.5, Default = 0.42, Decimal = 100})
    Range = SilentAura:CreateSlider({Name = 'Extra swing distance', Tooltip = 'Where you will start swinging, not attacking', Min = 0, Max = 6, Decimal = 5, Default = 3, Suffix = function(val) return val <= 1 and 'stud' or 'studs' end})
    Angle = SilentAura:CreateSlider({Name = 'Max angle', Min = 1, Max = 360, Default = 180})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    Mode = SilentAura:CreateDropdown({Name = 'Target mode', List = methods, Tooltip = 'How Aura should prioritize targets', Default = 'Health'})
    Area = SilentAura:CreateDropdown({Name = 'Target area', Tooltip = 'Where the Aura will aim towards', List = {'Center', 'Closest'}, Default = 'Center', Visible = false})
    Perfect = SilentAura:CreateToggle({Name = 'Perfect Swing', Tooltip = "Follows tool's swing time", Default = true, Function = function(callback) pcall(function() SwingTime.Object.Visible = not callback end) end})
    Mouse = SilentAura:CreateToggle({Name = 'Require mouse down'})
    LegitAura = SilentAura:CreateToggle({Name = 'Swing only'})
    SilentAim = SilentAura:CreateToggle({Name = 'Silent Aim', Tooltip = "Uses catvape's aiming technology to silently aim while looking legit", Default = true, Function = function(callback) pcall(function() Area.Object.Visible = not callback end) end})
    Show = SilentAura:CreateToggle({Name = 'Show target', Default = true, Function = function(callback) pcall(function() Targetcolor.Object.Visible = callback; Attackcolor.Object.Visible = callback end) end})
    Targetcolor = SilentAura:CreateColorSlider({Name = 'Target color', Darker = true, DefaultOpacity = 0.5, DefaultHue = 1})
    Attackcolor = SilentAura:CreateColorSlider({Name = 'Attack color', Darker = true, DefaultOpacity = 0.5})
    Limit = SilentAura:CreateToggle({Name = 'Limit to items'})
end)run(function()
    local Sprint, old
    Sprint = vape.Categories.Combat:CreateModule({
        Name = 'Sprint',
        Function = function(callback)
            if callback then
                if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['4'].Visible = false end) end
                old = bedwars.SprintController.stopSprinting
                bedwars.SprintController.stopSprinting = function(...)
                    local call = old(...)
                    bedwars.SprintController:startSprinting()
                    return call
                end
                Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
                    task.delay(0.1, function() bedwars.SprintController:stopSprinting() end) 
                end))
                bedwars.SprintController:stopSprinting()
            else
                if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['4'].Visible = true end) end
                bedwars.SprintController.stopSprinting = old
                bedwars.SprintController:stopSprinting()
            end
        end
    })
end)
run(function()
    local TriggerBot, CPS
    local rayParams = RaycastParams.new()
    TriggerBot = vape.Categories.Combat:CreateModule({
        Name = 'Trigger Bot',
        Function = function(callback)
            if callback then
                repeat
                    local doAttack
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
                            local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
                            rayParams.FilterDescendantsInstances = {lplr.Character}
                            local unit = lplr:GetMouse().UnitRay
                            local localPos = entitylib.character.RootPart.Position
                            local rayRange = (attackRange or 14.4)
                            local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
                            if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
                                local limit = (attackRange)
                                for _, ent in entitylib.List do
                                    doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
                                    if doAttack then break end
                                end
                            end
                            doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
                            if doAttack then bedwars.SwordController:swingSwordAtMouse() end
                        end
                    end
                    task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
                until not TriggerBot.Enabled
            end
        end
    })
    CPS = TriggerBot:CreateTwoSlider({Name = 'CPS', Min = 1, Max = 9, DefaultMin = 7, DefaultMax = 7})
end)
run(function()
    local Velocity, Horizontal, Vertical, Chance, TargetCheck
    local rand, old = Random.new(), nil
    Velocity = vape.Categories.Combat:CreateModule({
        Name = 'Velocity',
        Function = function(callback)
            if callback then
                old = bedwars.KnockbackUtil.applyKnockback
                bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
                    if rand:NextNumber(0, 100) > Chance.Value then return end
                    local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({Range = 50, Part = 'RootPart', Players = true})
                    if check then
                        knockback = knockback or {}
                        if Horizontal.Value == 0 and Vertical.Value == 0 then return end
                        knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
                        knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
                    end
                    return old(root, mass, dir, knockback, ...)
                end
            else
                bedwars.KnockbackUtil.applyKnockback = old
            end
        end
    })
    Horizontal = Velocity:CreateSlider({Name = 'Horizontal', Min = 0, Max = 100, Default = 0, Suffix = '%'})
    Vertical = Velocity:CreateSlider({Name = 'Vertical', Min = 0, Max = 100, Default = 0, Suffix = '%'})
    Chance = Velocity:CreateSlider({Name = 'Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
    TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
run(function()
    local VelocityPlus, Mode, Chance, TargetCheck
    local rand, old = Random.new(), nil
    local function rotateY(v, deg)
    	local r = math.rad(deg)
    	return Vector3.new(v.X * math.cos(r) - v.Z * math.sin(r), 0, v.X * math.sin(r) + v.Z * math.cos(r))
    end
    VelocityPlus = vape.Categories.Combat:CreateModule({
    	Name = 'Velocity Plus',
    	Function = function(callback)
    		if callback then
    			old = bedwars.KnockbackUtil.applyKnockback
    			bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
    				if rand:NextNumber(0, 100) > Chance.Value then return old(root, mass, dir, knockback, ...) end
    				if TargetCheck.Enabled and not entitylib.EntityPosition({Range = 22, Part = 'RootPart', Players = true}) then return old(root, mass, dir, knockback, ...) end
    				local velocity = (root.Position * Vector3.new(1, 0, 1)) - Vector3.new(dir.X, 0, dir.Z)
    				if velocity.Magnitude < 0.001 then return old(root, mass, dir, knockback, ...) end
    				velocity = velocity.Unit
    				local chosen = Mode.Value == 'Random' and ({ 'Left', 'Right', 'Pull' })[rand:NextInteger(1, 3)] or Mode.Value
    				local rdir = chosen == 'Pull' and -velocity or table.find({'Left', 'Right'}, chosen) and rotateY(velocity, chosen == 'Left' and 90 or 90) or velocity
    				return old(root, mass, Vector3.new(root.Position.X - rdir.X * 100, dir.Y, root.Position.Z - rdir.Z * 100), knockback, ...)
    			end
    		else
    			bedwars.KnockbackUtil.applyKnockback = old or bedwars.KnockbackUtil.applyKnockback
    			old = nil
    		end
    	end
    })
    Mode = VelocityPlus:CreateDropdown({Name = 'Direction', List = {'Left', 'Right', 'Pull', 'Random'}, Default = 'Random'})
    Chance = VelocityPlus:CreateSlider({Name = 'Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
    TargetCheck = VelocityPlus:CreateToggle({Name = 'Only when targeting'})
end)
run(function()
    local AntiFall, Mode, Material, Color
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local function getLowGround()
        local mag = math.huge
        for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
            pos = pos * 3
            if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then mag = pos.Y end
        end
        return mag
    end
    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'Anti Fall',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end
                local pos, debounce = getLowGround(), os.clock()
                if pos ~= math.huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = Vector3.new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < os.clock() then
                            debounce = os.clock() + 0.1
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    connection = runService.PreSimulation:Connect(function()
                                        if vape.Modules.Fly.Enabled or InfiniteFly.Enabled or vape.Modules['Long Jump'].Enabled then
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                            return
                                        end
                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
                                            local root = entitylib.character.RootPart
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
                                            root.Velocity *= Vector3.new(1, 0, 1)
                                            rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                            rayCheck.CollisionGroup = root.CollisionGroup
                                            local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
                                            if ray then
                                                for _ = 1, 10 do
                                                    local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
                                                    if not getPlacedBlock(dpos) then
                                                        top = Vector3.new(top.X, pos.Y, top.Z)
                                                        break
                                                    end
                                                end
                                            end
                                            root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
                                            if not frictionTable.Speed then
                                                root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                            end
                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
                            end
                        end
                    end))
                end
            else
                AntiFallDirection = nil
            end
        end
    })
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode', List = {'Normal', 'Collide', 'Velocity'},
        Function = function(val) if AntiFallPart then AntiFallPart.CanCollide = val == 'Collide' end end
    })
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do if v.Name ~= 'ForceField' then table.insert(materials, v.Name) end end
    Material = AntiFall:CreateDropdown({Name = 'Material', List = materials, Function = function(val) if AntiFallPart then AntiFallPart.Material = Enum.Material[val] end end})
    Color = AntiFall:CreateColorSlider({Name = 'Color', DefaultOpacity = 0.5, Function = function(h, s, v, o) if AntiFallPart then AntiFallPart.Color = Color3.fromHSV(h, s, v); AntiFallPart.Transparency = 1 - o end end})
end)
run(function()
    local AutoDodge, Targets, Melee, Range
    local oldroot, clone, hip = nil, nil, 2.5
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    rayParams.RespectCanCollide = true
    local function doClone()
        if store.rootpart then return end
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
            if oldroot and oldroot.Parent then return true end
            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            if not lplr.Character.Parent then return false end
            lplr.Character.Parent = replicatedStorage
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Transparency = 1
            oldroot.Parent = workspace
            store.rootpart = oldroot
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            bedwars.QueryUtil:setQueryIgnored(clone, true)
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            return true
        end
        return false
    end
    local function revertClone()
        if oldroot and oldroot.Parent and entitylib.isAlive then 
            lplr.Character.Parent = replicatedStorage
            oldroot.Parent = lplr.Character
            if clone then
                oldroot.CFrame = clone.CFrame
                oldroot.Velocity = clone.Velocity
                clone:Destroy()
                clone = nil
            end
            lplr.Character.PrimaryPart = oldroot
            lplr.Character.Parent = workspace
            oldroot.CanCollide = true
            entitylib.character.Humanoid.HipHeight = hip or 2.6
            oldroot.Transparency = 1
            oldroot = nil
            store.rootpart = nil
            return true
        end
        return false
    end
    AutoDodge = vape.Categories.Blatant:CreateModule({
    	Name = 'Auto Dodge',
    	Function = function(call)
    		if call then
    			repeat task.wait() until store.matchState ~= 0 and store.map or not AutoDodge.Enabled
    			if not AutoDodge.Enabled then return end
    			rayParams.FilterDescendantsInstances = {store.map}
    			local lowestpoint = 9e9
    			local Dodge = 0
    			for _, v in store.blocks do
    				local point = (v.Position.Y - (v.Size.Y / 2)) - 50
    				if point < lowestpoint then lowestpoint = point end
    			end
                AutoDodge:Clean(runService.PostSimulation:Connect(function()
                    if oldroot and oldroot.Parent then
                        local newpoint, pos = lowestpoint, CFrame.new(clone.CFrame.X, lowestpoint - 6, clone.CFrame.Z)
                        if Dodge then
                            newpoint = workspace:Raycast(pos.Position, Vector3.new(0, 1000, 0), rayParams)
                            if newpoint then newpoint = CFrame.new(clone.CFrame.X, newpoint.Position.Y - 6, clone.CFrame.Z) * CFrame.Angles(math.rad(90), 0, 0) end
                        end
                        oldroot.Velocity = Vector3.zero
                        oldroot.CFrame = Dodge and (newpoint or pos) or (clone.CFrame + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(90), 0, 0)
                    end
                end))
                local last = true
                repeat
                    if entitylib.isAlive then
                        if oldroot then
                            local ownership = isnetworkowner(oldroot)
                            if not ownership and ownership ~= last then notif('AutoDodge', 'Network ownership disowned', 7, 'alert') end
                            last = ownership
                            if not ownership then Dodge = false; revertClone(); task.wait(); continue end
                        end
                        if Melee.Enabled and entitylib.EntityPosition({Range = Range.Value, Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Wallcheck = Targets.Walls.Enabled or nil, Sort = sortmethods.Distance, Part = 'RootPart'}) and doClone() then
                            Dodge = false; task.wait(0.2); Dodge = true; task.wait(0.4)
                        else
                            Dodge = false; revertClone()
                        end
                    end
                    task.wait()
                until not AutoDodge.Enabled
    		else
    			revertClone()
    		end
    	end
    })
    Targets = AutoDodge:CreateTargets({Players = true, NPCs = false})
    Melee = AutoDodge:CreateToggle({Name = 'Melee', Default = true, Function = function(call) pcall(function() Range.Object.Visible = call end) end})
    Range = AutoDodge:CreateSlider({Name = 'Melee Range', Min = 1, Max = 30, Default = 30, Decimal = 5, Darker = true})
    AutoDodge:CreateToggle({Name = 'Projectiles', Default = true})
end)
run(function()
    local AutoKaida, Targets, SwingRange, AttackRange, Sort, Swing, Mouse, GUI, Perfect, Distance
    local function getAttackData()
        local claw = getItem('summoner_claw', nil, true)
        if claw then
            if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end
            if GUI.Enabled and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
            return claw
        end
        return false
    end
    AutoKaida = vape.Categories.Blatant:CreateModule({
        Name = 'Auto Kaida',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive and (workspace:GetServerTimeNow() - bedwars.SummonerClawHandController.lastAttackTime) > bedwars.SummonerKitBalance.CLAW_COOLDOWN then
                        local claw = getAttackData()
                        if claw then
                            local ent = entitylib.EntityPosition({Range = SwingRange.Value, Wallcheck = Targets.Walls.Enabled or nil, Part = 'RootPart', Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Sort = sortmethods[Sort.Value]})
                            if ent then
                                local selfpos = entitylib.character.RootPart.Position
                                local dir = CFrame.lookAt(selfpos, ent.RootPart.Position).LookVector
                                local delta = (ent.RootPart.Position - selfpos)
                                if Perfect.Enabled and (selfpos - ent.RootPart.Position).Magnitude <= Distance.Value then
                                    if bedwars.AbilityController:canUseAbility('summoner_start_charging') and bedwars.AbilityController:canUseAbility('summoner_finish_charging') then
                                        bedwars.AbilityController:useAbility('summoner_start_charging')
                                        task.wait(0.5)
                                        bedwars.AbilityController:useAbility('summoner_finish_charging')
                                        if not Swing.Enabled then continue end
                                    end
                                end
                                if not Swing.Enabled then
                                    local active = false
                                    for _, v in workspace:QueryDescendants('#Summoner_SummonCircle') do
                                        local pivot = v:FindFirstChild('Pivot')
                                        if pivot and math.floor(pivot.Position.X) == math.floor(entitylib.character.RootPart.Position.X) and math.floor(pivot.Position.Z) == math.floor(entitylib.character.RootPart.Position.Z) then
                                            active = true; break
                                        end
                                    end
                                    if active then task.wait(); continue end
                                end
                                if (selfpos - ent.RootPart.Position).Magnitude <= AttackRange.Value then
                                    bedwars.Client:Get('SummonerClawAttackRequest'):SendToServer({position = selfpos + dir * math.max(delta.Magnitude - 16.399, 0), direction = dir, clientTime = workspace:GetServerTimeNow()})
                                end
                                bedwars.SummonerClawHandController.lastAttackTime = workspace:GetServerTimeNow()
                                bedwars.SummonerClawController:clawAttack(lplr, selfpos, dir, claw.tool.Name)
                            end
                        end
                    end
                    task.wait(0.1)
                until not AutoKaida.Enabled
            end
        end
    })
    Targets = AutoKaida:CreateTargets({Players = true})
    SwingRange = AutoKaida:CreateSlider({Name = 'Swing Range', Min = 1, Max = 32, Default = 32})
    AttackRange = AutoKaida:CreateSlider({Name = 'Attack Range', Min = 1, Max = 32, Default = 32})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    Sort = AutoKaida:CreateDropdown({Name = 'Target mode', List = methods, Default = methods[2]})
    Mouse = AutoKaida:CreateToggle({Name = 'Require mouse down'})
    GUI = AutoKaida:CreateToggle({Name = 'GUI check'})
    Swing = AutoKaida:CreateToggle({Name = 'Swing during ability', Default = true})
    Perfect = AutoKaida:CreateToggle({Name = 'Perfect ability', Function = function(callback) pcall(function() Distance.Object.Visible = callback end) end})
    Distance = AutoKaida:CreateSlider({Name = 'Distance', Min = 3, Max = 15, Default = 6, Visible = false, Darker = true})
end)
run(function()
    local DamageBoost, stack
    DamageBoost = vape.Categories.Blatant:CreateModule({
    	Name = 'Damage Boost',
    	Function = function(callback)
    		if callback then
    			DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
    				if entitylib.isAlive and os.clock() > (stack or 0) and damageTable.entityInstance == lplr.Character and not LongJump.Enabled then
    					local horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0)
    					knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {vertical = 0, horizontal = horizontal}).Magnitude * (0.9 + lplr:GetNetworkPing())
                        stack = os.clock() + (knockbackSpeed / 45)
                        knockbackBoost = os.clock() + (horizontal / 3.5)
    				end
    			end))
    		end
    	end
    })
end)
run(function()
    local FastBreak, BedCheck, Blacklist, Blacklisted, Time
    local newlist, old = {}, nil
    local function find(tab, ind)
    	for i, v in tab do if v == ind or v:find(ind) then return i end end
    	return nil
    end
    FastBreak = vape.Categories.Blatant:CreateModule({
    	Name = 'Fast Break',
    	Function = function(callback)
    		if callback then
    			old = bedwars.BlockBreaker.hitBlock
    			bedwars.BlockBreaker.hitBlock = function(self, ...)
    				local _, params = unpack({ ... })
    				pcall(function()
    					local block, info = nil, self.clientManager:getBlockSelector():getMouseInfo(1, {ray = params})
    					block = info and info.target and info.target.blockInstance or nil
    					if block and (not Blacklist.Enabled or not find(newlist, block.Name)) and (not BedCheck.Enabled or block.Name ~= 'bed') then
    						bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
    					end
    				end)
    				return old(self, ...)
    			end
    			repeat
    				if (os.clock() - store.lastHit) > 0.3 then bedwars.BlockBreakController.blockBreaker:setCooldown(0.3) end
    				task.wait(0.1)
    			until not FastBreak.Enabled
    		else
    			bedwars.BlockBreaker.hitBlock = old
    			bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
    		end
    	end
    })
    Time = FastBreak:CreateSlider({Name = 'Break speed', Min = 0, Max = 0.3, Default = 0.25, Decimal = 100})
    BedCheck = FastBreak:CreateToggle({Name = 'Bed Check'})
    Blacklist = FastBreak:CreateToggle({Name = 'Use blacklist', Function = function(callback) if Blacklisted and Blacklisted.Object then Blacklisted.Object.Visible = callback end end})
    Blacklisted = FastBreak:CreateTextList({Name = 'Blocks', Darker = true, Visible = false, Function = function(list)
    		newlist = {}
    		for _, v in list do
    			if v:find('iron') then table.insert(newlist, 'iron_ore_mesh_block') else table.insert(newlist, v) end
    		end
    	end
    })
end)
run(function()
    local Value, VerticalValue, WallCheck, PopBalloons, TP
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local up, down, old = 0, 0
    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
                bedwars.BalloonController.deflateBalloon = function() end
                local tpTick, tpToggle, oldy = os.clock(), true
                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then bedwars.BalloonController:inflateBalloon() end
                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then bedwars.BalloonController:inflateBalloon() end
                end))
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
                        local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
                        local mass = (1.5 + (flyAllowed and 6 or 0) * (os.clock() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
                        local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
                        local velo = getSpeed()
                        local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
                        rayCheck.CollisionGroup = root.CollisionGroup
                        if WallCheck.Enabled then
                            local ray = workspace:Raycast(root.Position, destination, rayCheck)
                            if ray then destination = ((ray.Position + ray.Normal) - root.Position) end
                        end
                        if not flyAllowed then
                            if tpToggle then
                                local airleft = (os.clock() - entitylib.character.AirTime)
                                if airleft > 2 then
                                    if not oldy then
                                        local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled then
                                            tpToggle = false
                                            oldy = root.Position.Y
                                            tpTick = os.clock() + 0.11
                                            root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < os.clock() then
                                        local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end
                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
                    end
                end))
                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then down = -1 end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then down = 0 end
                end))
            else
                bedwars.BalloonController.deflateBalloon = old
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do bedwars.BalloonController:deflateBalloon() end
                end
            end
        end
    })
    Value = Fly:CreateSlider({Name = 'Speed', Min = 1, Max = 23, Default = 23})
    VerticalValue = Fly:CreateSlider({Name = 'Vertical Speed', Min = 1, Max = 150, Default = 50})
    WallCheck = Fly:CreateToggle({Name = 'Wall Check', Default = true})
    PopBalloons = Fly:CreateToggle({Name = 'Pop Balloons', Default = true})
    TP = Fly:CreateToggle({Name = 'TP Down', Default = true})
end)
run(function()
    local Mode, Expand, objects, set = nil, nil, {}, nil
    local function createHitbox(ent)
        if ent.Targetable and ent.Player then
            local hitbox = Instance.new('Part')
            hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
            hitbox.Position = ent.RootPart.Position
            hitbox.CanCollide = false
            hitbox.Massless = true
            hitbox.Transparency = 1
            hitbox.Parent = ent.Character
            local weld = Instance.new('Motor6D')
            weld.Part0 = hitbox
            weld.Part1 = ent.RootPart
            weld.Parent = hitbox
            objects[ent] = hitbox
        end
    end
    HitBoxes = vape.Categories.Blatant:CreateModule({
        Name = 'Hit Boxes',
        Function = function(callback)
            if callback then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
                    set = true
                else
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
                    HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
                        if objects[ent] then objects[ent]:Destroy(); objects[ent] = nil end
                    end))
                    for _, ent in entitylib.List do createHitbox(ent) end
                end
            else
                if set then debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8); set = nil end
                for _, part in objects do part:Destroy() end
                table.clear(objects)
            end
        end
    })
    Mode = HitBoxes:CreateDropdown({Name = 'Mode', List = {'Sword', 'Player'}, Function = function() if HitBoxes.Enabled then HitBoxes:Toggle(); HitBoxes:Toggle() end end})
    Expand = HitBoxes:CreateSlider({Name = 'Expand amount', Min = 0, Max = 14.4, Default = 14.4, Decimal = 10, Function = function(val)
        if HitBoxes.Enabled then
            if Mode.Value == 'Sword' then debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3)) else
                for _, part in objects do part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5) end
            end
        end
    end})
end)
run(function()
    vape.Categories.Blatant:CreateModule({
        Name = 'Keep Sprint',
        Function = function(callback)
            debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
            bedwars.SprintController:stopSprinting()
        end
    })
end)run(function()
    local Killaura, Continue, Targets, Mode, Sort, SwingRange, AttackRange, AirChance, SwingTime, Hitreg, Dynamic
    local Sync = {}
    local UpdateRate, Attackable, AngleSlider, MaxTargets, Mouse, Swing, GUI, BoxSwingColor, BoxAttackColor
    local ParticleTexture, ParticleColor1, ParticleColor2, ParticleSize, Face, Animation, AnimationMode, AnimationSpeed, AnimationTween
    local Limit, LegitAura
    local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, os.clock()
    local AttackRemote = {FireServer = function(self, ...) end}
    local projectileRemote = {InvokeServer = function(self, ...) end}
    task.spawn(function() AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance end)
    task.spawn(function() projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance end)
    local FastHits, Legit, FireRate, Whitelist
    local FireRates = {}
    local function getAmmo(check)
    	for _, item in store.inventory.inventory.items do
    		if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then return item.itemType end
    	end
    	return nil
    end
    local function getProjectiles()
    	local items = {}
    	for _, item in store.inventory.inventory.items do
    		local proj = bedwars.ItemMeta[item.itemType].projectileSource
    		local ammo = proj and getAmmo(proj)
    		if ammo and table.find(Whitelist.ListEnabled, ammo) then
    			table.insert(items, {item, ammo, proj.projectileType(ammo), proj})
    		end
    	end
    	return items
    end
    local function getHitreg(distance)
        local hitreg = math.max(Hitreg.Value + 1, 36)
        if Dynamic.Enabled then
            local limit = hitreg < 14.4 and Hitreg or 14.4
            local window = AttackRange.Value - limit
            if window < 1 then window = 1 end
            local scale = (distance - limit) / window
            if scale < 0 then scale = 0 elseif scale > 1 then scale = 1 end
            hitreg = hitreg + (limit - hitreg) * scale
        end
        return hitreg
    end
    local function getAttackData()
        if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) then return false end
        if Attackable.Enabled then
            if not entitylib.isAlive then return false end
            if (lplr.Character:GetAttribute('StunnedUntilTime') or 0) > workspace:GetServerTimeNow() then return false end
            if lplr.Character:FindFirstChild('elk') then return false end
            for _, v in bedwars.StatusEffectUtil:getAllActive(lplr.Character) do
                if v.statusEffect == 'frozen' then return false end
            end
        end
        if GUI.Enabled and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end
        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled and (store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid) then return false end
        if LegitAura.Enabled and (os.clock() - bedwars.SwordController.lastSwing) > 0.2 then return false end
        return sword, meta
    end
    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
            if callback then
                if Animation.Enabled then
                    local fake = {Controllers = {ViewmodelController = {isVisible = function() return not Attacking end, playAnimation = function(...) if not Attacking then bedwars.ViewmodelController:playAnimation(select(2, ...)) end end}}}
                    debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 7, fake)
                    debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)
                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0 end
                                local first = not started
                                started = true
                                if AnimationMode.Value == 'Random' then anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}} end
                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {C0 = armC0 * v.CFrame})
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not Killaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {C0 = armC0})
                                AnimTween:Play()
                            end
                            if not started then task.wait(1 / UpdateRate.Value) end
                        until (not Killaura.Enabled) or (not Animation.Enabled)
                    end)
                end
                local swingCooldown, switchCooldown, lastSwing, targetIndex = os.clock(), os.clock(), 0, 0
                local lastShot, projectileIndex, lastHit = os.clock(), 0, 0
                repeat
                    local attacked, sword, meta = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil
                    if sword then
                        local plrs = entitylib.AllPosition({Range = SwingRange.Value, Wallcheck = Targets.Walls.Enabled or nil, Part = 'RootPart', Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Limit = Mode.Value == 'Single' and 1 or MaxTargets.Value, Sort = sortmethods[Sort.Value]})
                        if #plrs > 0 then
                            switchItem(sword.tool, 0)
                            local selfpos = entitylib.character.RootPart.Position
                            local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                            if os.clock() > switchCooldown and Mode.Value == 'Switch' then switchCooldown = os.clock() + 0.7; targetIndex += 1 end
                            if not plrs[targetIndex] then targetIndex = 1 end
                            for i, v in plrs do
                                if Mode.Value == 'Switch' and i ~= targetIndex then continue end
                                local delta = (v.RootPart.Position - selfpos)
                                local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                                if angle > (math.rad(AngleSlider.Value) / 2) then continue end
                                table.insert(attacked, {Entity = v, Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor})
                                targetinfo.Targets[v] = os.clock() + 1
                                if not Attacking then
                                    Attacking = true
                                    store.KillauraTarget = v
                                    if not Swing.Enabled and AnimDelay < os.clock() and not LegitAura.Enabled then
                                        AnimDelay = os.clock() + math.max(SwingTime.Value, 0.11)
                                        lastSwing = os.clock()
                                        bedwars.SwordController:playSwordEffect(meta, false)
                                        if meta.displayName:find(' Scythe') then bedwars.ScytheController:playLocalAnimation() end
                                        if vape.ThreadFix then setthreadidentity(8) end
                                    end
                                end
                                if delta.Magnitude > AttackRange.Value then continue end
                                local actualRoot = v.Character.PrimaryPart
                                if actualRoot and (not Sync.Enabled or (os.clock() - swingCooldown >= SwingTime.Value)) and (v.Humanoid.FloorMaterial ~= Enum.Material.Air or math.random(1, 100) < AirChance.Value) then
                                    local current, delay = os.clock(), 10 / math.max(Hitreg.Value, 1)
                                    if Hitreg.Value >= 36 or (current - lastHit) >= delay then
                                        lastHit += delay
                                        if current - lastHit > delay then lastHit = current end
                                        local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
                                        local pos = selfpos + dir * math.max(delta.Magnitude - 14.4, 0)
                                        bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                                        store.attackReach = (delta.Magnitude * 100) // 1 / 100
                                        store.attackReachUpdate = os.clock() + 1
                                        swingCooldown = os.clock()
                                        AttackRemote:FireServer({weapon = sword.tool, chargedAttack = {chargeRatio = 0}, entityInstance = v.Character, validate = {raycast = {cameraPosition = {value = pos}, cursorDirection = {value = dir}}, targetPosition = {value = actualRoot.Position + (CFrame.lookAt(actualRoot.Position, selfpos).LookVector * math.max((selfpos - actualRoot.Position).Magnitude / 10, 0))}, selfPosition = {value = pos}}})
                                        if FastHits.Enabled and os.clock() > lastShot and not entitylib.Wallcheck(entitylib.character.RootPart.Position, actualRoot.Position, {gameCamera, lplr.Character, v.Character}) then
                                            local projectiles = getProjectiles()
                                            if #projectiles > 0 then
                                                projectileIndex += 1
                                                if not projectiles[projectileIndex] then projectileIndex = 1 end
                                                local item, ammo, projectile, itemMeta = unpack(projectiles[projectileIndex])
                                                if os.clock() > (FireRates[item.itemType] or 0) then
                                                    local projmeta = bedwars.ProjectileMeta[projectile]
                                                    local projSpeed, gravity = projmeta.launchVelocity, projmeta.gravitationalAcceleration or 196.2
                                                    local oldhotbar, oldtool = store.inventory.hotbarSlot, store.hand.tool
                                                    local hotbar = getHotbar(item.tool)
                                                    if hotbar then switchItem(item.tool); if Legit.Enabled then hotbarSwitch(hotbar) end end
                                                    local calc = prediction.SolveTrajectory(selfpos, projSpeed, gravity, v.RootPart.Position, v.RootPart.Velocity, workspace.Gravity, v.HipHeight, v.Jumping and 42.6 or nil, nil, nil, lplr:GetNetworkPing())
                                                    if calc then
                                                        local sdir, id = CFrame.lookAt(selfpos, calc).LookVector, httpService:GenerateGUID(true)
                                                        local shootPosition = (CFrame.new(selfpos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
                                                        bedwars.ProjectileController:createLocalProjectile(itemMeta, ammo, projectile, shootPosition, id, sdir * projSpeed, {drawDurationSeconds = 1})
                                                        local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, sdir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
                                                        if res then res.Parent = replicatedStorage; FireRates[item.itemType] = os.clock() + itemMeta.fireDelaySec; local shoot = itemMeta.launchSound; shoot = shoot and shoot[math.random(1, #shoot)] or nil; if shoot then bedwars.SoundManager:playSound(shoot) end end
                                                        lastShot = os.clock() + (lplr:GetNetworkPing() + FireRate.Value)
                                                    end
                                                    task.spawn(function() if Legit.Enabled then hotbarSwitch(oldhotbar); if oldtool then switchItem(oldtool.tool) end end end)
                                                end
                                            end
                                        end
                                        if Mode.Value ~= 'Multi' then break end
                                    end
                                end
                            end
                        else
                            if (os.clock() - lastSwing) < Continue:GetRandomValue() and not Swing.Enabled and not LegitAura.Enabled and AnimDelay < os.clock() then
                                AnimDelay = os.clock() + math.max(SwingTime.Value, 0.11)
                                if vape.ThreadFix then setthreadidentity(8) end
    							pcall(function()
    								bedwars.SwordController:playSwordEffect(meta, false)
                                    if meta.displayName:find(' Scythe') then bedwars.ScytheController:playLocalAnimation() end
    							end)
                            end
                        end
                    end
                    for i, v in Boxes do
                        v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                        if v.Adornee then v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value); v.Transparency = 1 - attacked[i].Check.Opacity end
                    end
                    for i, v in Particles do
                        v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                        v.Parent = attacked[i] and gameCamera or nil
                    end
                    if Face.Enabled and attacked[1] then
                        local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                    end
                    task.wait(1 / UpdateRate.Value)
                until not Killaura.Enabled
            else
                store.KillauraTarget = nil
                for _, v in Boxes do v.Adornee = nil end
                for _, v in Particles do v.Parent = nil end
                if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
                debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 7, bedwars.Knit)
                debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
                Attacking = false
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {C0 = armC0})
                    AnimTween:Play()
                end
            end
        end
    })
    Targets = Killaura:CreateTargets({Players = true, NPCs = true})
    Continue = Killaura:CreateTwoSlider({Name = 'Continue Swinging', Min = 0, Max = 2, Decimal = 100, DefaultMin = 0, DefaultMax = 0.1, Suffix = 'seconds'})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    SwingRange = Killaura:CreateSlider({Name = 'Swing range', Min = 1, Max = 28, Default = 28})
    AttackRange = Killaura:CreateSlider({Name = 'Attack range', Min = 1, Max = 28, Default = 28})
    AngleSlider = Killaura:CreateSlider({Name = 'Max angle', Min = 1, Max = 360, Default = 360})
    AirChance = Killaura:CreateSlider({Name = 'Air Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
    SwingTime = Killaura:CreateSlider({Name = 'Swing time', Min = 0, Max = 2, Decimal = 100, Default = 0.11, Suffix = 'seconds'})
    Hitreg = Killaura:CreateSlider({Name = 'Hitreg', Min = 1, Max = 36, Default = 36, Suffix = 'reg'})
    UpdateRate = Killaura:CreateSlider({Name = 'Update rate', Min = 1, Max = 120, Default = 60, Suffix = 'hz'})
    FastHits = Killaura:CreateToggle({Name = 'Fast Hits', Default = false, Function = function(callback) pcall(function() Legit.Object.Visible = callback; FireRate.Object.Visible = callback; Whitelist.Object.Visible = callback end) end})
    Whitelist = Killaura:CreateTextList({Name = 'Projectiles', Default = {'arrow', 'snowball'}, Darker = true, Visible = false})
    Legit = Killaura:CreateToggle({Name = 'Legit Switch', Darker = true, Visible = false})
    FireRate = Killaura:CreateSlider({Name = 'Fire rate', Suffix = 'seconds', Min = 0, Max = 2, Decimal = 100, Darker = true, Visible = false, Default = 0.05})
    MaxTargets = Killaura:CreateSlider({Name = 'Max targets', Min = 1, Max = 5, Default = 5})
    Mode = Killaura:CreateDropdown({Name = 'Attack Mode', List = {'Single', 'Multi', 'Switch'}, Default = 'Switch', Function = function(val) pcall(function() MaxTargets.Object.Visible = val ~= 'Single' end) end})
    Sort = Killaura:CreateDropdown({Name = 'Target Mode', List = methods})
    Dynamic = Killaura:CreateToggle({Name = 'Dynamic hits'})
    Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
    Swing = Killaura:CreateToggle({Name = 'No Swing'})
    GUI = Killaura:CreateToggle({Name = 'GUI check'})
    Killaura:CreateToggle({Name = 'Show target', Function = function(callback)
            BoxSwingColor.Object.Visible = callback; BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.AlwaysOnTop = true; box.Size = Vector3.new(3, 5, 3); box.CFrame = CFrame.new(0, -0.5, 0); box.ZIndex = 0; box.Parent = vape.gui; Boxes[i] = box
                end
            else
                for _, v in Boxes do v:Destroy() end; table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = Killaura:CreateColorSlider({Name = 'Target Color', Darker = true, DefaultHue = 0.6, DefaultOpacity = 0.5, Visible = false})
    BoxAttackColor = Killaura:CreateColorSlider({Name = 'Attack Color', Darker = true, DefaultOpacity = 0.5, Visible = false})
    Killaura:CreateToggle({Name = 'Target particles', Function = function(callback)
            ParticleTexture.Object.Visible = callback; ParticleColor1.Object.Visible = callback; ParticleColor2.Object.Visible = callback; ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2); part.Anchored = true; part.CanCollide = false; part.Transparency = 1; part.CanQuery = false; part.Parent = Killaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5; particles.Size = NumberSequence.new(ParticleSize.Value); particles.Shape = Enum.ParticleEmitterShape.Sphere; particles.Texture = ParticleTexture.Value; particles.Transparency = NumberSequence.new(0); particles.Lifetime = NumberRange.new(0.4); particles.Speed = NumberRange.new(16); particles.Rate = 128; particles.Drag = 16; particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)), ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))})
                    particles.Parent = part; Particles[i] = part
                end
            else
                for _, v in Particles do v:Destroy() end; table.clear(Particles)
            end
        end
    })
    ParticleTexture = Killaura:CreateTextBox({Name = 'Texture', Default = 'rbxassetid://14736249347', Function = function() for _, v in Particles do v.ParticleEmitter.Texture = ParticleTexture.Value end end, Darker = true, Visible = false})
    ParticleColor1 = Killaura:CreateColorSlider({Name = 'Color Begin', Function = function(h, s, v) for _, p in Particles do p.ParticleEmitter.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(h, s, v)), ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))}) end end, Darker = true, Visible = false})
    ParticleColor2 = Killaura:CreateColorSlider({Name = 'Color End', Function = function(h, s, v) for _, p in Particles do p.ParticleEmitter.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)), ColorSequenceKeypoint.new(1, Color3.fromHSV(h, s, v))}) end end, Darker = true, Visible = false})
    ParticleSize = Killaura:CreateSlider({Name = 'Size', Min = 0, Max = 1, Default = 0.2, Decimal = 100, Function = function(val) for _, p in Particles do p.ParticleEmitter.Size = NumberSequence.new(val) end end, Darker = true, Visible = false})
    Face = Killaura:CreateToggle({Name = 'Face target'})
    Animation = Killaura:CreateToggle({Name = 'Custom Animation', Function = function(callback) AnimationMode.Object.Visible = callback; AnimationTween.Object.Visible = callback; AnimationSpeed.Object.Visible = callback; if Killaura.Enabled then Killaura:Toggle(); Killaura:Toggle() end end})
    local animnames = {}; for i in anims do table.insert(animnames, i) end
    AnimationMode = Killaura:CreateDropdown({Name = 'Animation Mode', List = animnames, Darker = true, Visible = false})
    AnimationSpeed = Killaura:CreateSlider({Name = 'Animation Speed', Min = 0, Max = 2, Default = 1, Decimal = 10, Darker = true, Visible = false})
    AnimationTween = Killaura:CreateToggle({Name = 'No Tween', Darker = true, Visible = false})
    Attackable = Killaura:CreateToggle({Name = 'Attackable check'})
    Limit = Killaura:CreateToggle({Name = 'Limit to items'})
    LegitAura = Killaura:CreateToggle({Name = 'Swing only'})
end)
run(function()
    local Value, CameraDir, start
    local JumpTick, JumpSpeed, Direction = os.clock(), 0
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function() projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance end)
    local function launchProjectile(item, pos, proj, speed, dir)
        if not pos then return end
        pos = pos - dir * 0.1
        local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
        switchItem(item.tool, 0)
        task.wait(0.1)
        bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
        if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
            local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
            shoot = shoot and shoot[math.random(1, #shoot)] or nil
            if shoot then bedwars.SoundManager:playSound(shoot) end
        end
    end
    local LongJumpMethods = {
        cannon = function(_, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            bedwars.placeBlock(rounded, 'cannon', false)
            task.delay(0, function()
                local block, blockpos = getPlacedBlock(rounded)
                if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
                    local breaktype = bedwars.ItemMeta[block.Name].block.breakType
                    local tool = store.tools[breaktype]
                    if tool then switchItem(tool.tool) end
                    bedwars.Client:Get(remotes.CannonAim):SendToServer({cannonBlockPos = blockpos, lookVector = dir})
                    local broken = 0.1
                    if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then broken = 0.4; bedwars.breakBlock(block, true, true) end
                    task.delay(broken, function()
                        for _ = 1, 3 do
                            local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
                            if call then bedwars.breakBlock(block, true, true); JumpSpeed = 5.25 * Value.Value; JumpTick = os.clock() + 2.3; Direction = Vector3.new(dir.X, 0, dir.Z).Unit; break end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end,
        cat = function(_, _, dir)
            LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function() JumpSpeed = 4 * Value.Value; JumpTick = os.clock() + 2.5; Direction = Vector3.new(dir.X, 0, dir.Z).Unit; entitylib.character.RootPart.Velocity = Vector3.zero end))
            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled end
            if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then bedwars.AbilityController:useAbility('CAT_POUNCE') end
        end,
        fireball = function(item, pos, dir) launchProjectile(item, pos, 'fireball', 60, dir) end,
        grappling_hook = function(item, pos, dir) launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir) end,
        jade_hammer = function(item, _, dir)
            if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled end
            if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then bedwars.AbilityController:useAbility(item.itemType..'_jump'); JumpSpeed = 1.4 * Value.Value; JumpTick = os.clock() + 2.5; Direction = Vector3.new(dir.X, 0, dir.Z).Unit end
        end,
        tnt = function(item, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
            bedwars.placeBlock(rounded, item.itemType, false)
        end,
        wood_dao = function(item, pos, dir)
            if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled end
            if LongJump.Enabled then bedwars.SwordController.lastAttack = workspace:GetServerTimeNow(); switchItem(item.tool, 0.1); replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {direction = dir, origin = pos, weapon = item.itemType}); JumpSpeed = 4.5 * Value.Value; JumpTick = os.clock() + 2.4; Direction = Vector3.new(dir.X, 0, dir.Z).Unit end
        end
    }
    for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do LongJumpMethods[v] = LongJumpMethods.wood_dao end
    LongJumpMethods.void_axe = LongJumpMethods.jade_hammer; LongJumpMethods.siege_tnt = LongJumpMethods.tnt; LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
    LongJump = vape.Categories.Blatant:CreateModule({
        Name = 'Long Jump',
        Function = function(callback)
            frictionTable.LongJump = callback or nil
            updateVelocity()
            if callback then
                LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
                        local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {vertical = 0, horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)}).Magnitude * 1.1
                        if knockbackBoost >= JumpSpeed then
                            local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
                            if not pos then return end
                            local vec = (entitylib.character.RootPart.Position - pos)
                            JumpSpeed = knockbackBoost; JumpTick = os.clock() + 2.5; Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                        end
                    end
                end))
                LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
                    if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
                        local vec = entitylib.character.RootPart.CFrame.LookVector
                        JumpSpeed = 2.5 * Value.Value; JumpTick = os.clock() + 2.5; Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                    end
                end))
                start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
                LongJump:Clean(runService.PreSimulation:Connect(function(dt)
                    local root = entitylib.isAlive and entitylib.character.RootPart or nil
                    if root and isnetworkowner(root) then
                        if JumpTick > os.clock() then
                            root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - os.clock()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0) else root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z) end
                            start = nil
                        else
                            if start then root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector) end
                            root.AssemblyLinearVelocity = Vector3.zero; JumpSpeed = 0
                        end
                    else
                        start = nil
                    end
                end))
                if store.hand and LongJumpMethods[store.hand.tool.Name] then task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector); return end
                for i, v in LongJumpMethods do
                    local item = getItem(i)
                    if item or store.equippedKit == i then task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector); break end
                end
            else
                JumpTick, Direction, JumpSpeed = os.clock(), nil, 0
            end
        end
    })
    Value = LongJump:CreateSlider({Name = 'Speed', Min = 1, Max = 37, Default = 37})
    CameraDir = LongJump:CreateToggle({Name = 'Camera Direction'})
end)
run(function()
    local MouseTP, Movement, Mode
    local rayParams = RaycastParams.new()
    rayParams.RespectCanCollide = true; rayParams.FilterType = Enum.RaycastFilterType.Include
    local MouseTPs = {
    	Items = function(position)
    		local item = getItem('telepearl') or getItem('fireball')
    		local localPosition = entitylib.character.RootPart.Position
    		if item then
    			if item.itemType == 'telepearl' then
    				local meta = bedwars.ProjectileMeta.telepearl
    				local calc = prediction.SolveTrajectory(localPosition, meta.launchVelocity, meta.gravitationalAcceleration, position, Vector3.zero, workspace.Gravity, 0, 0)
    				if calc then position = calc end
    				local shootPosition = (CFrame.new(localPosition, position) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    				switchItem(item.tool)
    				bedwars.Client:Get(remotes.FireProjectile):CallServerAsync(item.tool, 'telepearl', 'telepearl', shootPosition, localPosition, CFrame.lookAt(localPosition, position).LookVector * meta.launchVelocity, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045):andThen(function(result) if result then bedwars.SoundManager:playSound('rbxassetid://6866223756') end end)
    				return true
    			elseif item.itemType == 'fireball' and (localPosition - Vector3.new(position.X, localPosition.Y, position.Z)).Magnitude <= 200 then
    				local root = entitylib.character.RootPart
    				local ray = workspace:Raycast(localPosition, Vector3.new(0, -1000, 0), rayParams)
    				if ray then
    					localPosition = ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
    					root.Velocity = Vector3.zero; root.CFrame = CFrame.new(localPosition)
    					MouseTP:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
    						if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
    							local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {vertical = 0, horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)}).Magnitude * 1.1
    							if knockbackBoost >= 38 then repeat task.wait() until (root.Position - position).Magnitude <= 1 end
    						end
    					end))
    					local shootPosition = (CFrame.new(localPosition, position) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    					switchItem(item.tool)
    					bedwars.Client:Get(remotes.FireProjectile):CallServerAsync(item.tool, 'fireball', 'fireball', shootPosition, localPosition, Vector3.new(0, -68, 0), httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045):andThen(function(result) if result then bedwars.SoundManager:playSound('rbxassetid://7192289445') end end)
    					task.wait(2.5)
    					return true
    				end
    			end
    		end
    		return false
    	end,
    	Kits = function() end
    }
    MouseTP = vape.Categories.Blatant:CreateModule({
    	Name = 'Mouse TP',
    	Function = function(callback)
    		if callback then
    			local position = nil
    			if Mode.Value == 'Mouse' then
    				rayParams.FilterDescendantsInstances = { workspace:WaitForChild('Map', 9e9) }
    				local ray = cloneref(lplr:GetMouse()).UnitRay
    				ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayParams)
    				position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
    			elseif Mode.Value == 'Player' then
    				local ent = entitylib.EntityMouse({Range = math.huge, Part = 'RootPart', Players = true})
    				position = ent and ent.RootPart.Position
    			end
    			if position then
    				if Movement.Value == 'All' then
    					if not MouseTPs.Kits(position) and not MouseTPs.Items(position) then notif('MouseTP', 'Couldn\'t find an item or a kit to teleport with', 5) end
    				elseif not MouseTPs[Movement.Value](position) then
    					notif('MouseTP', `Couldn't find {Movement.Value:lower()} to teleport with`, 5)
    				end
    			else
    				notif('MouseTP', 'No position found.', 5)
    			end
    			if MouseTP.Enabled then MouseTP:Toggle() end
    		end
    	end
    })
    Mode = MouseTP:CreateDropdown({Name = 'Mode', List = {'Mouse', 'Player'}})
    Movement = MouseTP:CreateDropdown({Name = 'Movement', List = {'All', 'Kits', 'Items'}})
end)
run(function()
    local old
    vape.Categories.Blatant:CreateModule({
        Name = 'No Slow',
        Function = function(callback)
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if callback then
                old = modifier.addModifier
                modifier.addModifier = function(self, tab)
                    if tab.moveSpeedMultiplier then tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1) end
                    return old(self, tab)
                end
                for i in modifier.modifiers do
                    if (i.moveSpeedMultiplier or 1) < 1 then modifier:removeModifier(i) end
                end
            else
                modifier.addModifier = old; old = nil
            end
        end
    })
end)
run(function()
    local OwlAura, Targets, Range
    OwlAura = vape.Categories.Blatant:CreateModule({
        Name = 'Owl Aura',
        Function = function(callback)
            if callback then
                local owls = collection('Owl', OwlAura, function(self, obj) task.delay(1, function() if obj and obj.Parent and obj:GetAttribute('Owner') == lplr.UserId then table.insert(self, obj) end end) end)
                repeat
                    if store.equippedKit ~= 'owl' then task.wait(3); continue end
                    if entitylib.isAlive then
                        local owl = owls[1]
                        if owl then
                            local origin = owl.Part.Position
                            local plr = entitylib.EntityPosition({Origin = origin, Range = Range.Value, Part = 'RootPart', Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Wallcheck = Targets.Walls.Enabled, Sort = sortmethods.Health})
                            if plr then
                                local meta = table.clone(bedwars.ProjectileMeta.owl_projectile)
                                local calc = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
                                if calc then
                                    local dir = CFrame.lookAt(origin, calc).LookVector * meta.launchVelocity
                                    bedwars.Client:Get('OwlAiming'):SendToServer({owl = owl.Part, starting = true})
                                    bedwars.Client:Get('OwlFireProjectile'):SendToServer({ProjectileRefId = vape.Libraries.string:GenerateString(8), direction = dir, fromPosition = origin, initialVelocity = dir})
                                    task.wait(lplr:GetNetworkPing())
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not OwlAura.Enabled
            else
                bedwars.Client:Get('OwlAiming'):SendToServer({starting = false})
            end
        end
    })
    Targets = OwlAura:CreateTargets({Players = true, Wallcheck = true})
    Range = OwlAura:CreateSlider({Name = 'Range', Min = 1, Max = 50, Default = 50})
end)
run(function()
    local PlayerAttach, Range, Targets
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    PlayerAttach = vape.Categories.Blatant:CreateModule({
        Name = 'Player Attach',
        Function = function(call)
            if call then
                repeat
                    if entitylib.isAlive then
                        local plr = entitylib.AllPosition({Range = Range.Value, Wallcheck = Targets.Walls.Enabled or nil, Part = 'RootPart', Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Limit = 1, Sort = function(a, b) return a.Entity.Health < b.Entity.Health end})[1]
                        if plr then
                            rayCheck.FilterDescendantsInstances = {plr.RootPart.Parent, lplr.Character}
                            entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(0, entitylib.character.RootPart.Size.Y / 2 + entitylib.character.Humanoid.HipHeight + 0.25 * 3, 0)
                            entitylib.character.RootPart.CFrame = plr.RootPart.CFrame + (not workspace:Raycast(plr.RootPart.Position, plr.RootPart.CFrame.LookVector, rayCheck) and (plr.RootPart.CFrame.LookVector * 1.4) or Vector3.zero)
                        end
                    end
                    task.wait()
                until not PlayerAttach.Enabled
            end
        end
    })
    Targets = PlayerAttach:CreateTargets({Players = true, NPCs = true})
    Range = PlayerAttach:CreateSlider({Name = 'Range', Min = 1, Max = 35, Default = 23})
end)
run(function()
    local Prediction, AutoCharge, TargetPart, Targets, FOV, Sort, OtherProjectiles, Blacklist
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
    local launchHook, oldd
    local function getMousePosition() return inputService.TouchEnabled and gameCamera.ViewportSize / 2 or inputService.GetMouseLocation(inputService) end
    local function getPosition(ent, proj)
    	if TargetPart.Value == 'Closest' then
    		local localPosition, magnitude, part = getMousePosition(), 9e9, nil
    		for _, v in ent:GetChildren() do
    			if pcall(function() return v.Position end) then
    				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)
    				if vis then
    					local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude
    					if mag < magnitude then magnitude = mag; part = v end
    				end
    			end
    		end
    		return part and part.Position or ent.PrimaryPart.Position
    	elseif TargetPart.Value == 'Dynamic' then
    		local tool = store.hand.tool
    		if tool and tool.Name:find('headhunter') then return ent.Head.Position end
    		return ent.PrimaryPart.Position
    	end
    	return
    end
    local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
    	Name = 'Projectile Aimbot',
    	Disabled = not canDebug,
    	Function = function(callback)
    		if callback then
    			oldd = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
    			launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileAimbot', 100, function(nextLaunch, ...)
    				local self, projmeta, worldmeta, origin, shootpos = ...
    				local plr = entitylib.EntityMouse({Part = 'RootPart', Range = FOV.Value, Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Wallcheck = Targets.Walls.Enabled, Sort = sortmethods[Sort.Value or 'Distance'], Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero})
    				if plr then
    					local pos = shootpos or self:getLaunchPosition(origin)
    					if not pos then return nextLaunch(...) end
    					if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then return nextLaunch(...) end
    					if table.find(Blacklist.ListEnabled or {}, ((projmeta.projectile == 'glue_trap' or projmeta.projectile == 'glue_projectile') and 'gloop' or projmeta.projectile)) then return nextLaunch(...) end
    					local meta = projmeta:getProjectileMeta()
    					local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
    					local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
    					local projSpeed = (meta.launchVelocity or 100)
    					local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
    					local balloons = plr.Character:GetAttribute('InflatedBalloons')
    					local playerGravity = workspace.Gravity
    					if balloons and balloons > 0 then playerGravity = (workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))) end
    					if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then playerGravity = 6 end
    					if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
    						for _, owl in collectionService:GetTagged('Owl') do if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then playerGravity = 0 end end
    					end
    					local targetpos = getPosition(plr.Character) or plr[TargetPart.Value].Position
    					local newlook = CFrame.new(offsetpos, targetpos) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
    					local v = plr.RootPart.Velocity
    					local newv = v:Lerp(plr.RootPart.Velocity, 0.5)
    					pos = entitylib.character.RootPart.Position
    					local ps = math.min(lplr:GetNetworkPing(), 0.5)
    					if ps > 0.06 then targetpos = targetpos + (v * ps) end
    					local calc = prediction.SolveTrajectory(newlook.p, projSpeed * Prediction.Value, gravity, targetpos, projmeta.projectile == 'telepearl' and Vector3.zero or newv, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
    					if calc then
    						targetinfo.Targets[plr] = os.clock() + 1
    						return {initialVelocity = CFrame.new(newlook.Position, calc).LookVector * (projSpeed * (AutoCharge.Enabled and 1 or projmeta.velocityMultiplier)), positionFrom = offsetpos, deltaT = lifetime, gravitationalAcceleration = gravity, drawDurationSeconds = AutoCharge.Enabled and 5 or projmeta.drawDurationSeconds}
    					end
    				end
    				return nextLaunch(...)
    			end)
    			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
    				local origin, dir = select(2, ...)
    				local plr = entitylib.EntityMouse({Part = 'RootPart', Range = FOV.Value, Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Wallcheck = Targets.Walls.Enabled, Sort = sortmethods[Sort.Value or 'Distance'], Origin = origin})
    				if plr then
    					local calc = prediction.SolveTrajectory(origin, 100, 20, plr[TargetPart.Value].Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
    					if calc then
    						for i, v in debug.getstack(2) do if v == dir then debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector) end end
    					end
    				end
    				return oldd(...)
    			end
    		else
    			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = oldd
    			if launchHook then launchHook(); launchHook = nil end
    		end
    	end
    })
    Targets = ProjectileAimbot:CreateTargets({Players = true, Walls = true})
    TargetPart = ProjectileAimbot:CreateDropdown({Name = 'Part', List = {'RootPart', 'Head', 'Dynamic', 'Closest'}})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    Sort = ProjectileAimbot:CreateDropdown({Name = 'Target Mode', List = methods, Default = 'Distance'})
    Prediction = ProjectileAimbot:CreateSlider({Name = 'Prediction', Min = 0.1, Max = 2, Default = 1, Decimal = 10})
    FOV = ProjectileAimbot:CreateSlider({Name = 'FOV', Min = 1, Max = 1000, Default = 1000})
    AutoCharge = ProjectileAimbot:CreateToggle({Name = 'Auto Charge', Default = true})
    OtherProjectiles = ProjectileAimbot:CreateToggle({Name = 'Other Projectiles', Default = true, Function = function(call) if Blacklist and Blacklist.Object then Blacklist.Object.Visible = call end end})
    Blacklist = ProjectileAimbot:CreateTextList({Name = 'Blacklist', Default = {'gloop', 'telepearl'}, Darker = true, Placeholder = 'projectile'})
end)
run(function()
    local ProjectileAura, FireRate, Targets, Range, Sort, List
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = { InvokeServer = function(self, ...) end }
    local projectileCooldown, FireDelays = 0, {}
    task.spawn(function() projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance end)
    local function getAmmo(check)
    	for _, item in store.inventory.inventory.items do
    		if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then return item.itemType end
    	end
    	return nil
    end
    local function getProjectiles()
    	local items = {}
    	for _, item in store.inventory.inventory.items do
    		local proj = bedwars.ItemMeta[item.itemType].projectileSource
    		local ammo = proj and getAmmo(proj)
    		if ammo and table.find(List.ListEnabled, ammo) then table.insert(items, {item, ammo, proj.projectileType(ammo), proj}) end
    	end
    	return items
    end
    ProjectileAura = vape.Categories.Blatant:CreateModule({
    	Name = 'Projectile Aura',
    	Function = function(callback)
    		if callback then
    			repeat
    				if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
    					local ent = entitylib.EntityPosition({Part = 'RootPart', Range = Range.Value, Sort = sortmethods[Sort.Value], Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Wallcheck = Targets.Walls.Enabled})
    					if ent then
    						local pos = entitylib.character.RootPart.Position
    						for _, data in getProjectiles() do
    							local item, ammo, projectile, itemMeta = unpack(data)
    							if (FireDelays[item.itemType] or 0) < os.clock() then
    								rayCheck.FilterDescendantsInstances = { workspace.Map }
    								local meta = bedwars.ProjectileMeta[projectile]
    								local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
    								local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position + (ent.Humanoid.MoveDirection or Vector3.zero), ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight + 2, ent.Jumping and 42.6 or nil, rayCheck)
    								if calc then
    									targetinfo.Targets[ent] = os.clock() + 1
    									local switched = switchItem(item.tool)
    									local v = ent.RootPart.AssemblyLinearVelocity
    									local s = v:Lerp(ent.RootPart.AssemblyLinearVelocity, 0.5)
    									pos = entitylib.character.RootPart.Position
    									local ps = math.min(lplr:GetNetworkPing(), 0.5)
    									local tpos = ent.RootPart.Position
    									if ps > 0.06 then tpos = tpos + (v * ps) end
    									calc = prediction.SolveTrajectory(pos, projSpeed, gravity, tpos, s, workspace.Gravity, ent.HipHeight + 2, ent.Jumping and 42.6 or nil, rayCheck)
    									if not calc then task.wait(); continue end
    									task.spawn(function()
    										local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
    										local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    										projectileCooldown = 9e9
    										local _, res = pcall(function() return projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, { drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false) }, workspace:GetServerTimeNow() - 0.045) end)
    										projectileCooldown = os.clock()
    										if not res then FireDelays[item.itemType] = os.clock() else
    											local shoot = itemMeta.launchSound
    											shoot = shoot and shoot[math.random(1, #shoot)] or nil
    											if shoot then bedwars.SoundManager:playSound(shoot) end
    										end
    									end)
    									FireDelays[item.itemType] = os.clock() + itemMeta.fireDelaySec
    									if switched then
    										repeat task.wait() until os.clock() > projectileCooldown
    										if FireRate.Value > 0 then task.wait(FireRate.Value) end
    									end
    								end
    							end
    						end
    					end
    				end
    				task.wait(0.012)
    			until not ProjectileAura.Enabled
    		end
    	end
    })
    Targets = ProjectileAura:CreateTargets({Players = true, Walls = true})
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do if not table.find(methods, i) then table.insert(methods, i) end end
    Sort = ProjectileAura:CreateDropdown({Name = 'Target Mode', List = methods, Default = 'Distance'})
    List = ProjectileAura:CreateTextList({Name = 'Projectiles', Default = {'arrow', 'snowball'}})
    FireRate = ProjectileAura:CreateSlider({Name = 'Fire Rate', Min = 0, Max = 2, Default = 0.02, Decimal = 100, Suffix = 'seconds'})
    Range = ProjectileAura:CreateSlider({Name = 'Range', Min = 1, Max = 50, Default = 50})
end)
run(function()
    local Speed, Mode, Value, WallCheck, AutoJump, AlwaysJump
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    Speed = vape.Categories.Blatant:CreateModule({
        Name = 'Speed',
        Function = function(callback)
            frictionTable.Speed = callback or nil
            updateVelocity()
            pcall(function() debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier') end)
            if callback then
                Speed:Clean(runService.PreSimulation:Connect(function(dt)
                    bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
                    if entitylib.isAlive then
                        if not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) then
                            bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or Value.Value)
                            if Mode.Value == 'CFrame' then
                                local state = entitylib.character.Humanoid:GetState()
                                if state == Enum.HumanoidStateType.Climbing then return end
                                local root, velo = entitylib.character.RootPart, getSpeed()
                                local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
                                local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
                                if WallCheck.Enabled then
                                    rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                    rayCheck.CollisionGroup = root.CollisionGroup
                                    local ray = workspace:Raycast(root.Position, destination, rayCheck)
                                    if ray then destination = ((ray.Position + ray.Normal) - root.Position) end
                                end
                                root.CFrame += destination
                                root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
                                    entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                end
                            end
                        end
                    end
                end))
            else
                bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
            end
        end
    })
    Mode = Speed:CreateDropdown({Name = 'Method', List = {'Bedwars', 'CFrame'}, Default = 'CFrame'})
    Value = Speed:CreateSlider({Name = 'Speed', Min = 1, Max = 23, Default = 23})
    WallCheck = Speed:CreateToggle({Name = 'Wall Check', Default = true})
    AutoJump = Speed:CreateToggle({Name = 'AutoJump', Function = function(callback) AlwaysJump.Object.Visible = callback end})
    AlwaysJump = Speed:CreateToggle({Name = 'Always Jump', Visible = false, Darker = true})
end)run(function()
    local ArmorHighlight, Boots, Helmet, Chestplate, UseParts
    local Instances, Decoys = {}, {}
    local Properties = {OutlineTransparency = 'Slider', FillTransparency = 'Slider', FillColor = 'ColorSlider', OutlineColor = 'ColorSlider'}
    local function getArmor(v)
        if v:GetAttribute('ArmorSlot') == 0 and Helmet.Enabled then return 'Helmet'
        elseif v:GetAttribute('ArmorSlot') == 1 and Chestplate.Enabled then return 'Chestplate'
        elseif v:GetAttribute('ArmorSlot') == 2 and Boots.Enabled then return 'Boots' end
        return nil
    end
    ArmorHighlight = vape.Categories.Render:CreateModule({
        Name = 'Armor Highlight',
        Function = function(call)
            if call then
                ArmorHighlight:Clean(lplr.CharacterAdded:Connect(function(char)
                    ArmorHighlight:Clean(char.ChildAdded:Connect(function(part)
                        task.wait(1)
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = Instance.new('Part'); v.CanCollide = false
                                for name, prop in getproperties(part:WaitForChild('Handle')) do pcall(function() v[name] = prop end) end
                                v.Anchored = true; part.Handle.Transparency = 1; v.Material = Enum.Material.Neon
                                for _, child in part.Handle:GetChildren() do child.Parent = v end
                                v.Parent = part; table.insert(Decoys, {TP = part.Handle, Main = v})
                            else
                                local highlight = Instance.new('Highlight', part:WaitForChild('Handle'))
                                for i,v in Properties do highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value end
                                table.insert(Instances, highlight)
                            end
                        end
                    end))
                end))
                ArmorHighlight:Clean(runService.PreRender:Connect(function()
                    for _, data in Decoys do
                        if data.Main and data.Main.Parent and data.TP and data.TP.Parent then
                            data.Main.Velocity = Vector3.new(0, 1, 0); data.Main.CFrame = data.TP.CFrame
                        end
                    end
                end))
            else
                for i,v in Instances do v:Destroy() end
                table.clear(Decoys); table.clear(Instances)
            end
        end
    })
    for i,v in Properties do
        local name = i
        Properties[name] = ArmorHighlight['Create'.. v](ArmorHighlight, {
            Name = i, Min = 0, Max = 1, Decimal = 35,
            Function = function(hue, sat, val)
                pcall(function() for _, ins in Instances do ins[name] = sat and Color3.fromHSV(hue, sat, val) or hue end end)
                if sat then for _, ins in Decoys do ins.Main.Color = Color3.fromHSV(hue, sat, val) end end
            end
        })
    end
    Helmet = ArmorHighlight:CreateToggle({Name = 'Helmet', Function = function() if ArmorHighlight.Enabled then ArmorHighlight:Toggle(); ArmorHighlight:Toggle() end end})
    Chestplate = ArmorHighlight:CreateToggle({Name = 'Chestplate', Function = function() if ArmorHighlight.Enabled then ArmorHighlight:Toggle(); ArmorHighlight:Toggle() end end})
    Boots = ArmorHighlight:CreateToggle({Name = 'Boots', Default = true, Function = function() if ArmorHighlight.Enabled then ArmorHighlight:Toggle(); ArmorHighlight:Toggle() end end})
    UseParts = ArmorHighlight:CreateToggle({Name = 'Use Parts', Default = true, Function = function() if ArmorHighlight.Enabled then ArmorHighlight:Toggle(); ArmorHighlight:Toggle() end end})
end)
run(function()
    local BedESP, Reference = nil, {}
    local Folder = Instance.new('Folder'); Folder.Parent = vape.gui
    local function Added(bed)
    	if not BedESP.Enabled then return end
    	local BedFolder = Instance.new('Folder'); BedFolder.Parent = Folder
    	Reference[bed] = BedFolder
    	local parts = bed:GetChildren()
    	table.sort(parts, function(a, b) return a.Name > b.Name end)
    	for _, part in parts do
    		if part:IsA('BasePart') and part.Name ~= 'Blanket' then
    			local handle = Instance.new('BoxHandleAdornment')
    			handle.Size = part.Size + Vector3.new(0.01, 0.01, 0.01)
    			handle.AlwaysOnTop = true; handle.ZIndex = 2; handle.Visible = true; handle.Adornee = part; handle.Color3 = part.Color
    			if part.Name == 'Legs' then
    				handle.Color3 = Color3.fromRGB(167, 112, 64)
    				handle.Size = part.Size + Vector3.new(0.01, -1, 0.01)
    				handle.CFrame = CFrame.new(0, -0.4, 0)
    				handle.ZIndex = 0
    			end
    			handle.Parent = BedFolder
    		end
    	end
    	table.clear(parts)
    end
    BedESP = vape.Categories.Render:CreateModule({
    	Name = 'Bed ESP',
    	Function = function(callback)
    		if callback then
    			BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed) task.delay(0.2, Added, bed) end))
    			BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed) if Reference[bed] then Reference[bed]:Destroy(); Reference[bed] = nil end end))
    			for _, bed in collectionService:GetTagged('bed') do Added(bed) end
    		else
    			Folder:ClearAllChildren(); table.clear(Reference)
    		end
    	end
    })
end)
run(function()
    local HiveESP, Color, Transparency, Scale
    local Folder = Instance.new('Folder'); Folder.Parent = vape.gui
    local Reference, Strings, Updates = {}, {}, {}
    local function Added(ent)
    	local Name = playersService:GetNameFromUserIdAsync(ent:GetAttribute('PlacedByUserId')) or 'Unknown'
    	Strings[ent] = `{Name}'s beehive | %s Bee%s`
    	local nametag = Instance.new('TextLabel')
    	nametag.TextSize = 14 * Scale.Value; nametag.Font = Enum.Font.Arial
    	local format = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
    	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    	nametag.Name = Name; nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7); nametag.AnchorPoint = Vector2.new(0.5, 1)
    	nametag.BackgroundColor3 = Color3.new(); nametag.BackgroundTransparency = 0.5; nametag.BorderSizePixel = 0
    	nametag.Visible = false; nametag.Text = format; nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	nametag.RichText = true; nametag.Parent = Folder
    	Reference[ent] = nametag
    	HiveESP:Clean(ent:GetAttributeChangedSignal('Level'):Connect(function() Updates[ent] = os.clock() + 0.1 end))
    	Updates[ent] = os.clock() + 0.1
    end
    local function Updated(ent)
    	if Reference[ent] then
    		Reference[ent].TextSize = 14 * Scale.Value; Reference[ent].TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value); Reference[ent].BackgroundTransparency = Transparency.Value
    	end
    end
    local function Removing(ent)
    	if Reference[ent] then Reference[ent]:Destroy(); Reference[ent] = nil end
    end
    HiveESP = vape.Categories.Render:CreateModule({
    	Name = 'Beehive ESP',
    	Function = function(call)
    		if call then
    			for _, v in collectionService:GetTagged('beehive') do Added(v) end
    			HiveESP:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(Added))
    			HiveESP:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(Removing))
    			HiveESP:Clean(runService.PreRender:Connect(function()
    				for ent, nametag in Reference do
    					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
    					nametag.Visible = headVis
    					if not headVis then continue end
    					if (Updates[ent] or 0) > os.clock() then
    						nametag.Text = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
    						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    					end
    					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    				end
    			end))
    		else
    			for i in Reference do Removing(i) end
    		end
    	end
    })
    Color = HiveESP:CreateColorSlider({Name = 'Text Color', Function = function(h, s, v) if HiveESP.Enabled then for ent in Reference do Updated(ent) end end end})
    Transparency = HiveESP:CreateSlider({Name = 'Transparency', Function = function() if HiveESP.Enabled then for ent in Reference do Updated(ent) end end end, Default = 0.5, Min = 0, Max = 1, Decimal = 100})
    Scale = HiveESP:CreateSlider({Name = 'Scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10, Function = function() if HiveESP.Enabled then for ent in Reference do Updated(ent) end end end})
end)
run(function()
    local CustomTags, Color, TAG, old, old2, tagRenderConn, tagGuiConn
    local function Color3ToHex(r, g, b) return string.lower(string.format('#%02X%02X%02X', r, g, b)) end
    local function CompleteTagEffect()
    	if not lplr:FindFirstChild('Tags') then return end
    	local tagObj = lplr.Tags:FindFirstChild('0')
    	if not tagObj then return end
    	if not old then old = tagObj.Value; old2 = tagObj:GetAttribute('Text') end
    	local color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	local R = math.floor(color.R * 255); local G = math.floor(color.G * 255); local B = math.floor(color.B * 255)
    	tagObj.Value = string.format("<font color='rgb(%d,%d,%d)'>[%s]</font>", R, G, B, TAG.Value)
    	tagObj:SetAttribute('Text', TAG.Value)
    	lplr:SetAttribute('ClanTag', TAG.Value)
    	if tagRenderConn then tagRenderConn:Disconnect(); tagRenderConn = nil end
    	if tagGuiConn then tagGuiConn:Disconnect(); tagGuiConn = nil end
    	tagGuiConn = lplr.PlayerGui.ChildAdded:Connect(function(child)
    		if child.Name ~= 'TabListScreenGui' or not child:IsA('ScreenGui') then return end
    		tagRenderConn = runService.RenderStepped:Connect(function()
    			local nameToFind = (lplr.DisplayName == '' or lplr.DisplayName == lplr.Name) and lplr.Name or lplr.DisplayName
    			for _, v in ipairs(child:GetDescendants()) do
    				if v:IsA('TextLabel') and string.find(string.lower(v.Text), string.lower(nameToFind)) then
    					v.Text = string.format('<font transparency="0.3" color="%s">[%s]</font> %s', Color3ToHex(R, G, B), TAG.Value, nameToFind)
    				end
    			end
    		end)
    	end)
    end
    local function RemoveTagEffect()
    	if tagRenderConn then tagRenderConn:Disconnect(); tagRenderConn = nil end
    	if tagGuiConn then tagGuiConn:Disconnect(); tagGuiConn = nil end
    	if lplr:FindFirstChild('Tags') then
    		local tagObj = lplr.Tags:FindFirstChild('0')
    		if tagObj then
    			if old then tagObj.Value = old end
    			if old2 then tagObj:SetAttribute('Text', old2) end
    		end
    	end
    	if lplr:GetAttribute('ClanTag') then lplr:SetAttribute('ClanTag', old) end
    	old = nil; old2 = nil
    end
    CustomTags = vape.Categories.Render:CreateModule({Name = 'Custom Tags', Function = function(callback) if callback then CompleteTagEffect() else RemoveTagEffect() end end})
    Color = CustomTags:CreateColorSlider({Name = 'Color', Function = function() if CustomTags.Enabled then CompleteTagEffect() end end})
    TAG = CustomTags:CreateTextBox({Name = 'Tag', Default = 'gg', Function = function() if CustomTags.Enabled then CompleteTagEffect() end end})
end)
run(function()
    local GeneratorESP, Transparency, Scale, Whitelist
    local Whitelisted = { ListEnabled = {}, Object = nil }
    local Folder = Instance.new('Folder'); Folder.Parent = vape.gui
    local Reference, Strings, Cooldown, Updates = {}, {}, {}, {}
    local function getNumber(text)
    	if not text or text == '' then return 0 end
    	local seconds = text:match('%[(%d+)%]')
    	if seconds then return tonumber(seconds) or 0 end
    	local justNumber = text:match('(%d+)')
    	if justNumber then return tonumber(justNumber) or 0 end
    	return 0
    end
    local function Added(ent)
    	local App = ent.RoactTree.TeamOreGeneratorApp
    	local Name = (App:FindFirstChild('GlobalOreGenerator') or App:FindFirstChild('TeamGenMain'))
    	local Countdown = (Name or App):FindFirstChild('Countdown', true)
    	if Name then Name = Name:FindFirstChild('Title') end
    	local TierType = ''
    	if Name then
    		Name = Name.Text; TierType = 'iron'
    	else
    		local Ore = ent:GetAttribute('Id')
    		Ore = Ore:sub(0, #Ore - 2)
    		TierType = (Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore)):lower()
    		Name = Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore) .. ' Generator'
    	end
    	if Whitelist.Enabled and not table.find(Whitelisted.ListEnabled, TierType) then return end
    	Strings[ent] = `{Name} %s%s`
    	local nametag = Instance.new('TextLabel')
    	nametag.TextSize = 14 * Scale.Value; nametag.Font = Enum.Font.Arial
    	local format = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, '')
    	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    	nametag.Name = Name; nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7); nametag.AnchorPoint = Vector2.new(0.5, 1)
    	nametag.BackgroundColor3 = Color3.new(); nametag.BackgroundTransparency = 0.5; nametag.BorderSizePixel = 0
    	nametag.Visible = false; nametag.Text = format; nametag.TextColor3 = Color3.new(1, 1, 1); nametag.RichText = true; nametag.Parent = Folder
    	Reference[ent] = nametag
    	local Update = function() Updates[ent] = os.clock() + 0.1 end
    	GeneratorESP:Clean(ent:GetAttributeChangedSignal('GeneratorLevel'):Connect(Update))
    	GeneratorESP:Clean(ent:GetAttributeChangedSignal('Cooldown'):Connect(Update))
    	if Countdown then
    		Cooldown[ent] = Countdown
    		GeneratorESP:Clean(Countdown:GetPropertyChangedSignal('Text'):Connect(Update))
    	end
    	Update()
    end
    local function Updated(ent)
    	if Reference[ent] then Reference[ent].TextSize = 14 * Scale.Value; Reference[ent].BackgroundTransparency = Transparency.Value end
    end
    local function Removing(ent)
    	if Reference[ent] then Reference[ent]:Destroy(); Reference[ent] = nil end
    end
    GeneratorESP = vape.Categories.Render:CreateModule({
    	Name = 'Generator ESP',
    	Function = function(call)
    		if call then
    			for _, v in collectionService:GetTagged('Generator') do Added(v) end
    			GeneratorESP:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(Added))
    			GeneratorESP:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(Removing))
    			GeneratorESP:Clean(runService.PreRender:Connect(function()
    				for ent, nametag in Reference do
    					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
    					nametag.Visible = headVis
    					if not headVis then continue end
    					if (Updates[ent] or 0) > os.clock() then
    						nametag.Text = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, Cooldown[ent] and  `| {getNumber(Cooldown[ent].Text)}s` or '')
    						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    					end
    					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    				end
    			end))
    		else
    			for i in Reference do Removing(i) end
    		end
    	end
    })
    Transparency = GeneratorESP:CreateSlider({Name = 'Transparency', Function = function() if GeneratorESP.Enabled then for ent in Reference do Updated(ent) end end end, Default = 0.5, Min = 0, Max = 1, Decimal = 100})
    Scale = GeneratorESP:CreateSlider({Name = 'Scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10, Function = function() if GeneratorESP.Enabled then for ent in Reference do Updated(ent) end end end})
    Whitelist = GeneratorESP:CreateToggle({Name = 'Use whitelist', Default = true, Function = function(call) if Whitelisted.Object then Whitelisted.Object.Visible = call end end})
    Whitelisted = GeneratorESP:CreateTextList({Name = 'Generators', Darker = true, Default = {'diamond', 'iron'}})
end)
run(function()
    local Health
    Health = vape.Categories.Render:CreateModule({
    	Name = 'Health',
    	Function = function(callback)
    		if callback then
    			local label = Instance.new('TextLabel')
    			label.Size = UDim2.fromOffset(100, 20); label.Position = UDim2.new(0.5, 6, 0.5, 30); label.BackgroundTransparency = 1; label.AnchorPoint = Vector2.new(0.5, 0)
    			label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health')) .. ' ❤️' or ''
    			label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
    			label.TextSize = 18; label.Font = Enum.Font.Arial; label.Parent = vape.gui
    			Health:Clean(label)
    			Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
    				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health')) .. ' ❤️' or ''
    				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
    			end))
    		end
    	end
    })
end)
run(function()
    local ItemESP, Distance, Transparency, Scale, WhitelistOnly
    local Whitelist = { ListEnabled = {}, Object = nil }
    local Folder = Instance.new('Folder'); Folder.Parent = vape.gui
    local Reference, Strings, Sizes = {}, {}, {}
    local function Added(ent)
    	local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
    	if WhitelistOnly.Enabled and not table.find(Whitelist.ListEnabled, Name:lower()) then return end
    	Strings[ent] = Name .. '%s'
    	if Distance.Enabled then Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent] end
    	local nametag = Instance.new('TextLabel')
    	nametag.TextSize = 14 * Scale.Value; nametag.Font = Enum.Font.Arial
    	local size = getfontsize(removeTags(ent.Name), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    	nametag.Name = ent.Name; nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7); nametag.AnchorPoint = Vector2.new(0.5, 1)
    	nametag.BackgroundColor3 = Color3.new(); nametag.BackgroundTransparency = 0.5; nametag.BorderSizePixel = 0
    	nametag.Visible = false; nametag.Text = string.format(Strings[ent], 'nan', ent:GetAttribute('Amount') >= 2 and ' x' .. tostring(ent:GetAttribute('Amount')) or '')
    	nametag.TextColor3 = Color3.new(1, 1, 1); nametag.RichText = true; nametag.Parent = Folder
    	Reference[ent] = nametag
    end
    local function Updated(ent)
    	if Reference[ent] then Reference[ent].TextSize = 14 * Scale.Value; Reference[ent].BackgroundTransparency = Transparency.Value end
    end
    local function Removing(ent)
    	if Reference[ent] then Reference[ent]:Destroy(); Reference[ent] = nil end
    end
    ItemESP = vape.Categories.Render:CreateModule({
    	Name = 'Item ESP',
    	Function = function(call)
    		if call then
    			ItemESP:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(Added))
    			ItemESP:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(Removing))
    			ItemESP:Clean(runService.PreRender:Connect(function()
    				for ent, nametag in Reference do
    					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
    					nametag.Visible = headVis
    					if not headVis then continue end
    					if Distance.Enabled then
    						local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.Position).Magnitude) or 0
    						if Sizes[ent] ~= mag then
    							nametag.Text = string.format(Strings[ent], mag, ent:GetAttribute('Amount') >= 2 and ' x' .. tostring(ent:GetAttribute('Amount')) or '')
    							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    							nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    							Sizes[ent] = mag
    						end
    					end
    					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    				end
    			end))
    			for _, v in collectionService:GetTagged('ItemDrop') do Added(v) end
    		else
    			for i in Reference do Removing(i) end
    		end
    	end
    })
    Distance = ItemESP:CreateToggle({Name = 'Distance'})
    ItemESP:CreateToggle({Name = 'Group items'})
    Transparency = ItemESP:CreateSlider({Name = 'Transparency', Function = function() if ItemESP.Enabled then for ent in Reference do Updated(ent) end end end, Default = 0.5, Min = 0, Max = 1, Decimal = 100})
    Scale = ItemESP:CreateSlider({Name = 'Scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10, Function = function() if ItemESP.Enabled then for ent in Reference do Updated(ent) end end end})
    WhitelistOnly = ItemESP:CreateToggle({Name = 'Whitelist Only', Function = function(call) if Whitelist.Object then Whitelist.Object.Visible = call; if ItemESP.Enabled then ItemESP:Toggle(); ItemESP:Toggle() end end end})
    Whitelist = ItemESP:CreateTextList({Name = 'Allowed items', Visible = false, Darker = true, Function = function() if ItemESP.Enabled then ItemESP:Toggle(); ItemESP:Toggle() end end})
end)
run(function()
    local NameTags, Targets, Color, Background, DisplayName, Health, Distance, Equipment, Rank, Enchant, DrawingToggle, Scale, FontOption, Teammates, DistanceCheck, DistanceLimit
    local Strings, Sizes, Reference = {}, {}, {}
    local Folder = Instance.new('Folder'); Folder.Parent = vape.gui
    local methodused
    local Added = {
    	Normal = function(ent)
    		if not Targets.Players.Enabled and ent.Player then return end
    		if not Targets.NPCs.Enabled and ent.NPC then return end
    		if Teammates.Enabled and not ent.Targetable and not ent.Friend then return end
    		local nametag = Instance.new('TextLabel')
    		Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
    		if Health.Enabled then
    			local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
    			Strings[ent] = Strings[ent] .. ' <font color="rgb(' .. tostring(math.floor(healthColor.R * 255)) .. ',' .. tostring(math.floor(healthColor.G * 255)) .. ',' .. tostring(math.floor(healthColor.B * 255)) .. ')">' .. math.round(ent.Health) .. '</font>'
    		end
    		if Distance.Enabled then Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> ' .. Strings[ent] end
    		if Equipment.Enabled then
    			for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
    				local Icon = Instance.new('ImageLabel')
    				Icon.Name = v; Icon.Size = UDim2.fromOffset(30, 30); Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
    				Icon.BackgroundTransparency = 1; Icon.Image = ''; Icon.Parent = nametag
    			end
    		end
    		nametag.TextSize = 14 * Scale.Value; nametag.FontFace = FontOption.Value
    		local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    		nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
    		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7); nametag.AnchorPoint = Vector2.new(0.5, 1)
    		nametag.BackgroundColor3 = Color3.new(); nametag.BackgroundTransparency = Background.Value; nametag.BorderSizePixel = 0
    		nametag.Visible = false; nametag.Text = Strings[ent]
    		nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value); nametag.RichText = true; nametag.Parent = Folder
    		task.spawn(function()
    			if Rank.Enabled and ent.Player then
    				local Icon = Instance.new('ImageLabel'); Icon.Name = 'RankIcon'; Icon.Size = UDim2.fromOffset(30, 30); Icon.Position = UDim2.fromOffset(size.X + 10, -4); Icon.BackgroundTransparency = 1; Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image or ''; Icon.Parent = nametag
    			end
    		end)
    		task.spawn(function()
    			if Enchant.Enabled and ent.Player then
    				local Icon = Instance.new('ImageLabel'); Icon.Name = 'EnchantIcon'; Icon.Size = UDim2.fromOffset(30, 30); Icon.Position = UDim2.fromOffset(-30, -4); Icon.BackgroundTransparency = 1; Icon.Image = store.enchants[ent.Player]:async() or ''; Icon.Parent = nametag
    			end
    		end)
    		Reference[ent] = nametag
    	end,
    	Drawing = function(ent)
    		if not Targets.Players.Enabled and ent.Player then return end
    		if not Targets.NPCs.Enabled and ent.NPC then return end
    		if Teammates.Enabled and not ent.Targetable and not ent.Friend then return end
    		local nametag = {}
    		nametag.BG = Drawing.new('Square'); nametag.BG.Filled = true; nametag.BG.Transparency = 1 - Background.Value; nametag.BG.Color = Color3.new(); nametag.BG.ZIndex = 1
    		nametag.Text = Drawing.new('Text'); nametag.Text.Size = 15 * Scale.Value; nametag.Text.Font = 0; nametag.Text.ZIndex = 2
    		Strings[ent] = ent.Player and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
    		if Health.Enabled then Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health) end
    		if Distance.Enabled then Strings[ent] = '[%s] ' .. Strings[ent] end
    		nametag.Text.Text = Strings[ent]
    		nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    		nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
    		Reference[ent] = nametag
    	end,
    }
    local Removed = {
    	Normal = function(ent) local v = Reference[ent]; if v then Reference[ent] = nil; Strings[ent] = nil; Sizes[ent] = nil; v:Destroy() end end,
    	Drawing = function(ent) local v = Reference[ent]; if v then Reference[ent] = nil; Strings[ent] = nil; Sizes[ent] = nil; for _, obj in v do pcall(function() obj.Visible = false; obj:Remove() end) end end end,
    }
    local Updated = {
    	Normal = function(ent)
    		local nametag = Reference[ent]
    		if nametag then
    			Sizes[ent] = nil
    			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
    			if Health.Enabled then
    				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
    				Strings[ent] = Strings[ent] .. ' <font color="rgb(' .. tostring(math.floor(healthColor.R * 255)) .. ',' .. tostring(math.floor(healthColor.G * 255)) .. ',' .. tostring(math.floor(healthColor.B * 255)) .. ')">' .. math.round(ent.Health) .. '</font>'
    			end
    			if Distance.Enabled then Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> ' .. Strings[ent] end
    			if Equipment.Enabled and store.inventories[ent.Player] then
    				local kit = ent.Player:GetAttribute('PlayingAsKit')
    				local inventory = store.inventories[ent.Player]
    				nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
    				nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
    				nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
    				nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
    				nametag.Kit.Image = kit and bedwars.BedwarsKitMeta[kit].renderImage or ''
    			end
    			if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or '' end
    			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7); nametag.Text = Strings[ent]
    		end
    	end,
    	Drawing = function(ent)
    		local nametag = Reference[ent]
    		if nametag then
    			if vape.ThreadFix then setthreadidentity(8) end
    			Sizes[ent] = nil
    			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
    			if Health.Enabled then Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health) end
    			if Distance.Enabled then Strings[ent] = '[%s] ' .. Strings[ent]; nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent] else nametag.Text.Text = Strings[ent] end
    			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
    			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    		end
    	end,
    }
    local ColorFunc = {
    	Normal = function(hue, sat, val) local color = Color3.fromHSV(hue, sat, val); for i, v in Reference do v.TextColor3 = entitylib.getEntityColor(i) or color end end,
    	Drawing = function(hue, sat, val) local color = Color3.fromHSV(hue, sat, val); for i, v in Reference do v.Text.Color = entitylib.getEntityColor(i) or color end end,
    }
    local Loop = {
    	Normal = function()
    		local alive = entitylib.isAlive
    		local localPosition = alive and entitylib.character.RootPart.Position
    		for ent, nametag in Reference do
    			local distance
    			if alive and (DistanceCheck.Enabled or Distance.Enabled) then distance = (localPosition - ent.RootPart.Position).Magnitude end
    			if DistanceCheck.Enabled then
    				distance = distance or math.huge
    				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then nametag.Visible = false; continue end
    			end
    			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
    			nametag.Visible = headVis
    			if not headVis then continue end
    			if Distance.Enabled then
    				local mag = alive and math.floor(distance) or 0
    				if Sizes[ent] ~= mag then
    					nametag.Text = string.format(Strings[ent], mag)
    					local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    					nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7); Sizes[ent] = mag
    				end
    			end
    			nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    		end
    	end,
    	Drawing = function()
    		local alive = entitylib.isAlive
    		local localPosition = alive and entitylib.character.RootPart.Position
    		for ent, nametag in Reference do
    			local distance
    			if alive and (DistanceCheck.Enabled or Distance.Enabled) then distance = (localPosition - ent.RootPart.Position).Magnitude end
    			if DistanceCheck.Enabled then
    				distance = distance or math.huge
    				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then nametag.Text.Visible = false; nametag.BG.Visible = false; continue end
    			end
    			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
    			nametag.Text.Visible = headVis; nametag.BG.Visible = headVis
    			if not headVis then continue end
    			if Distance.Enabled then
    				local mag = alive and math.floor(distance) or 0
    				if Sizes[ent] ~= mag then
    					nametag.Text.Text = string.format(Strings[ent], mag)
    					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7); Sizes[ent] = mag
    				end
    			end
    			nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
    			nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
    		end
    	end,
    }
    NameTags = vape.Categories.Render:CreateModule({
    	Name = 'Name Tags',
    	Function = function(callback)
    		if callback then
    			methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
    			if Removed[methodused] then NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused])) end
    			if Added[methodused] then
    				for _, v in entitylib.List do if Reference[v] then Removed[methodused](v) end; Added[methodused](v) end
    				NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent) if Reference[ent] then Removed[methodused](ent) end; Added[methodused](ent) end))
    			end
    			if Updated[methodused] then NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused])); for _, v in entitylib.List do Updated[methodused](v) end end
    			if ColorFunc[methodused] then NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function() ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value) end)) end
    			if Loop[methodused] then NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused])) end
    		else
    			if Removed[methodused] then for i in Reference do Removed[methodused](i) end end
    		end
    	end
    })
    Targets = NameTags:CreateTargets({Players = true, Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end})
    FontOption = NameTags:CreateFont({Name = 'Font', Blacklist = 'Arial', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end})
    Color = NameTags:CreateColorSlider({Name = 'Player Color', Function = function(h, s, v) if NameTags.Enabled and ColorFunc[methodused] then ColorFunc[methodused](h, s, v) end end})
    Scale = NameTags:CreateSlider({Name = 'Scale', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end, Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
    Background = NameTags:CreateSlider({Name = 'Transparency', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end, Default = 0.5, Min = 0, Max = 1, Decimal = 10})
    Health = NameTags:CreateToggle({Name = 'Health', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end})
    Distance = NameTags:CreateToggle({Name = 'Distance', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end})
    Rank = NameTags:CreateToggle({Name = 'Rank'})
    Enchant = NameTags:CreateToggle({Name = 'Enchant', Default = true})
    Equipment = NameTags:CreateToggle({Name = 'Equipment', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end})
    DisplayName = NameTags:CreateToggle({Name = 'Use Displayname', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end, Default = true})
    Teammates = NameTags:CreateToggle({Name = 'Priority Only', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end, Default = true})
    DrawingToggle = NameTags:CreateToggle({Name = 'Drawing', Function = function() if NameTags.Enabled then NameTags:Toggle(); NameTags:Toggle() end end})
    DistanceCheck = NameTags:CreateToggle({Name = 'Distance Check', Function = function(callback) DistanceLimit.Object.Visible = callback end})
    DistanceLimit = NameTags:CreateTwoSlider({Name = 'Player Distance', Min = 0, Max = 256, DefaultMin = 0, DefaultMax = 64, Darker = true, Visible = false})
end)
run(function()
    local BulletTracers, Material, Lifetime, Curve, Opacity, Thickness, Color, Fade
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    BulletTracers = vape.Categories.Render:CreateModule({
    	Name = 'Projectile Tracers',
    	Function = function(callback)
    		if callback then
    			BulletTracers:Clean(workspace.ChildAdded:Connect(function(projectile)
    				task.delay(0, function()
    					rayCheck.FilterDescendantsInstances = {projectile, lplr.Character}
    					if projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then return end
    					local origin = projectile:GetPivot().Position
    					local velocity = projectile.PrimaryPart and projectile.PrimaryPart.Velocity or Vector3.zero
    					local velocityMagnitude = velocity.Magnitude
    					if velocityMagnitude <= 0 then return end
    					local velocityUnit = velocity / velocityMagnitude
    					local gravity = bedwars.ProjectileMeta[projectile.Name].gravitationalAcceleration
    					local ray = workspace:Raycast(origin, velocityUnit * 2000, rayCheck)
    					local endpoint = ray and ray.Position or (origin + velocityUnit * 2000)
    					local travelTime = (endpoint - origin).Magnitude / velocityMagnitude
    					prediction.SpawnArcTracer(origin, velocityUnit, velocityMagnitude, gravity, travelTime, Curve.Value, {Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value), Transparency = Opacity.Value, Thick = Thickness.Value, Material = Enum.Material[Material.Value], Lifetime = Lifetime.Value, Fade = Fade.Enabled})
    				end)
    			end))
    		end
    	end
    })
    local materials = {'SmoothPlastic'}
    for _, v in Enum.Material:GetEnumItems() do if v.Name ~= 'SmoothPlastic' then table.insert(materials, v.Name) end end
    Material = BulletTracers:CreateDropdown({Name = 'Material', List = materials})
    Color = BulletTracers:CreateColorSlider({Name = 'Tracer Color', DefaultOpacity = 0.5})
    Thickness = BulletTracers:CreateSlider({Name = 'Thickness', Min = 0.01, Max = 1, Default = 0.1, Decimal = 100})
    Curve = BulletTracers:CreateSlider({Name = 'Curveness', Min = 1, Max = 100, Default = 40})
    Opacity = BulletTracers:CreateSlider({Name = 'Opacity', Min = 0, Max = 1, Default = 0, Decimal = 100})
    Lifetime = BulletTracers:CreateSlider({Name = 'Lifetime', Min = 0, Max = 5, Decimal = 100, Default = 2, Suffix = 'secs'})
    Fade = BulletTracers:CreateToggle({Name = 'Fade', Default = true})
end)
run(function()
    local AutoToxic, GG, Toggles, Lists, said, dead = nil, nil, {}, {}, {}, {}
    local function sendMessage(name, obj, default)
        local tab = Lists[name].ListEnabled
        local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
        if not custommsg then return end
        if #tab > 1 and custommsg == said[name] then
            repeat task.wait(); custommsg = tab[math.random(1, #tab)] until custommsg ~= said[name]
        end
        said[name] = custommsg
        custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
        else
            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
        end
    end
    AutoToxic = vape.Categories.Utility:CreateModule({
        Name = 'Auto Toxic',
        Function = function(callback)
            if callback then
                AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
                    if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
                        sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
                    elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
                        local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
                        sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
                    end
                end))
                AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                    if deathTable.finalKill then
                        local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
                        local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
                        if not killed or not killer then return end
                        if killed == lplr then
                            if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
                                dead = true
                                sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
                            end
                        elseif killer == lplr and Toggles.Kill.Enabled then
                            sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
                        end
                    end
                end))
                AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
                    if GG.Enabled then
                        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg') else replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All') end
                    end
                    local myTeam = bedwars.Store:getState().Game.myTeam
                    if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
                        if Toggles.Win.Enabled then sendMessage('Win', nil, 'yall garbage') end
                    end
                end))
            end
        end
    })
    GG = AutoToxic:CreateToggle({Name = 'AutoGG', Default = true})
    for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
        Toggles[v] = AutoToxic:CreateToggle({Name = v..' ', Function = function(callback) if Lists[v] then Lists[v].Object.Visible = callback end end})
        Lists[v] = AutoToxic:CreateTextList({Name = v, Darker = true, Visible = false})
    end
end)
run(function()
    local FakeLag, TransmissionOffset, Mode, Delay
    local rng
    FakeLag = vape.Categories.Utility:CreateModule({
        Name = 'Fake Lag',
        Function = function(callback)
            if callback then
                rng = Random.new()
                local clock, restore, after = os.clock(), os.clock(), 0
                repeat
                    local ms = Delay.Value / 1000
                    if Mode.Value == 'Dynamic' then
                        if (os.clock() - clock) >= ms or restore > os.clock() then
                            if clock ~= 9e9 then restore = os.clock() + TransmissionOffset.Value; clock = 9e9 end
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        else
                            if clock == 9e9 then clock = os.clock(); restore = 0 end
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        end
                    elseif Mode.Value == 'Repel' then
                        if store.update > os.clock() then
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                            setfflag('S2PhysicsSenderRate', '0')
                            setfflag('DataSenderRate', '-1')
                            task.wait(rng:NextNumber(70, 150) / 1000)
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                            setfflag('DataSenderRate', '60')
                            setfflag('S2PhysicsSenderRate', '15')
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                            store.update = 0
                            num = rng:NextNumber()
                        end
                        if os.clock() > after then
                            num = rng:NextNumber()
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                        end
                    elseif Mode.Value == 'Latency' then
                        setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        task.wait(Delay.Value / 1500)
                        setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        task.wait(ms)
                    end
                    runService.PreRender:Wait()
                until not FakeLag.Enabled
            else
                setfflag('DataSenderRate', '60')
                setfflag('PhysicsSenderMaxBandwidthBps', '38760')
            end
        end
    })
    getgenv().FakeLag = FakeLag
    TransmissionOffset = FakeLag:CreateSlider({Name = 'Transmission Offset', Min = 1, Max = 10, Default = 3, Decimal = 5, Darker = true})
    Mode = FakeLag:CreateDropdown({Name = 'Mode', List = { 'Dynamic', 'Repel', 'Latency' }, Default = 'Dynamic', Function = function(val) TransmissionOffset.Object.Visible = val == 'Dynamic'; setfflag('PhysicsSenderMaxBandwidthBps', '38760') end})
    Delay = FakeLag:CreateSlider({Name = 'Delay', Suffix = function() return 'ms' end, Min = 1, Max = 500, Default = 100})
end)
run(function()
    TrapDisabler = vape.Categories.Utility:CreateModule({
        Name = 'TrapDisabler',
        Tooltip = 'Disables Snap Traps'
    })
end)
run(function()
    vape.Categories.World:CreateModule({
        Name = 'Anti-AFK',
        Function = function(callback)
            if callback then
                for _, v in getconnections(lplr.Idled) do v:Disconnect() end
                for _, v in getconnections(runService.Heartbeat) do
                    if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then v:Disconnect() end
                end
                bedwars.Client:Get(remotes.AfkStatus):SendToServer({afk = false})
            end
        end
    })
end)
run(function()
    local AutoBuy, Sword, Armor, Upgrades, TierCheck, BedwarsCheck, GUI, SmartCheck
    local Custom, CustomPost, UpgradeToggles, Functions, id = {}, {}, {}, {}, nil
    local Callbacks = {Custom, Functions, CustomPost}
    local npctick = os.clock()
    local swords = {'wood_sword', 'stone_sword', 'iron_sword', 'diamond_sword', 'emerald_sword'}
    local armors = {'none', 'leather_chestplate', 'iron_chestplate', 'diamond_chestplate', 'emerald_chestplate'}
    local axes = {'none', 'wood_axe', 'stone_axe', 'iron_axe', 'diamond_axe'}
    local pickaxes = {'none', 'wood_pickaxe', 'stone_pickaxe', 'iron_pickaxe', 'diamond_pickaxe'}
    local function getShopNPC()
        local shop, items, upgrades, newid = nil, false, false, nil
        if entitylib.isAlive then
            local localPosition = entitylib.character.RootPart.Position
            for _, v in store.shop do
                if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                    shop = v.Upgrades or v.Shop or nil; upgrades = upgrades or v.Upgrades; items = items or v.Shop; newid = v.Shop and v.Id or newid
                end
            end
        end
        return shop, items, upgrades, newid
    end
    local function canBuy(item, currencytable, amount)
        amount = amount or 1
        if not currencytable[item.currency] then
            local currency = getItem(item.currency)
            currencytable[item.currency] = currency and currency.amount or 0
        end
        if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
        if item.lockedByForge or item.disabled then return false end
        if item.require and item.require.teamUpgrade then
            if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then return false end
        end
        return currencytable[item.currency] >= (item.price * amount)
    end
    local function buyItem(item, currencytable)
        if not id then return end
        notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
        bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({shopItem = item, shopId = id}):andThen(function(suc)
            if suc then
                bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
                bedwars.Store:dispatch({type = 'BedwarsAddItemPurchased', itemType = item.itemType})
                bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
            end
        end)
        currencytable[item.currency] -= item.price
    end
    local function buyUpgrade(upgradeType, currencytable)
        if not Upgrades.Enabled then return end
        local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
        local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
        local currentTier = (currentUpgrades[upgradeType] or 0) + 1
        local bought = false
        for i = currentTier, #upgrade.tiers do
            local tier = upgrade.tiers[i]
            if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
            if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
                notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
                bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
                currencytable.diamond -= tier.cost
                bought = true
            else break end
        end
        return bought
    end
    local function buyTool(tool, tools, currencytable)
        local bought, buyable = false
        tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
        for i = tool, #tools do
            local v = bedwars.Shop.getShopItem(tools[i], lplr)
            if canBuy(v, currencytable) then
                if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
                    if Armor.Enabled then
                        local currentarmor = store.inventory.inventory.armor[2]
                        currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
                        if (table.find(armors, currentarmor) or 3) < 3 then break end
                    end
                    if Sword.Enabled then
                        if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
                    end
                end
                bought = true; buyable = v
            end
            if TierCheck.Enabled and v.nextTier then break end
        end
        if buyable then buyItem(buyable, currencytable) end
        return bought
    end
    AutoBuy = vape.Categories.Inventory:CreateModule({
        Name = 'Auto Buy',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.queueType ~= 'bedwars_test'
                if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
                local lastupgrades
                AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function() if (npctick - os.clock()) > 1 then npctick = os.clock() end end))
                repeat
                    local npc, shop, upgrades, newid = getShopNPC()
                    id = newid
                    if GUI.Enabled and not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then npc = nil end
                    if npc and lastupgrades ~= upgrades then if (npctick - os.clock()) > 1 then npctick = os.clock() end; lastupgrades = upgrades end
                    if npc and npctick <= os.clock() and store.matchState ~= 2 and store.shopLoaded then
                        local currencytable = {}; local waitcheck
                        for _, tab in Callbacks do for _, cb in tab do if cb(currencytable, shop, upgrades) then waitcheck = true end end end
                        npctick = os.clock() + (waitcheck and 0.4 or math.huge)
                    end
                    task.wait(0.1)
                until not AutoBuy.Enabled
            else
                npctick = os.clock()
            end
        end
    })
    Sword = AutoBuy:CreateToggle({Name = 'Buy Sword', Function = function(callback)
            npctick = os.clock()
            Functions[2] = callback and function(currencytable, shop)
                if not shop then return end
                if store.equippedKit == 'dasher' then swords = {'wood_dao', 'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} elseif store.equippedKit == 'ice_queen' then swords[5] = 'ice_sword' elseif store.equippedKit == 'ember' then swords[5] = 'infernal_saber' elseif store.equippedKit == 'lumen' then swords[5] = 'light_sword' end
                return buyTool(store.tools.sword, swords, currencytable)
            end or nil
        end
    })
    Armor = AutoBuy:CreateToggle({Name = 'Buy Armor', Default = true, Function = function(callback)
            npctick = os.clock()
            Functions[1] = callback and function(currencytable, shop)
                if not shop then return end
                local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
                return buyTool({itemType = currentarmor and currentarmor.itemType or 'none'}, armors, currencytable)
            end or nil
        end
    })
    AutoBuy:CreateToggle({Name = 'Buy Axe', Function = function(callback) npctick = os.clock(); Functions[3] = callback and function(currencytable, shop) if not shop then return end; return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable) end or nil end})
    AutoBuy:CreateToggle({Name = 'Buy Pickaxe', Function = function(callback) npctick = os.clock(); Functions[4] = callback and function(currencytable, shop) if not shop then return end; return buyTool(store.tools.stone, pickaxes, currencytable) end or nil end})
    Upgrades = AutoBuy:CreateToggle({Name = 'Buy Upgrades', Default = true, Function = function(callback) for _, v in UpgradeToggles do v.Object.Visible = callback end end})
    local count = 0
    for i, v in bedwars.TeamUpgradeMeta do
        local toggleCount = count
        table.insert(UpgradeToggles, AutoBuy:CreateToggle({
            Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name), Darker = true, Default = (i == 'ARMOR' or i == 'DAMAGE'),
            Function = function(callback)
                npctick = os.clock()
                Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
                    if not upgrades or (v.disabledInQueue and table.find(v.disabledInQueue, store.queueType)) then return end
                    return buyUpgrade(i, currencytable)
                end or nil
            end
        }))
        count += 1
    end
    TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
    BedwarsCheck = AutoBuy:CreateToggle({Name = 'Only Bedwars', Default = true, Function = function() if AutoBuy.Enabled then AutoBuy:Toggle(); AutoBuy:Toggle() end end})
    GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
    SmartCheck = AutoBuy:CreateToggle({Name = 'Smart check', Default = true})
    AutoBuy:CreateTextList({Name = 'Item', Placeholder = 'priority/item/amount/after', Function = function(list)
            table.clear(Custom); table.clear(CustomPost)
            for _, entry in list do
                local tab = entry:split('/')
                local ind = tonumber(tab[1])
                if ind then
                    (tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
                        if not shop then return end
                        local v = bedwars.Shop.getShopItem(tab[2], lplr)
                        if v then
                            local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
                            item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
                            if item > 0 and canBuy(v, currencytable, item) then for _ = 1, item do buyItem(v, currencytable) end; return true end
                        end
                    end
                end
            end
        end
    })
end)
run(function()
    local AutoConsume, Health, SpeedPotion, Apple, ShieldPotion
    local function consumeCheck(attribute)
        if entitylib.isAlive then
            if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
                local speedpotion = getItem('speed_potion')
                if speedpotion and not lplr.Character:GetAttribute('StatusEffect_speed') then for _ = 1, 4 do if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end end end
            end
            if Apple.Enabled and (not attribute or attribute:find('Health')) then
                if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
                    local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
                    if apple then bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({item = apple.tool}) end
                end
            end
            if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
                if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
                    local shield = getItem('big_shield') or getItem('mini_shield')
                    if shield then bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({item = shield.tool}) end
                end
            end
        end
    end
    AutoConsume = vape.Categories.Inventory:CreateModule({
        Name = 'Auto Consume',
        Function = function(callback)
            if callback then
                AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
                AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute) if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then consumeCheck(attribute) end end))
                consumeCheck()
            end
        end
    })
    Health = AutoConsume:CreateSlider({Name = 'Health Percent', Min = 1, Max = 99, Default = 70, Suffix = '%'})
    SpeedPotion = AutoConsume:CreateToggle({Name = 'Speed Potions', Default = true})
    Apple = AutoConsume:CreateToggle({Name = 'Apple', Default = true})
    ShieldPotion = AutoConsume:CreateToggle({Name = 'Shield Potions', Default = true})
end)
run(function()
    vape.Legit:CreateModule({
        Name = 'Hit Fix',
        Function = function(callback)
            debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
            debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
        end
    })
end)
run(function()
    local TexturePacks, Pack
    TexturePacks = vape.Legit:CreateModule({
    	Name = 'Texture Pack',
    	Function = function(callback)
    		if callback then
    			loadstring(game:HttpGet('https://raw.githubusercontent.com/MaxlaserTech/TexturePacks/main/' .. Pack.Value .. '.lua'), Pack.Value)()
    		else
    			if getgenv().texturepack then getgenv().texturepack:Disconnect(); getgenv().texturepack = nil end
    		end
    	end
    })
    Pack = TexturePacks:CreateDropdown({Name = 'Pack', List = {'Acidic', 'Devourer', 'Enlightened', 'FatCat', 'Fury', 'Makima', 'Marin-Kitsawaba', 'Moon4Real', 'Nebula', 'Onyx', 'Prime', 'Simply', 'Vile', 'VioletsDreams', 'Wichtiger'}})
end)
