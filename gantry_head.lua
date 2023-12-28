PROTOCOL_HEAD = "gantry_head"
PROTOCOL_HOST = "gantry"
SIDE_MODEM = "right"
INFO_SLOT = 1

rednet.host(PROTOCOL_HEAD, "gantry0_head")

function init()
    init_rednet()
end

function init_rednet()
    rednet.open(SIDE_MODEM)
    host_id = rednet.lookup(PROTOCOL_HOST)
    local attempts = 1
    while host_id == nil do
        print("Looking for host, attempt " .. attempts)
        sleep(2)
        host_id = rednet.lookup(PROTOCOL_HOST)
        attempts = attempts + 1
    end
end

function send_status()
    rednet.send(host_id, get_status(), PROTOCOL_HEAD)
end

function get_status()
    if not turtle.detectUp() then
        return "none"
    end
    if not peripheral.isPresent("top") then
        print("error: block is present but not an inventory")
        return "error_no_inventory"
    end
    local _specific_type, type = peripheral.getType("top")
    if type ~= "inventory" then
        print("error: peripheral is present but not an inventory")
        return "error_bad_peripheral"
    end
    local inventory = peripheral.wrap("top")
    local info = inventory.getItemDetail(INFO_SLOT)

    if info == nil then
        print("error: inventory present but no item in slot")
        return "error_no_item"
    end

    local status = info.displayName
    print(status)
    return status
end

function main_loop()
    print("Handling status updates")
    while true do
        local _id, message = rednet.receive(PROTOCOL_HEAD)
        if message == "get_head_status" then
            send_status()
        else
            print("Unknown message: " .. message)
        end
    end
end

init()
main_loop()
