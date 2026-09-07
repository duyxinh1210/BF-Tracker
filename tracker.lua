--========================================================
-- BLOX FRUITS TRACKER V11.2
-- CONTINUOUS / AUTO-EXEC SAFE
--
-- Local replicated values : refresh 1s
-- Full inventory remote   : refresh 15s
-- Initial remote failure  : retry 1s
--
-- Output:
-- getgenv().BF_TRACKER_DATA
--========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------
-- SETTINGS
----------------------------------------------------------

local LOCAL_INTERVAL = 1
local FULL_INTERVAL = 15
local INITIAL_RETRY = 1


----------------------------------------------------------
-- INSTANCE GUARD
--
-- Nếu chạy lại script, loop cũ tự dừng.
----------------------------------------------------------

local ENV = getgenv and getgenv() or _G

ENV.BF_TRACKER_INSTANCE =
	(ENV.BF_TRACKER_INSTANCE or 0) + 1

local RUN_ID =
	ENV.BF_TRACKER_INSTANCE


----------------------------------------------------------
-- HELPERS
----------------------------------------------------------

local function lower(v)
	return string.lower(tostring(v or ""))
end


local function contains(a, b)

	return string.find(
		lower(a),
		lower(b),
		1,
		true
	) ~= nil

end


local function countTable(t)

	local n = 0

	for _ in pairs(t or {}) do
		n += 1
	end

	return n

end


local function valueOf(parent, name)

	if not parent then
		return nil
	end

	local obj =
		parent:FindFirstChild(name)

	if
		obj
		and
		obj:IsA("ValueBase")
	then

		return obj.Value

	end

	return nil

end


----------------------------------------------------------
-- WAIT LOCAL PLAYER
--
-- FIX lỗi auto-exec của V11.1
----------------------------------------------------------

print("[BF V11.2] Waiting LocalPlayer...")

local Player =
	Players.LocalPlayer

while not Player do

	task.wait(0.1)

	Player =
		Players.LocalPlayer

end


print(
	"[BF V11.2] LocalPlayer:",
	Player.Name
)


----------------------------------------------------------
-- WAIT PLAYER DATA
----------------------------------------------------------

local Data =
	Player:FindFirstChild("Data")

while not Data do

	task.wait(0.1)

	Data =
		Player:FindFirstChild("Data")

end


print("[BF V11.2] Player.Data ready")


----------------------------------------------------------
-- WAIT RACE
----------------------------------------------------------

local Race =
	Data:FindFirstChild("Race")

while not Race do

	task.wait(0.1)

	Race =
		Data:FindFirstChild("Race")

end


print(
	"[BF V11.2] Race:",
	Race.Value
)


----------------------------------------------------------
-- WAIT REMOTE
----------------------------------------------------------

local Modules =
	ReplicatedStorage:
	WaitForChild("Modules")

local Net =
	Modules:
	WaitForChild("Net")

local GetAll =
	Net:
	WaitForChild(
		"RF/GetAllItemValues"
	)


----------------------------------------------------------
-- INVENTORY CONFIG
----------------------------------------------------------

local InventoryConfig =
	require(
		ReplicatedStorage
		:WaitForChild("ItemConfig")
		:WaitForChild("Data")
		:WaitForChild("Inventory")
	)


print("[BF V11.2] Remote + Config ready")


----------------------------------------------------------
-- META
----------------------------------------------------------

local function getMeta(id)

	local cfg =
		InventoryConfig[id]

	if typeof(cfg) ~= "table" then

		return {
			ItemId = id,
			Name = "Unknown #" .. tostring(id),
			Kind = "Unknown",
			Brackets = "",
			Groups = "",
			Actions = "",
			DisplayCategory = ""
		}

	end


	local raw =
		tostring(cfg.Id or "")


	local name =
		raw:gsub(
			"%s*%[[^%]]+%]%s*$",
			""
		)


	name =
		name:gsub(
			"^%-%-%s*",
			""
		)


	if name == "" then

		name =
			tostring(
				cfg["Stack Display Name"]
				or
				("Unknown #" .. id)
			)

	end


	local kind =
		raw:match(
			"%[([^%-]+)%-%d+%]"
		)
		or
		"Unknown"


	return {

		ItemId =
			id,

		Name =
			name,

		Kind =
			kind,

		Raw =
			raw,

		Brackets =
			cfg.Brackets or "",

		Groups =
			cfg.Groups or "",

		Actions =
			cfg.Actions or "",

		DisplayCategory =
			cfg[
				"Stack Display Category"
			]
			or ""

	}

end


----------------------------------------------------------
-- GROUP GetAllItemValues
----------------------------------------------------------

local function groupRecords(raw)

	local grouped = {}


	for _, row in pairs(raw) do

		if
			typeof(row) == "table"
			and
			typeof(row.ItemId) == "number"
			and
			typeof(row.Key) == "string"
		then

			local id =
				row.ItemId


			grouped[id] =
				grouped[id]
				or
				{
					ItemId = id,
					Properties = {}
				}


			local props =
				grouped[id].Properties


			local key =
				row.Key


			local value =
				row.Value


			if typeof(value) == "boolean" then

				if value == true then

					props[key] = true

				elseif props[key] == nil then

					props[key] = false

				end


			elseif
				typeof(value) == "number"
				and
				(
					key == "Quantity"
					or
					key == "Mastery"
					or
					key == "Evolution"
				)
			then

				if
					props[key] == nil
					or
					value > props[key]
				then

					props[key] =
						value

				end


			elseif props[key] == nil then

				props[key] =
					value

			end

		end

	end


	return grouped

end


----------------------------------------------------------
-- OWNERSHIP
----------------------------------------------------------

local function strictOwned(item)

	local p =
		item.Properties


	return
		p.IsOwned == true
		or
		(
			typeof(p.Quantity) == "number"
			and
			p.Quantity > 0
		)

end


----------------------------------------------------------
-- CATEGORY
----------------------------------------------------------

local function categoryOf(item, meta)

	local p =
		item.Properties

	local kind =
		lower(meta.Kind)

	local bracket =
		lower(meta.Brackets)

	local display =
		lower(meta.DisplayCategory)

	local groups =
		lower(meta.Groups)

	local actions =
		lower(meta.Actions)


	------------------------------------------------------
	-- ACCESSORY
	------------------------------------------------------

	if
		p.AccessoryType ~= nil
		or
		p.AccessoryModifiers ~= nil
		or
		contains(kind, "accessory")
		or
		contains(bracket, "accessor")
	then

		return "Accessories"

	end


	------------------------------------------------------
	-- MATERIAL
	------------------------------------------------------

	if
		kind == "material"
		or
		contains(bracket, "material")
		or
		contains(display, "material")
	then

		return "Materials"

	end


	------------------------------------------------------
	-- SWORD
	------------------------------------------------------

	if
		contains(bracket, "sword")
		or
		contains(display, "sword")
	then

		return "Swords"

	end


	------------------------------------------------------
	-- GUN
	------------------------------------------------------

	if
		contains(bracket, "gun")
		or
		contains(display, "gun")
	then

		return "Guns"

	end


	------------------------------------------------------
	-- STORED FRUIT
	------------------------------------------------------

	if strictOwned(item) then

		if
			kind == "physicalmoveset"
			or
			kind == "moveset"
		then

			local fruitHint =
				contains(bracket, "fruit")
				or
				contains(display, "fruit")
				or
				contains(actions, "fruit")


			local fruitName =
				string.find(
					meta.Name,
					"-",
					1,
					true
				) ~= nil


			if fruitHint or fruitName then

				return "StoredFruits"

			end

		end

	end


	------------------------------------------------------
	-- MELEE
	------------------------------------------------------

	if
		kind == "moveset"
		and
		contains(bracket, "gear")
		and
		contains(groups, "backpack")
	then

		return "Melee"

	end


	return nil

end


----------------------------------------------------------
-- CLEAN ITEM
----------------------------------------------------------

local function cleanItem(item, meta)

	local p =
		item.Properties


	return {

		ItemId =
			item.ItemId,

		Name =
			meta.Name,

		Quantity =
			p.Quantity,

		Mastery =
			p.Mastery,

		IsOwned =
			p.IsOwned == true,

		IsEquipped =
			p.IsEquipped == true,

		AccessoryType =
			p.AccessoryType

	}

end


----------------------------------------------------------
-- FRUIT COMPARE
----------------------------------------------------------

local function sameFruit(a, b)

	a = lower(a)
	b = lower(b)


	if a == b then
		return true
	end


	local aa =
		a:match("^([^%-]+)")


	local bb =
		b:match("^([^%-]+)")


	return
		aa
		and
		bb
		and
		aa == bb

end


----------------------------------------------------------
-- FIND CURRENT RACE ITEM
----------------------------------------------------------

local function findRaceItem(grouped)

	for id, item in pairs(grouped) do

		local meta =
			getMeta(id)


		if
			lower(meta.Kind) == "race"
			and
			lower(meta.Name)
				==
				lower(Race.Value)
		then

			return item, meta

		end

	end


	return nil, nil

end


----------------------------------------------------------
-- STATE
----------------------------------------------------------

local State = {

	Version = "11.2",

	Ready = false,

	Status = "STARTING",

	Revision = 0,

	Account = {},

	Race = {},

	Inventory = {

		Melee = {},
		Swords = {},
		Guns = {},
		StoredFruits = {},
		Accessories = {},
		Materials = {}

	},

	CurrentFruit = nil,

	Equipped = {},

	Stats = {

		FullRefreshes = 0,

		LastFullDuration = nil,

		LastFullUpdate = nil,

		LastLocalUpdate = nil,

		LastError = nil

	}

}


ENV.BF_TRACKER_DATA =
	State

_G.BF_TRACKER_DATA =
	State


----------------------------------------------------------
-- FAST LOCAL REFRESH
--
-- Không remote.
-- Chạy mỗi 1 giây.
----------------------------------------------------------

local function refreshLocal()

	State.Account.Username =
		Player.Name

	State.Account.DisplayName =
		Player.DisplayName

	State.Account.UserId =
		Player.UserId

	State.Account.Level =
		valueOf(Data, "Level")

	State.Account.Beli =
		valueOf(Data, "Beli")

	State.Account.Fragments =
		valueOf(Data, "Fragments")

	State.Account.Exp =
		valueOf(Data, "Exp")

	State.Account.DevilFruit =
		valueOf(
			Data,
			"DevilFruit"
		)

	State.Account.PlaceId =
		game.PlaceId

	State.Account.JobId =
		game.JobId


	------------------------------------------------------
	-- BOUNTY
	------------------------------------------------------

	local leaderstats =
		Player:FindFirstChild(
			"leaderstats"
		)


	if leaderstats then

		State.Account.BountyHonor =
			valueOf(
				leaderstats,
				"Bounty/Honor"
			)

	end


	------------------------------------------------------
	-- RACE LOCAL VALUES
	------------------------------------------------------

	State.Race.Name =
		Race.Value

	State.Race.A =
		valueOf(Race, "A")

	State.Race.B =
		valueOf(Race, "B")

	State.Race.C =
		valueOf(Race, "C")


	------------------------------------------------------
	-- Nếu đã biết Version từ full scan
	-- thì Tier update ngay theo C
	------------------------------------------------------

	if State.Race.Version == 4 then

		State.Race.Tier =
			State.Race.C


		State.Race.Display =
			string.format(
				"%s V4 T%s",
				State.Race.Name,
				tostring(
					State.Race.Tier
					or "?"
				)
			)

	elseif State.Race.Version then

		State.Race.Tier =
			nil


		State.Race.Display =
			string.format(
				"%s V%s",
				State.Race.Name,
				tostring(
					State.Race.Version
				)
			)

	end


	State.Stats.LastLocalUpdate =
		os.time()

end


----------------------------------------------------------
-- FULL REMOTE REFRESH
----------------------------------------------------------

local function refreshFull()

	local started =
		os.clock()


	State.Status =
		"REFRESHING"


	local ok, raw =
		pcall(function()

			return
				GetAll:
				InvokeServer()

		end)


	if
		not ok
		or
		typeof(raw) ~= "table"
		or
		next(raw) == nil
	then

		State.Status =
			State.Ready
			and
			"READY"
			or
			"WAITING_DATA"


		State.Stats.LastError =
			tostring(raw)


		return false

	end


	------------------------------------------------------
	-- GROUP
	------------------------------------------------------

	local grouped =
		groupRecords(raw)


	------------------------------------------------------
	-- CURRENT RACE
	------------------------------------------------------

	local raceItem =
		findRaceItem(grouped)


	if
		not raceItem
		or
		typeof(
			raceItem
			.Properties
			.Evolution
		) ~= "number"
	then

		State.Status =
			State.Ready
			and
			"READY"
			or
			"WAITING_RACE"


		State.Stats.LastError =
			"Race Evolution not ready"


		return false

	end


	local evolution =
		raceItem
		.Properties
		.Evolution


	------------------------------------------------------
	-- INVENTORY
	------------------------------------------------------

	local Inventory = {

		Melee = {},

		Swords = {},

		Guns = {},

		StoredFruits = {},

		Accessories = {},

		Materials = {}

	}


	local CurrentFruit =
		nil


	local currentFruitName =
		tostring(
			valueOf(
				Data,
				"DevilFruit"
			)
			or
			""
		)


	for id, item in pairs(grouped) do

		local meta =
			getMeta(id)


		--------------------------------------------------
		-- CURRENT FRUIT
		--------------------------------------------------

		if
			sameFruit(
				meta.Name,
				currentFruitName
			)
			and
			(
				item.Properties.Mastery ~= nil
				or
				item.Properties.IsEquipped == true
			)
		then

			local candidate =
				cleanItem(
					item,
					meta
				)


			if
				not CurrentFruit
				or
				(
					candidate.IsEquipped
					and
					not CurrentFruit.IsEquipped
				)
				or
				(
					(candidate.Mastery or 0)
					>
					(CurrentFruit.Mastery or 0)
				)
			then

				CurrentFruit =
					candidate

			end

		end


		--------------------------------------------------
		-- OWNED INVENTORY
		--------------------------------------------------

		if strictOwned(item) then

			local category =
				categoryOf(
					item,
					meta
				)


			if
				category
				and
				Inventory[category]
			then

				table.insert(
					Inventory[category],
					cleanItem(
						item,
						meta
					)
				)

			end

		end

	end


	------------------------------------------------------
	-- SORT
	------------------------------------------------------

	for _, list in pairs(Inventory) do

		table.sort(
			list,
			function(a, b)

				return
					lower(a.Name)
					<
					lower(b.Name)

			end
		)

	end


	------------------------------------------------------
	-- EQUIPPED
	------------------------------------------------------

	local function findEquipped(list)

		for _, item in ipairs(list) do

			if item.IsEquipped then
				return item
			end

		end

		return nil

	end


	------------------------------------------------------
	-- APPLY STATE
	------------------------------------------------------

	State.Inventory =
		Inventory


	State.CurrentFruit =
		CurrentFruit


	State.Equipped = {

		Melee =
			findEquipped(
				Inventory.Melee
			),

		Sword =
			findEquipped(
				Inventory.Swords
			),

		Gun =
			findEquipped(
				Inventory.Guns
			),

		Fruit =
			CurrentFruit

	}


	State.Race.Name =
		Race.Value


	State.Race.Version =
		evolution


	State.Race.Evolution =
		evolution


	State.Race.A =
		valueOf(Race, "A")


	State.Race.B =
		valueOf(Race, "B")


	State.Race.C =
		valueOf(Race, "C")


	if evolution == 4 then

		State.Race.Tier =
			State.Race.C


		State.Race.Display =
			string.format(
				"%s V4 T%s",
				Race.Value,
				tostring(
					State.Race.Tier
					or "?"
				)
			)

	else

		State.Race.Tier =
			nil


		State.Race.Display =
			string.format(
				"%s V%s",
				Race.Value,
				tostring(
					evolution
				)
			)

	end


	State.Ready =
		true


	State.Status =
		"READY"


	State.Revision += 1


	State.Stats.FullRefreshes += 1


	State.Stats.RawRecords =
		countTable(raw)


	State.Stats.UniqueItemIds =
		countTable(grouped)


	State.Stats.LastFullDuration =
		os.clock() - started


	State.Stats.LastFullUpdate =
		os.time()


	State.Stats.LastError =
		nil


	------------------------------------------------------
	-- OUTPUT
	------------------------------------------------------

	print(
		string.format(
			"[BF V11.2] UPDATE #%d | %.3fs | %s | Fruits:%d Sword:%d Melee:%d",
			State.Revision,
			State.Stats.LastFullDuration,
			State.Race.Display
				or "?",
			#Inventory.StoredFruits,
			#Inventory.Swords,
			#Inventory.Melee
		)
	)


	return true

end


----------------------------------------------------------
-- INITIAL LOCAL
----------------------------------------------------------

refreshLocal()


print(
	"[BF V11.2] Continuous tracker started"
)


print(
	"[BF V11.2] Full refresh:",
	FULL_INTERVAL,
	"seconds"
)


----------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------

local nextFull =
	0


while
	ENV.BF_TRACKER_INSTANCE
	==
	RUN_ID
do

	------------------------------------------------------
	-- LOCAL DATA EVERY 1 SECOND
	------------------------------------------------------

	refreshLocal()


	------------------------------------------------------
	-- FULL DATA
	------------------------------------------------------

	if os.clock() >= nextFull then

		local success =
			refreshFull()


		if success then

			nextFull =
				os.clock()
				+
				FULL_INTERVAL

		else

			------------------------------------------------
			-- Lúc mới join chưa load xong:
			-- retry nhanh hơn.
			------------------------------------------------

			if State.Ready then

				nextFull =
					os.clock()
					+
					FULL_INTERVAL

			else

				nextFull =
					os.clock()
					+
					INITIAL_RETRY

			end

		end

	end


	task.wait(
		LOCAL_INTERVAL
	)

end


print(
	"[BF V11.2] Old tracker instance stopped"
)
