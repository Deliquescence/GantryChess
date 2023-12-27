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

function init()
    for _, side in pairs(redstone.getSides()) do
        redstone.setOutput(side, false)
    end

    function init_axis(axis)
        while true do
            local _id, message = rednet.receive(PROTOCOL, 5)
            if message == nil then
                print("No message within timeout, sending broadcast")
                rednet.broadcast("UPDATE_LOCATION", PROTOCOL)
            elseif message == axis.."_0" then
                print(axis.." axis initialization successful")
                break
            end
        end
    end


    print("Attempting primary axis initialization")
    move_backward()
    init_axis("PRIMARY")

    print("Attempting secondary axis initialization")
    move_left()
    init_axis("SECONDARY")
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
    redstone.setOutput(SIDE_PRIMARY_AXIS, true)
    redstone.setOutput(SIDE_SECONDARY_AXIS, true)
end

init()


return {
    move_forward = move_forward,
    move_backward = move_backward,
    move_left = move_left,
    move_right = move_right,
    halt_movement = halt_movement,
}
