-- Primary: forward/back
SIDE_PRIMARY_AXIS = "left"
-- Secondary: left/right
SIDE_SECONDARY_AXIS = "back"
SIDE_STICKER = "right"
SIDE_GEARSHIFT = "top"
-- clockwise input into gearshift


SIDE_MODEM = "bottom"
PROTOCOL = "gantry"

rednet.open(SIDE_MODEM)
rednet.host(PROTOCOL, "gantry0")

current_location = {}

function init()
    for _, side in pairs(redstone.getSides()) do
        redstone.setOutput(side, false)
    end

    print("Attempting primary axis initialization")
    move_backward()
    wait_location_update("primary", 0)

    print("Attempting secondary axis initialization")
    move_left()
    wait_location_update("secondary", 0)
end

function move_primary(to)
    if to < current_location.primary then
        move_backward()
        wait_location_update("primary", to)
    elseif to > current_location.primary then
        move_forward()
        wait_location_update("primary", to)
    end
    halt_primary()
end

function wait_location_update(axis, target)
    while true do
        local _id, message = rednet.receive(PROTOCOL, 5)
        if message == nil then
            print("No message within timeout, sending broadcast")
            rednet.broadcast("update_location", PROTOCOL)
        else
            if message:find("primary_") then
                current_location.primary = tonumber(message:sub(9))
                print("primary at " .. current_location.primary)
            elseif message:find("secondary_") then
                current_location.secondary = tonumber(message:sub(11))
                print("secondary at " .. current_location.secondary)
            end
            if message == axis .. "_" .. target then
                return true
            end
        end
    end
end

function move_forward()
    redstone.setOutput(SIDE_PRIMARY_AXIS, false)
    redstone.setOutput(SIDE_SECONDARY_AXIS, true)
    redstone.setOutput(SIDE_GEARSHIFT, false)
end

function move_backward()
    redstone.setOutput(SIDE_PRIMARY_AXIS, false)
    redstone.setOutput(SIDE_SECONDARY_AXIS, true)
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
    halt_primary()
    halt_secondary()
end

function halt_primary()
    redstone.setOutput(SIDE_PRIMARY_AXIS, true)
end

function halt_secondary()
    redstone.setOutput(SIDE_SECONDARY_AXIS, true)
end

init()
move_primary(2)
move_primary(0)
move_primary(1)


return {
    move_forward = move_forward,
    move_backward = move_backward,
    move_left = move_left,
    move_right = move_right,
    halt_movement = halt_movement,
}
