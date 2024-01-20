PROTOCOL_CONTROL = "gantry_control"
PROTOCOL_CONTROL_ACK = "gantry_control_ack"
PROTOCOL_LOCATION = "gantry_location"
PROTOCOL_HEAD = "gantry_head"

GANTRY_N_PRIMARY_AXIS = 8
GANTRY_N_SECONDARY_AXIS = 12

local control = {
    SIDE_AXIS_CONTROL = "back",
    SIDE_THROTTLE = "left", -- redstone enabled means double speed
    SIDE_STICKER = "right",
    SIDE_GEARSHIFT = "top",
    SIDE_HEAD_CLUTCH = "front",
    SIDE_MODEM = "bottom",
    SECONDARY_AXIS_POWER_LEVEL = 2,
    PISTON_DEBOUNCE = 0.8,
    STICKER_DEBOUNCE = 0.20,
}

local gui = {
    SIDE_MODEM = "left",
    SIDE_MONITOR = "right",
}

local head = {
    SIDE_MODEM = "right",
    INFO_SLOT = 1,
}

local waypoint = {
    SIDE_REDSTONE = "left",
    SIDE_MODEM = "right",
}

return {
    control = control,
    gui = gui,
    head = head,
    waypoint = waypoint,
}
