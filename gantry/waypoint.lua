---@diagnostic disable: undefined-field
local MESSAGE = os.getComputerLabel()
local SIDE_REDSTONE = "left"
local SIDE_MODEM = "right"
PROTOCOL_LOCATION = "gantry_location"
PROTOCOL_CONTROL = "gantry_control"

local client = {}

function client:check_and_notify()
    if redstone.getInput(SIDE_REDSTONE) then
        self:notify()
    end
end

function client:notify()
    rednet.broadcast(MESSAGE, PROTOCOL_LOCATION)
end

function client:init_rednet()
    print("Initializing rednet")
    rednet.open(SIDE_MODEM)
    -- host_id = rednet.lookup(PROTOCOL_CONTROL)
    -- local attempts = 1
    -- while host_id == nil do
    --     print("Looking for host, attempt " .. attempts)
    --     sleep(1)
    --     host_id = rednet.lookup(PROTOCOL_CONTROL)
    --     attempts = attempts + 1
    -- end
    -- print("Control host found")
end

local function main()
    print("This is " .. MESSAGE)
    client:init_rednet()

    while true do
        local eventData = { os.pullEvent() }
        local event = eventData[1]

        if event == "redstone" then
            client:check_and_notify()
        elseif event == "rednet_message" then
            local sender = eventData[2]
            local message = eventData[3]
            local protocol = eventData[4]
            if message == "update_location" and protocol == PROTOCOL_LOCATION then
                client:check_and_notify()
            end
        end
    end
end

main()
