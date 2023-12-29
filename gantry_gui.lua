---@diagnostic disable: undefined-field
SIDE_MODEM = "left"
SIDE_MONITOR = "right"
PROTOCOL_CONTROL = "gantry_control"
PROTOCOL_CONTROL_ACK = "gantry_control_ack"
PROTOCOL_LOCATION = "gantry_location"
GANTRY_N_PRIMARY_AXIS = 4
GANTRY_N_SECONDARY_AXIS = 5
PIXELS_BOTTOM_ROW = 5
MODES = {
    move = "move_to",
    transport = "transport"
}

monitor = peripheral.wrap(SIDE_MONITOR)
computer_term = term.current()

waiting_command = false
mode = MODES.move
current_location = {
    primary = nil,
    secondary = nil,
}
squares = {}
selection_to = nil
selection_from = nil
mode_change_box = nil

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

function clean_write()
    squares = {}
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    term.clear()
    monitor.setCursorBlink(false)

    local max_x, max_y = monitor.getSize()
    local usable_x = max_x
    local usable_y = max_y - PIXELS_BOTTOM_ROW
    local width = math.floor(usable_x / GANTRY_N_SECONDARY_AXIS)
    local height = math.floor(usable_y / GANTRY_N_PRIMARY_AXIS)
    for i = 0, GANTRY_N_SECONDARY_AXIS - 1, 1 do
        for j = 0, GANTRY_N_PRIMARY_AXIS - 1, 1 do
            -- different coordinate system
            local primary = GANTRY_N_PRIMARY_AXIS - j - 1
            local secondary = i

            local parity = (i + j) % 2 == 0
            local color = colors.gray
            if parity then color = colors.lightGray end
            if selection_from ~= nil and selection_from.gantry_primary == primary and selection_from.gantry_secondary == secondary then
                color = colors.purple
            elseif selection_to ~= nil and selection_to.gantry_primary == primary and selection_to.gantry_secondary == secondary then
                color = colors.blue
            elseif current_location.primary == primary and current_location.secondary == secondary then
                color = colors.green
            end

            local x = i * width
            local y = j * height
            local square = drawBox(
                x + 1,
                y + 1,
                x + width - 1,
                y + height - 1,
                color)
            square.gantry_primary = primary
            square.gantry_secondary = secondary
            table.insert(squares, square)
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, max_y - 3)
    if waiting_command then
        term.write("Waiting for previous command to finish...")
    else
        term.clearLine()
    end

    mode_change_box = drawBox(1, max_y - 2, 17, max_y, colors.brown, true)
    term.setCursorPos(2, max_y - 1)
    term.write("Mode: " .. mode)
end

function drawBox(startX, startY, endX, endY, color, filled)
    local box = {
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        color = color,
        bound_check = gui_click_bound_check,
    }
    if filled then
        paintutils.drawFilledBox(box.startX, box.startY, box.endX, box.endY, color)
    else
        paintutils.drawBox(box.startX, box.startY, box.endX, box.endY, color)
    end
    return box
end

function gui_click_bound_check(box, x, y)
    return x >= box.startX and x <= box.endX and y >= box.startY and y <= box.endY
end

function rednet_receive_loop()
    while true do
        local _id, message, protocol = rednet.receive()
        if message == nil then
            return
        elseif protocol == PROTOCOL_LOCATION then
            parse_location_update(message)
            clean_write()
        elseif protocol == PROTOCOL_CONTROL_ACK then
            waiting_command = false
            selection_from = nil
            selection_to = nil
            clean_write()
        end
    end
end

function is_valid_location()
    return current_location.primary ~= nil and
        current_location.secondary ~= nil
end

-- function force_location_update()
--     print("Broadcasting to get current location")
--     rednet.broadcast("update_location", PROTOCOL_LOCATION)
--     while true do
--         local _id, message = rednet.receive(PROTOCOL_LOCATION, 2)
--         if message == nil then
--             return
--         else
--             parse_location_update(message)
--         end
--     end
-- end

function parse_location_update(message)
    if message == nil then return end

    if message:find("primary_") then
        current_location.primary = tonumber(message:sub(9))
        -- print("primary at " .. current_location.primary)
    elseif message:find("secondary_") then
        current_location.secondary = tonumber(message:sub(11))
        -- print("secondary at " .. current_location.secondary)
    end
end

function request_location_update()
    print("Sending location broadcast")
    rednet.broadcast("update_location", PROTOCOL_LOCATION)
end

function gui_loop()
    while true do
        clean_write()
        term.redirect(computer_term)
        local _event, _side, x, y = os.pullEvent("monitor_touch")

        if mode_change_box:bound_check(x, y) then
            if mode == MODES.move then
                mode = MODES.transport
            else
                mode = MODES.move
            end
        end
        local touched_square = nil
        for _, square in ipairs(squares) do
            if square:bound_check(x, y) then
                touched_square = square
            end
        end
        if touched_square ~= nil and not waiting_command then
            if mode == MODES.move then
                selection_from = nil
                selection_to = touched_square
                local command = {
                    command = mode,
                    primary = touched_square.gantry_primary,
                    secondary = touched_square.gantry_secondary,
                }
                send_command(command)
            elseif mode == MODES.transport then
                if selection_from == nil then
                    selection_from = touched_square
                else
                    selection_to = touched_square
                    local command = {
                        command = mode,
                        fp = selection_from.gantry_primary,
                        fs = selection_from.gantry_secondary,
                        tp = selection_to.gantry_primary,
                        ts = selection_to.gantry_secondary,
                    }
                    send_command(command)
                end
            end
        end
    end
end

function send_command(command)
    local data = textutils.serialize(command)
    rednet.send(host_id, data, PROTOCOL_CONTROL)
    waiting_command = true
end

init_rednet()
parallel.waitForAll(gui_loop, rednet_receive_loop, request_location_update)