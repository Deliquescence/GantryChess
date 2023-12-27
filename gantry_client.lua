
MESSAGE = require("gantry_client_config")
SIDE_REDSTONE = "back"
SIDE_MODEM = "right"
PROTOCOL = "gantry"

function check_and_notify()
    if redstone.getInput(SIDE_REDSTONE) then
        notify()
    end
end

function notify()
    rednet.send(host_id, MESSAGE, PROTOCOL)
end

function init_rednet()
    rednet.open(SIDE_MODEM)
    host_id = rednet.lookup(PROTOCOL)
    if host_id == nil then
        print("Error: gantry host not found")
        error()
    end
end

function main()
    print("This is " .. MESSAGE)
    init_rednet()

    while true do
        local eventData = {os.pullEvent()}
        local event = eventData[1]

        if event == "redstone" then
            check_and_notify()
        elseif event == "rednet_message" then
            local sender = eventData[2]
            local message = eventData[3]
            local protocol = eventData[4]
            if sender == host_id and protocol == PROTOCOL then
                check_and_notify()
            end
        end
    end
end

main()
