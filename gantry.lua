-- clockwise input into gearshift
-- Primary: forward/back
SIDE_PRIMARY_AXIS = "left"
-- Secondary: left/right
SIDE_SECONDARY_AXIS = "back"
SIDE_STICKER = "right"
SIDE_GEARSHIFT = "top"
SIDE_STICKER = "right"
SIDE_HEAD_CLUTCH = "front"

PISTON_DEBOUNCE = 0.8
STICKER_DEBOUNCE = 0.20

SIDE_MODEM = "bottom"
PROTOCOL_LOCATION = "gantry_location"
PROTOCOL_HEAD = "gantry_head"
PROTOCOL_CONTROL = "gantry_control"

current_location = {
    primary = nil,
    secondary = nil,
}
holding = nil

function init()
    print("Initializing...")

    rednet.open(SIDE_MODEM)
    rednet.host(PROTOCOL_CONTROL, "gantry0_control")

    for _, side in pairs(redstone.getSides()) do
        -- Stop axis movement, reset everything else
        local enable = side == SIDE_PRIMARY_AXIS or side == SIDE_SECONDARY_AXIS
        redstone.setOutput(side, enable)
    end

    init_head_rednet()

    force_location_update()

    print("Checking if payload is attached")
    lower_piston()
    init_check_head()

    if not is_valid_location() then
        print("Bad location, resetting")
        reset_location()
    end
end

function init_check_head(second_check)
    local status = get_head_status()
    if status:find("error") then
        print("Error: head returned " .. status)
        error()
    elseif status == "none" and not second_check then
        print("No payload, making sure sticker is disabled")
        raise_piston()
        lower_piston()
        init_check_head(true)
    elseif status == "none" and second_check then
        print("Sticker clean")
    elseif second_check then
        print("Payload still attached, cycling again")
        raise_piston()
        toggle_sticker()
        lower_piston()
    else
        print("Found " .. status .. " on head")
        if not is_valid_location() then
            print("Location bad, but have payload. Moving to 0 0.")
            reset_location()
            init_check_head(true)
        else
            print("Location good, unsticking.")
            raise_piston()
            toggle_sticker()
            lower_piston()
            init_check_head(true)
        end
    end
end

function is_valid_location()
    return current_location.primary ~= nil and
        current_location.secondary ~= nil
end

function init_head_rednet()
    print("Connecting to gantry head")
    head_id = rednet.lookup(PROTOCOL_HEAD)
    local attempts = 1
    local MAX_ATTEMPTS = 5
    while head_id == nil do
        attempts = attempts + 1
        sleep(2)
        if attempts > MAX_ATTEMPTS then
            print("Error: gantry head not found")
            error()
        end
        head_id = rednet.lookup(PROTOCOL_HEAD)
    end
end

function get_head_status()
    rednet.send(head_id, "get_head_status", PROTOCOL_HEAD)
    for i = 0, 10, 1 do
        local id, message = rednet.receive(PROTOCOL_HEAD, 1)
        if message ~= nil then
            return message
        end
    end
    print("Error: head not responding to status request")
    error()
end

function reset_location()
    print("Moving primary axis to 0")
    move_backward()
    wait_location_update("primary", 0)

    print("Moving secondary axis to 0")
    move_left()
    wait_location_update("secondary", 0)
end

function transport_from_to(fp, fs, tp, ts)
    move_to(fp, fs)
    grab()

    move_to(tp, ts)
    release()
end

function grab()
    raise_piston()
    local status = get_head_status()
    if status:find("error") then
        print("Can't grab here because of error head status " .. status)
        lower_piston()
        error()
    elseif status == "none" then
        print("Warning: grabbing nothing")
    else
        print("Grabbing " .. status)
        holding = status
    end
    toggle_sticker()
    lower_piston()
end

function release()
    raise_piston()
    toggle_sticker()
    lower_piston()
    holding = nil
end

function move_to(primary, secondary)
    print()
    print("moving to " .. primary .. ", " .. secondary)
    move_axis("primary", primary)
    move_axis("secondary", secondary)
end

function move_axis(axis, to)
    if to < current_location[axis] then
        if axis == "primary" then
            move_backward()
        else
            move_left()
        end
        wait_location_update(axis, to)
    elseif to > current_location[axis] then
        if axis == "primary" then
            move_forward()
        else
            move_right()
        end
        wait_location_update(axis, to)
    end
    halt_axis(axis)
end

function wait_location_update(axis, target)
    while true do
        local _id, message = rednet.receive(PROTOCOL_LOCATION, 5)
        if message == nil then
            print("No message within timeout, sending broadcast")
            rednet.broadcast("update_location", PROTOCOL_LOCATION)
        else
            parse_location_update(message)
            if message == axis .. "_" .. target then
                return true
            end
        end
    end
end

function force_location_update()
    print("Broadcasting to get current location")
    rednet.broadcast("update_location", PROTOCOL_LOCATION)
    while true do
        local _id, message = rednet.receive(PROTOCOL_LOCATION, 5)
        if message == nil then
            return
        else
            parse_location_update(message)
        end
    end
end

function parse_location_update(message)
    if message == nil then return end

    if message:find("primary_") then
        current_location.primary = tonumber(message:sub(9))
        print("primary at " .. current_location.primary)
    elseif message:find("secondary_") then
        current_location.secondary = tonumber(message:sub(11))
        print("secondary at " .. current_location.secondary)
    end
end

function move_forward()
    redstone.setOutput(SIDE_PRIMARY_AXIS, false)
    redstone.setOutput(SIDE_GEARSHIFT, false)
end

function move_backward()
    redstone.setOutput(SIDE_PRIMARY_AXIS, false)
    redstone.setOutput(SIDE_GEARSHIFT, true)
end

function move_left()
    redstone.setOutput(SIDE_PRIMARY_AXIS, true)
    redstone.setOutput(SIDE_SECONDARY_AXIS, false)
    redstone.setOutput(SIDE_GEARSHIFT, true)
end

function move_right()
    redstone.setOutput(SIDE_PRIMARY_AXIS, true)
    redstone.setOutput(SIDE_SECONDARY_AXIS, false)
    redstone.setOutput(SIDE_GEARSHIFT, false)
end

function halt_movement()
    halt_axis("primary")
    halt_axis("secondary")
end

function halt_axis(axis)
    -- print("HALT " .. axis)
    if axis == "primary" then
        redstone.setOutput(SIDE_PRIMARY_AXIS, true)
    elseif axis == "secondary" then
        redstone.setOutput(SIDE_SECONDARY_AXIS, true)
    else
        print(axis .. " is not an axis")
        error()
    end
end

function raise_piston()
    redstone.setOutput(SIDE_GEARSHIFT, true)
    redstone.setOutput(SIDE_HEAD_CLUTCH, true)
    sleep(PISTON_DEBOUNCE)
    redstone.setOutput(SIDE_HEAD_CLUTCH, false)
    sleep(PISTON_DEBOUNCE)
end

function lower_piston()
    redstone.setOutput(SIDE_GEARSHIFT, false)
    redstone.setOutput(SIDE_HEAD_CLUTCH, true)
    sleep(PISTON_DEBOUNCE)
    redstone.setOutput(SIDE_HEAD_CLUTCH, false)
    sleep(PISTON_DEBOUNCE)
end

function toggle_sticker()
    sleep(STICKER_DEBOUNCE)
    redstone.setOutput(SIDE_STICKER, true)
    sleep(STICKER_DEBOUNCE)
    redstone.setOutput(SIDE_STICKER, false)
    sleep(STICKER_DEBOUNCE)
end

init()

-- transport_from_to(2, 0, 2, 1)
-- sleep(2)
-- transport_from_to(1, 1, 2, 2)
-- transport_from_to(0, 2, 1, 0)
-- transport_from_to(0, 0, 2, 2)
-- move_to(2, 2)
-- sleep(2)
-- move_to(0, 2)
-- sleep(2)
-- move_to(1, 1)

return {
    move_forward = move_forward,
    move_backward = move_backward,
    move_left = move_left,
    move_right = move_right,
    halt_movement = halt_movement,
}
