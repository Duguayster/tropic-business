local QBCore = exports['qb-core']:GetCoreObject()
local businesses = {}

-- Load business ownership data from a file on server start
local function loadBusinesses()
    local file = LoadResourceFile(GetCurrentResourceName(), 'businesses.json')
    if file then
        businesses = json.decode(file) or {}
    else
        businesses = {} -- Initialize as empty if the file doesn't exist
    end
end

-- Save business ownership data to a file
local function saveBusinesses()
    local jsonData = json.encode(businesses)
    SaveResourceFile(GetCurrentResourceName(), 'businesses.json', jsonData, -1)
end

-- Initialize the businesses JSON based on the Config
local function initializeBusinesses()
    for index, business in ipairs(Config.Businesses) do
        if not businesses[index] then
            businesses[index] = { owner = nil, job = nil } -- Start as null for each business
        end
    end
    saveBusinesses() -- Save the initialized structure
end

-- Load businesses when the server starts
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        loadBusinesses()
        initializeBusinesses() -- Ensure all businesses are initialized
    end
end)

RegisterNetEvent('business:buyBusiness', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local business = Config.Businesses[index]
    local money = Player.PlayerData.money['cash']

    -- Check if business license is required
    if Config.RequireBusinessLicense then
        local hasLicense = false

        if Config.Inventory == "qb" then
            -- Check for business license in qb-inventory
            hasLicense = Player.Functions.HasItem('business_license', 1)
        elseif Config.Inventory == "ox" then
            -- Check for business license in ox-inventory
            hasLicense = Player.Functions.GetItemByName('business_license') and Player.Functions.GetItemByName('business_license').amount > 0
        end

        if not hasLicense then
            TriggerClientEvent('QBCore:Notify', src, "You need a business license to purchase this business.", 'error')
            return
        end
    end

    -- Existing purchase logic
    if businesses[index] and businesses[index].owner == Player.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "You already own this business", 'error')
        return
    end

    if money >= business.BusinessPrice then
        Player.Functions.RemoveMoney('cash', business.BusinessPrice)
        Player.Functions.SetJob(business.BusinessJob, business.BusinessGrade)

        -- Set ownership in the businesses table
        businesses[index] = {
            owner = Player.PlayerData.citizenid,
            job = business.BusinessJob
        }

        saveBusinesses() -- Save ownership data
        TriggerClientEvent('QBCore:Notify', src, "You have purchased the business and are now the owner of " .. business.BusinessJob, 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough money to purchase this business", 'error')
    end
end)


RegisterNetEvent('business:sellBusiness', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local business = Config.Businesses[index]
    local job = Player.PlayerData.job.name

    -- Check if the player owns the business
    if businesses[index] and businesses[index].owner == Player.PlayerData.citizenid then
        local refund = business.BusinessPrice * (business.SellBackPercentage / 100)
        Player.Functions.AddMoney('cash', refund)
        Player.Functions.SetJob('unemployed', 0)

        -- Remove ownership
        businesses[index] = { owner = nil, job = nil } -- Reset to null
        saveBusinesses() -- Save updated ownership data
        TriggerClientEvent('QBCore:Notify', src, "You have sold the business and received $" .. refund, 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, "You do not own this business", 'error')
    end
end)

-- Check business ownership when a player connects
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
      local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    -- Give ownership back to players if they own a business
    for index, data in pairs(businesses) do
        if data.owner == Player.PlayerData.citizenid then
            Player.Functions.SetJob(data.job, Config.Businesses[index].BusinessGrade)
        end
    end
end) 
