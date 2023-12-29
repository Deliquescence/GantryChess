---@diagnostic disable: undefined-field
SIDE_MODEM = "left"
SIDE_MONITOR = "right"
PROTOCOL_CONTROL = "gantry_control"
PROTOCOL_LOCATION = "gantry_location"

GANTRY_N_PRIMARY_AXIS = 3
GANTRY_N_SECONDARY_AXIS = 3
monitor = peripheral.wrap(SIDE_MONITOR)
mode = "move_to"
computer_term = term.current()

current_location = {
    primary = nil,
    secondary = nil,
}

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

squares = {}
selection = nil
function clean_write()
    squares = {}
    term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    term.clear()
    monitor.setCursorBlink(false)

    local max_x, max_y = monitor.getSize()
    local usable_x = max_x
    local usable_y = max_y - 3
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
            if current_location.primary == primary and current_location.secondary == secondary then
                color = colors.green
            end

            local x = i * width
            local y = j * height
            local square = {
                startX = x + 1,
                startY = y + 1,
                endX = x + width - 1,
                endY = y + height - 1,
                gantry_primary = primary,
                gantry_secondary = secondary,
                bound_check = square_click_bound_check,
            }
            table.insert(squares, square)
            paintutils.drawBox(square.startX, square.startY, square.endX, square.endY, color)
        end
    end

    paintutils.drawBox(1, max_y - 2, 15, max_y, colors.green)
end

function square_click_bound_check(square, x, y)
    return x >= square.startX and x <= square.endX and y >= square.startY and y <= square.endY
end

function location_update_loop()
    while true do
        local _id, message = rednet.receive(PROTOCOL_LOCATION)
        if message == nil then
            return
        else
            parse_location_update(message)
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

        for _, square in ipairs(squares) do
            if square:bound_check(x, y) then
                selection = square
                local command = {
                    command = "move_to",
                    primary = square.gantry_primary,
                    secondary = square.gantry_secondary,
                }
                local data = textutils.serialize(command)
                rednet.send(host_id, data, PROTOCOL_CONTROL)
            end
        end
        coroutine.yield()
    end
end

init_rednet()
parallel.waitForAll(gui_loop, location_update_loop, request_location_update)
