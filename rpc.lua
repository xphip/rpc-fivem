local isServer = IsDuplicityVersion()

local RPC = {}
local registered = {}
local callbacks = {}
local idCounter = 0

---@param name string
---@param fn function
function RPC.register(name, fn)
    registered[name] = fn

    local prefix = isServer and "rpc:call:server:" or "rpc:call:client:"
    RegisterNetEvent(prefix .. name)
    AddEventHandler(prefix .. name, function(id, args)
        local src = isServer and source or nil
        local ok, result = pcall(function()
            return fn(src, table.unpack(args))
        end)
        if isServer then
            TriggerClientEvent("rpc:response", src, id, ok, result)
        else
            TriggerServerEvent("rpc:response", id, ok, result)
        end
    end)
end

RegisterNetEvent("rpc:response")
AddEventHandler("rpc:response", function(id, success, res)
    if callbacks[id] then
        callbacks[id](success, res)
        callbacks[id] = nil
    end
end)

---@param target number | nil
---@param method string
---@param ... any
---@return any
function RPC.call(target, method, ...)
    idCounter = idCounter + 1
    local id = tostring(GetGameTimer()) .. "_" .. tostring(idCounter)
    local args = { ... }

    local done = false
    local ok = false
    local result = nil

    callbacks[id] = function(success, res)
        done = true
        ok = success
        result = res
    end

    if isServer then
        TriggerClientEvent("rpc:call:client:" .. method, target, id, args)
    else
        TriggerServerEvent("rpc:call:server:" .. method, id, args)
    end

    local timeout = GetGameTimer() + 10000
    while not done and GetGameTimer() < timeout do
        Wait(0)
    end

    callbacks[id] = nil

    if not done then
        error(("RPC [%s] timed out"):format(method))
    end

    if not ok then
        error(("RPC [%s] failed: %s"):format(method, result))
    end

    return result
end
