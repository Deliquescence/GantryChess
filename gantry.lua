

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

    move_backward()
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
