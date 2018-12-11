ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)
--------------------------------------------------------------------------------
-- do not change anything
--------------------------------------------------------------------------------
local namezone = "Delivery"
local namezonenum = 0
local namezoneregion = 0
local MissionRegion = 0
local vehicleLife = 1000
local moneyWithdraws = 0
local deliveryTotalPay = 0
local deliveryNumber = 0
local missionReturnTruck = false
local missionNum = 0
local missionDelivery = false
local isInService = false
local PlayerData              = nil
local GUI                     = {}
GUI.Time                      = 0
local hasAlreadyEnteredMarker = false
local lastZone                = nil
local Blips                   = {}

local vehiclePlate = ""
local vehiclePlateCurrent = ""
local CurrentAction           = nil
local CurrentActionMsg        = ''
local CurrentActionData       = {}
--------------------------------------------------------------------------------
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

-- MENUS
function MenuCloakRoom()
	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'cloakroom',
		{
			title    = _U('cloakroom'),
			elements = {
				{label = _U('job_wear'), value = 'job_wear'},
				{label = _U('citizen_wear'), value = 'citizen_wear'}
			}
		},
		function(data, menu)
			if data.current.value == 'citizen_wear' then
				isInService = false
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
					  local model = nil

					  if skin.sex == 0 or 1 then
						model = GetHashKey("mp_m_freemode_01")
					  else
						model = GetHashKey("mp_f_freemode_01")
					  end

					  RequestModel(model)
					  while not HasModelLoaded(model) do
						RequestModel(model)
						Citizen.Wait(1)
					  end

					  SetPlayerModel(PlayerId(), model)
					  SetModelAsNoLongerNeeded(model)

					  TriggerEvent('skinchanger:loadSkin', skin)
					  TriggerEvent('esx:restoreLoadout')
        end)
      end
			if data.current.value == 'job_wear' then
				isInService = true
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
	    			if skin.sex == 0 then
	    				TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
					else
	    				TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
					end
				end)
			end
			menu.close()
		end,
		function(data, menu)
			menu.close()
		end
	)
end

function MenuVehicleSpawner()
	local elements = {}

	for i=1, #Config.Trucks, 1 do
		table.insert(elements, {label = GetLabelText(GetDisplayNameFromVehicleModel(Config.Trucks[i])), value = Config.Trucks[i]})
	end


	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'vehiclespawner',
		{
			title    = _U('vehiclespawner'),
			elements = elements
		},
		function(data, menu)
			ESX.Game.SpawnVehicle(data.current.value, Config.Zones.VehicleSpawnPoint.Pos, 270.0, function(vehicle)
				platenum = math.random(10000, 99999)
				SetVehicleNumberPlateText(vehicle, "WAL"..platenum)             
                missionDeliverySelect()
				vehiclePlate = "WAL"..platenum
				if data.current.value == 'phantom3' then
					ESX.Game.SpawnVehicle("trailers2", Config.Zones.VehicleSpawnPoint.Pos, 270.0, function(trailer)
					    AttachVehicleToTrailer(vehicle, trailer, 1.1)
					end)
				end				
				TaskWarpPedIntoVehicle(GetPlayerPed(-1), vehicle, -1)   
			end)

			menu.close()
		end,
		function(data, menu)
			menu.close()
		end
	)
end

function IsATruck()
	local isATruck = false
	local playerPed = GetPlayerPed(-1)
	for i=1, #Config.Trucks, 1 do
		if IsVehicleModel(GetVehiclePedIsUsing(playerPed), Config.Trucks[i]) then
			isATruck = true
			break
		end
	end
	return isATruck
end

function IsJobfedex()
	if PlayerData ~= nil then
		local isJobfedex = false
		if PlayerData.job.name ~= nil and PlayerData.job.name == 'fedex' then
			isJobfedex = true
		end
		return isJobfedex
	end
end

AddEventHandler('esx_fedex:hasEnteredMarker', function(zone)

	local playerPed = GetPlayerPed(-1)

	if zone == 'CloakRoom' then
		MenuCloakRoom()
	end

	if zone == 'VehicleSpawner' then
		if isInService and IsJobfedex() then
			if missionReturnTruck or missionDelivery then
				CurrentAction = 'hint'
                CurrentActionMsg  = _U('already_have_truck')
			else
				MenuVehicleSpawner()
			end
		end
	end

	if zone == namezone then
		if isInService and missionDelivery and missionNum == namezonenum and MissionRegion == namezoneregion and IsJobfedex() then
			if IsPedSittingInAnyVehicle(playerPed) and IsATruck() then
				VerifvehiclePlateCurrent()
				
				if vehiclePlate == vehiclePlateactuel then
					if Blips['delivery'] ~= nil then
						RemoveBlip(Blips['delivery'])
						Blips['delivery'] = nil
					end

					CurrentAction     = 'delivery'
                    CurrentActionMsg  = _U('delivery')
				else
					CurrentAction = 'hint'
                    CurrentActionMsg  = _U('not_your_truck')
				end
			else
				CurrentAction = 'hint'
                CurrentActionMsg  = _U('not_your_truck2')
			end
		end
	end

	if zone == 'cancelmission' then
		if isInService and missionDelivery and IsJobfedex() then
			if IsPedSittingInAnyVehicle(playerPed) and IsATruck() then
				VerifvehiclePlateCurrent()

                TriggerServerEvent('esx:clientLog', "3'" .. json.encode(vehiclePlate) .. "' '" .. json.encode(vehiclePlateCurrent) .. "'")
				
				if vehiclePlate == vehiclePlateCurrent then
                    CurrentAction     = 'returnTruckcancelmission'
                    CurrentActionMsg  = _U('cancel_mission')
				else
					CurrentAction = 'hint'
                    CurrentActionMsg  = _U('not_your_truck')
				end
			else
                CurrentAction     = 'returnTruckLostcancelmission'
			end
		end
	end

	if zone == 'returnTruck' then
		if isInService and missionReturnTruck and IsJobfedex() then
			if IsPedSittingInAnyVehicle(playerPed) and IsATruck() then
				VerifvehiclePlateCurrent()

				if vehiclePlate == vehiclePlateCurrent then
                    CurrentAction     = 'returnTruck'
				else
                    CurrentAction     = 'returnTruckcancelmission'
                    CurrentActionMsg  = _U('not_your_truck')
				end
			else
                CurrentAction     = 'returnTruckLost'
			end
		end
	end

end)

AddEventHandler('esx_fedex:hasExitedMarker', function(zone)
	ESX.UI.Menu.CloseAll()    
    CurrentAction = nil
    CurrentActionMsg = ''
end)

function newDestination()
	deliveryNumber = deliveryNumber+1
	deliveryTotalPay = deliveryTotalPay+destination.Paye

	if deliveryNumber >= Config.MaxDelivery then
		missionDeliveryStopReturnDeposit()
	else

		deliverysuite = math.random(0, 100)
		
		if deliverysuite <= 10 then
			missionDeliveryStopReturnDeposit()
		elseif deliverysuite <= 99 then
			missionDeliverySelect()
		elseif deliverysuite <= 100 then
			if MissionRegion == 1 then
				MissionRegion = 2
			elseif MissionRegion == 2 then
				MissionRegion = 1
			end
			missionDeliverySelect()	
		end
	end
end

function returnTruck_yes()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['cancelmission'] ~= nil then
		RemoveBlip(Blips['cancelmission'])
		Blips['cancelmission'] = nil
	end
	
	missionReturnTruck = false
	deliveryNumber = 0
	MissionRegion = 0
	
	givePay()
end

function returnTruck_no()
	
	if deliveryNumber >= Config.MaxDelivery then
		ESX.ShowNotification(_U('need_it'))
	else
		ESX.ShowNotification(_U('ok_work'))
		newDestination()
	end
end

function returnTruckLost_yes()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['cancelmission'] ~= nil then
		RemoveBlip(Blips['cancelmission'])
		Blips['cancelmission'] = nil
	end
	missionReturnTruck = false
	deliveryNumber = 0
	MissionRegion = 0
	
	givePayWithoutTruck()
end

function returnTruckLost_no()
	ESX.ShowNotification(_U('scared_me'))
end

function returnTruckcancelmission_yes()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['cancelmission'] ~= nil then
		RemoveBlip(Blips['cancelmission'])
		Blips['cancelmission'] = nil
	end
	
	missionDelivery = false
	deliveryNumber = 0
	MissionRegion = 0
	
	givePay()
end

function returnTruckcancelmission_no()	
	ESX.ShowNotification(_U('resume_delivery'))
end

function returnTruckLostcancelmission_yes()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['cancelmission'] ~= nil then
		RemoveBlip(Blips['cancelmission'])
		Blips['cancelmission'] = nil
	end
	
	missionDelivery = false
	deliveryNumber = 0
	MissionRegion = 0
	
	givePayWithoutTruck()
end

function returnTruckLostcancelmission_no()	
	ESX.ShowNotification(_U('resume_delivery'))
end

function round(num, numDecimalPlaces)
    local mult = 5^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function givePay()
	ped = GetPlayerPed(-1)
	vehicle = GetVehiclePedIsIn(ped, false)
	vievehicule = GetVehicleEngineHealth(vehicle)
	calculmoneyWithdraws = round(vehicleLife-vievehicule)
	
	if calculmoneyWithdraws <= 0 then
		moneyWithdraws = 0
	else
		moneyWithdraws = calculmoneyWithdraws
	end

    ESX.Game.DeleteVehicle(vehicle)

	local amount = deliveryTotalPay-moneyWithdraws
	
	if vievehicule >= 1 then
		if deliveryTotalPay == 0 then
			ESX.ShowNotification(_U('not_delivery'))
			ESX.ShowNotification(_U('pay_repair'))
			ESX.ShowNotification(_U('repair_minus')..moneyWithdraws)
			TriggerServerEvent("esx_fedex:pay", amount)
			deliveryTotalPay = 0
		else
			if moneyWithdraws <= 0 then
				ESX.ShowNotification(_U('shipments_plus')..deliveryTotalPay)
				TriggerServerEvent("esx_fedex:pay", amount)
				deliveryTotalPay = 0
			else
				ESX.ShowNotification(_U('shipments_plus')..deliveryTotalPay)
				ESX.ShowNotification(_U('repair_minus')..moneyWithdraws)
					TriggerServerEvent("esx_fedex:pay", amount)
				deliveryTotalPay = 0
			end
		end
	else
		if deliveryTotalPay ~= 0 and amount <= 0 then
			ESX.ShowNotification(_U('truck_state'))
			deliveryTotalPay = 0
		else
			if moneyWithdraws <= 0 then
				ESX.ShowNotification(_U('shipments_plus')..deliveryTotalPay)
					TriggerServerEvent("esx_fedex:pay", amount)
				deliveryTotalPay = 0
			else
				ESX.ShowNotification(_U('shipments_plus')..deliveryTotalPay)
				ESX.ShowNotification(_U('repair_minus')..moneyWithdraws)
				TriggerServerEvent("esx_fedex:pay", amount)
				deliveryTotalPay = 0
			end
		end
	end
end

function givePayWithoutTruck()
	ped = GetPlayerPed(-1)
	moneyWithdraws = Config.TruckPrice
	
	-- donne paye
	local amount = deliveryTotalPay-moneyWithdraws
	
	if deliveryTotalPay == 0 then
		ESX.ShowNotification(_U('no_delivery_no_truck'))
		ESX.ShowNotification(_U('truck_price')..moneyWithdraws)
					TriggerServerEvent("esx_fedex:pay", amount)
		deliveryTotalPay = 0
	else
		if amount >= 1 then
			ESX.ShowNotification(_U('shipments_plus')..deliveryTotalPay)
			ESX.ShowNotification(_U('truck_price')..moneyWithdraws)
					TriggerServerEvent("esx_fedex:pay", amount)
			deliveryTotalPay = 0
		else
			ESX.ShowNotification(_U('truck_state'))
			deliveryTotalPay = 0
		end
	end
end

-- Key Controls
Citizen.CreateThread(function()
    while true do

        Citizen.Wait(0)

        if CurrentAction ~= nil then

        	SetTextComponentFormat('STRING')
        	AddTextComponentString(CurrentActionMsg)
       		DisplayHelpTextFromStringLabel(0, 0, 1, -1)

            if IsControlJustReleased(0, 38) and IsJobfedex() then

                if CurrentAction == 'delivery' then
                    newDestination()
                end

                if CurrentAction == 'returnTruck' then
                    returnTruck_yes()
                end

                if CurrentAction == 'returnTruckLost' then
                    returnTruckLost_yes()
                end

                if CurrentAction == 'returnTruckcancelmission' then
                    returnTruckcancelmission_yes()
                end

                if CurrentAction == 'returnTruckLostcancelmission' then
                    returnTruckLostcancelmission_yes()
                end

                CurrentAction = nil
            end

        end

    end
end)

-- DISPLAY MISSION MARKERS AND MARKERS
Citizen.CreateThread(function()
	while true do
		Wait(0)
		
		if missionDelivery then
			DrawMarker(destination.Type, destination.Pos.x, destination.Pos.y, destination.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, destination.Size.x, destination.Size.y, destination.Size.z, destination.Color.r, destination.Color.g, destination.Color.b, 100, false, true, 2, false, false, false, false)
			DrawMarker(Config.delivery.cancelmission.Type, Config.delivery.cancelmission.Pos.x, Config.delivery.cancelmission.Pos.y, Config.delivery.cancelmission.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.delivery.cancelmission.Size.x, Config.delivery.cancelmission.Size.y, Config.delivery.cancelmission.Size.z, Config.delivery.cancelmission.Color.r, Config.delivery.cancelmission.Color.g, Config.delivery.cancelmission.Color.b, 100, false, true, 2, false, false, false, false)
		elseif missionReturnTruck then
			DrawMarker(destination.Type, destination.Pos.x, destination.Pos.y, destination.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, destination.Size.x, destination.Size.y, destination.Size.z, destination.Color.r, destination.Color.g, destination.Color.b, 100, false, true, 2, false, false, false, false)
		end

		local coords = GetEntityCoords(GetPlayerPed(-1))
		
		for k,v in pairs(Config.Zones) do

			if isInService and (IsJobfedex() and v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end

		end

		for k,v in pairs(Config.Cloakroom) do

			if(IsJobfedex() and v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end

		end
		
	end
end)

-- Activate menu when player is inside marker
Citizen.CreateThread(function()
	while true do
		
		Wait(0)
		
		if IsJobfedex() then

			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil

			for k,v in pairs(Config.Zones) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end
			
			for k,v in pairs(Config.Cloakroom) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end
			
			for k,v in pairs(Config.delivery) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end

			if isInMarker and not hasAlreadyEnteredMarker then
				hasAlreadyEnteredMarker = true
				lastZone                = currentZone
				TriggerEvent('esx_fedex:hasEnteredMarker', currentZone)
			end

			if not isInMarker and hasAlreadyEnteredMarker then
				hasAlreadyEnteredMarker = false
				TriggerEvent('esx_fedex:hasExitedMarker', lastZone)
			end

		end

	end
end)

-- CREATE BLIPS
Citizen.CreateThread(function()
	local blip = AddBlipForCoord(Config.Cloakroom.CloakRoom.Pos.x, Config.Cloakroom.CloakRoom.Pos.y, Config.Cloakroom.CloakRoom.Pos.z)
  
	SetBlipSprite (blip, 67)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.2)
	SetBlipColour (blip, 5)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_job'))
	EndTextCommandSetBlipName(blip)
end)

-------------------------------------------------
-- Fonctions
-------------------------------------------------
-- Fonction selection new mission delivery
function missionDeliverySelect()
    TriggerServerEvent('esx:clientLog', "missionDeliverySelect num")
    TriggerServerEvent('esx:clientLog', MissionRegion)
    

	if MissionRegion == 0 then

            TriggerServerEvent('esx:clientLog', "missionDeliverySelect 1")
		MissionRegion = math.random(1,2)
	end
	
	if MissionRegion == 1 then -- Los santos
            TriggerServerEvent('esx:clientLog', "missionDeliverySelect 2")
		missionNum = math.random(1, 10)
	
		if missionNum == 1 then destination = Config.delivery.Delivery1LS namezone = "Delivery1LS" namezonenum = 1 namezoneregion = 1
		elseif missionNum == 2 then destination = Config.delivery.Delivery2LS namezone = "Delivery2LS" namezonenum = 2 namezoneregion = 1
		elseif missionNum == 3 then destination = Config.delivery.Delivery3LS namezone = "Delivery3LS" namezonenum = 3 namezoneregion = 1
		elseif missionNum == 4 then destination = Config.delivery.Delivery4LS namezone = "Delivery4LS" namezonenum = 4 namezoneregion = 1
		elseif missionNum == 5 then destination = Config.delivery.Delivery5LS namezone = "Delivery5LS" namezonenum = 5 namezoneregion = 1
		elseif missionNum == 6 then destination = Config.delivery.Delivery6LS namezone = "Delivery6LS" namezonenum = 6 namezoneregion = 1
		elseif missionNum == 7 then destination = Config.delivery.Delivery7LS namezone = "Delivery7LS" namezonenum = 7 namezoneregion = 1
		elseif missionNum == 8 then destination = Config.delivery.Delivery8LS namezone = "Delivery8LS" namezonenum = 8 namezoneregion = 1
		elseif missionNum == 9 then destination = Config.delivery.Delivery9LS namezone = "Delivery9LS" namezonenum = 9 namezoneregion = 1
		elseif missionNum == 10 then destination = Config.delivery.Delivery10LS namezone = "Delivery10LS" namezonenum = 10 namezoneregion = 1
		end
		
	elseif MissionRegion == 2 then -- Blaine County

            TriggerServerEvent('esx:clientLog', "missionDeliverySelect 3")
		missionNum = math.random(1, 10)
	
		if missionNum == 1 then destination = Config.delivery.Delivery1BC namezone = "Delivery1BC" namezonenum = 1 namezoneregion = 2
		elseif missionNum == 2 then destination = Config.delivery.Delivery2BC namezone = "Delivery2BC" namezonenum = 2 namezoneregion = 2
		elseif missionNum == 3 then destination = Config.delivery.Delivery3BC namezone = "Delivery3BC" namezonenum = 3 namezoneregion = 2
		elseif missionNum == 4 then destination = Config.delivery.Delivery4BC namezone = "Delivery4BC" namezonenum = 4 namezoneregion = 2
		elseif missionNum == 5 then destination = Config.delivery.Delivery5BC namezone = "Delivery5BC" namezonenum = 5 namezoneregion = 2
		elseif missionNum == 6 then destination = Config.delivery.Delivery6BC namezone = "Delivery6BC" namezonenum = 6 namezoneregion = 2
		elseif missionNum == 7 then destination = Config.delivery.Delivery7BC namezone = "Delivery7BC" namezonenum = 7 namezoneregion = 2
		elseif missionNum == 8 then destination = Config.delivery.Delivery8BC namezone = "Delivery8BC" namezonenum = 8 namezoneregion = 2
		elseif missionNum == 9 then destination = Config.delivery.Delivery9BC namezone = "Delivery9BC" namezonenum = 9 namezoneregion = 2
		elseif missionNum == 10 then destination = Config.delivery.Delivery10BC namezone = "Delivery10BC" namezonenum = 10 namezoneregion = 2
		end
		
	end
	
	missionDeliveryLetsGo()
end

-- Function active mission delivery
function missionDeliveryLetsGo()
	if Blips['delivery'] ~= nil then
		RemoveBlip(Blips['delivery'])
		Blips['delivery'] = nil
	end
	
	if Blips['cancelmission'] ~= nil then
		RemoveBlip(Blips['cancelmission'])
		Blips['cancelmission'] = nil
	end
	
	Blips['delivery'] = AddBlipForCoord(destination.Pos.x,  destination.Pos.y,  destination.Pos.z)
	SetBlipRoute(Blips['delivery'], true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_delivery'))
	EndTextCommandSetBlipName(Blips['delivery'])
	
	Blips['cancelmission'] = AddBlipForCoord(Config.delivery.cancelmission.Pos.x,  Config.delivery.cancelmission.Pos.y,  Config.delivery.cancelmission.Pos.z)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_goal'))
	EndTextCommandSetBlipName(Blips['cancelmission'])

	if MissionRegion == 1 then -- Los santos
		ESX.ShowNotification(_U('meet_ls'))
	elseif MissionRegion == 2 then -- Blaine County
		ESX.ShowNotification(_U('meet_bc'))
	elseif MissionRegion == 0 then -- in case
		ESX.ShowNotification(_U('meet_del'))
	end

	missionDelivery = true
end

--Function return deposit
function missionDeliveryStopReturnDeposit()
	destination = Config.delivery.returnTruck
	
	Blips['delivery'] = AddBlipForCoord(destination.Pos.x,  destination.Pos.y,  destination.Pos.z)
	SetBlipRoute(Blips['delivery'], true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('blip_depot'))
	EndTextCommandSetBlipName(Blips['delivery'])
	
	if Blips['cancelmission'] ~= nil then
		RemoveBlip(Blips['cancelmission'])
		Blips['cancelmission'] = nil
	end

	ESX.ShowNotification(_U('return_depot'))
	
	MissionRegion = 0
	missionDelivery = false
	missionNum = 0
	missionReturnTruck = true
end

function SavevehiclePlate()
	vehiclePlate = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(-1), false))
end

function VerifvehiclePlateCurrent()
	vehiclePlateCurrent = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(-1), false))
end