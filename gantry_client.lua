---@diagnostic disable: undefined-field
MESSAGE = require("gantry_client_config")
SIDE_REDSTONE = "back"
SIDE_MODEM = "right"
PROTOCOL_LOCATION = "gantry_location"
PROTOCOL_CONTROL = "gantry_control"
MAX_ATTEMPTS = 20

function check_and_notify()
    if redstone.getInput(SIDE_REDSTONE) then
        notify()
    end
end

function notify()
    rednet.send(host_id, MESSAGE, PROTOCOL_LOCATION)
end

function init_rednet()
    print("Initializing rednet")
    rednet.open(SIDE_MODEM)
    host_id = rednet.lookup(PROTOCOL_CONTROL)
    local attempts = 1
    while host_id == nil do
        print("Looking for host, attempt " .. attempts)
        sleep(2)
        host_id = rednet.lookup(PROTOCOL_CONTROL)
        attempts = attempts + 1
    end
    print("Control host found")
end

function main()
    print("This is " .. MESSAGE)
    init_rednet()

    while true do
        local eventData = { os.pullEvent() }
        local event = eventData[1]

        if event == "redstone" then
            check_and_notify()
        elseif event == "rednet_message" then
            local sender = eventData[2]
            local message = eventData[3]
            local protocol = eventData[4]
            if sender == host_id and protocol == PROTOCOL_LOCATION then
                check_and_notify()
            end
        end
    end
end

main()
