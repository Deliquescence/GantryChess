---@diagnostic disable: undefined-field

local config = require("config").gui

local PIXELS_BOTTOM_ROW = 5
local MODES = {
    move = "move_to",
    transport = "transport",
    inspect = "inspect",
}

local monitor = peripheral.wrap(config.SIDE_MONITOR)
local computer_term = term.current()

local gui = {
    waiting_command = false,
    mode = MODES.inspect,
    current_location = {
        primary = nil,
        secondary = nil,
    },
    recent_command_info = nil,
    squares = {},
    selection_to = nil,
    selection_from = nil,
    mode_change_box = nil,
}

local function print_term(str)
    local prev = term.redirect(computer_term)
    print(str)
    term.redirect(prev)
end

function gui:init_rednet()
    print("Initializing rednet")
    rednet.open(config.SIDE_MODEM)
    self.host_id = rednet.lookup(PROTOCOL_CONTROL)
    local attempts = 1
    while self.host_id == nil do
        print("Looking for host, attempt " .. attempts)
        sleep(2)
        self.host_id = rednet.lookup(PROTOCOL_CONTROL)
        attempts = attempts + 1
    end
    print("Control host found")
end

function gui:clean_write()
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

            -- make lower right light colored
            local parity = (i + j) % 2 == (GANTRY_N_PRIMARY_AXIS + GANTRY_N_SECONDARY_AXIS) % 2
            local color = colors.gray
            if parity then color = colors.lightGray end

            local x = i * width
            local y = j * height
            local square = self:drawBox(
                x + 1,
                y + 1,
                x + width - 1,
                y + height - 1,
                color,
                true)
            square.gantry_primary = primary
            square.gantry_secondary = secondary
            table.insert(squares, square)

            local at_square = gui:current_location_at(primary, secondary)
            if at_square and self.waiting_command then
                color = colors.green
            elseif self.selection_from ~= nil and self.selection_from.gantry_primary == primary and self.selection_from.gantry_secondary == secondary then
                color = colors.purple
            elseif self.selection_to ~= nil and self.selection_to.gantry_primary == primary and self.selection_to.gantry_secondary == secondary then
                color = colors.blue
            elseif at_square then
                color = colors.green
            end

            self:drawBox(
                x + 1,
                y + 1,
                x + width - 1,
                y + height - 1,
                color,
                false)
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, max_y - 3)
    if self.waiting_command then
        term.write("Waiting for previous command to finish...")
    elseif self.recent_command_info ~= nil then
        term.write(self.recent_command_info)
    else
        term.clearLine()
    end

    mode_change_box = gui:drawBox(1, max_y - 2, 17, max_y, colors.brown, true)
    term.setCursorPos(2, max_y - 1)
    term.write("Mode: " .. self.mode)
end

local function click_bound_check(box, x, y)
    return x >= box.startX and x <= box.endX and y >= box.startY and y <= box.endY
end

function gui:drawBox(startX, startY, endX, endY, color, filled)
    local box = {
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        color = color,
        bound_check = click_bound_check,
    }
    if filled then
        paintutils.drawFilledBox(box.startX, box.startY, box.endX, box.endY, color)
    else
        paintutils.drawBox(box.startX, box.startY, box.endX, box.endY, color)
    end
    return box
end

function gui:rednet_receive_loop()
    while true do
        local _id, message, protocol = rednet.receive()
        if message == nil then
            return
        elseif protocol == PROTOCOL_LOCATION then
            gui:parse_location_update(message)
            gui:clean_write()
        elseif protocol == PROTOCOL_CONTROL_ACK then
            local data = textutils.unserialize(message)
            if data.error ~= nil then
                self.recent_command_info = data.error
            elseif data.command == MODES.inspect or data.command == "read_contents" then
                self.recent_command_info = string.format("Spot %s %s has %s",
                    data.primary, data.secondary, data.contents)
            else
                self.recent_command_info = nil
            end
            self.waiting_command = false
            self.selection_from = nil
            self.selection_to = nil
            self:clean_write()
        end
    end
end

function gui:at_valid_location()
    return self.current_location.primary ~= nil and
        self.current_location.secondary ~= nil
end

function gui:parse_location_update(message)
    if message == nil then return end

    local _, primary = message:find("primary_")
    local _, secondary = message:find("secondary_")
    if primary then
        self.current_location.primary = tonumber(message:sub(primary + 1))
        -- print("primary at " .. self.current_location.primary)
    elseif secondary then
        self.current_location.secondary = tonumber(message:sub(secondary + 1))
        -- print("secondary at " .. self.current_location.secondary)
    end
end

function gui:current_location_at(primary, secondary)
    return self.current_location.primary == primary and self.current_location.secondary == secondary
end

local function request_location_update()
    print_term("Sending location broadcast")
    rednet.broadcast("update_location", PROTOCOL_LOCATION)
end

function gui:gui_loop()
    while true do
        self:clean_write()
        local _event, _side, x, y = os.pullEvent("monitor_touch")

        if mode_change_box:bound_check(x, y) then
            if self.mode == MODES.inspect then
                self.mode = MODES.transport
            else
                self.mode = MODES.inspect
            end
        end
        local touched_square = nil
        for _, square in ipairs(squares) do
            if square:bound_check(x, y) then
                touched_square = square
            end
        end
        if touched_square ~= nil and not self.waiting_command then
            local at_touched_square = self:current_location_at(touched_square.gantry_primary,
                touched_square.gantry_secondary)

            if self.mode == MODES.inspect then
                self.selection_from = nil
                self.selection_to = touched_square
                local command = {
                    command = self.mode,
                    primary = touched_square.gantry_primary,
                    secondary = touched_square.gantry_secondary,
                }
                self:send_command(command)
            elseif self.mode == MODES.move then
                self.selection_from = nil
                self.selection_to = touched_square
                local command = {
                    command = MODES.move,
                    primary = touched_square.gantry_primary,
                    secondary = touched_square.gantry_secondary,
                }
                self:send_command(command)
            elseif self.mode == MODES.transport then
                if self.selection_from == nil then
                    self.selection_from = touched_square
                else
                    self.selection_to = touched_square
                    local command = {
                        command = self.mode,
                        fp = self.selection_from.gantry_primary,
                        fs = self.selection_from.gantry_secondary,
                        tp = self.selection_to.gantry_primary,
                        ts = self.selection_to.gantry_secondary,
                    }
                    self:send_command(command)
                end
            end
        end
    end
end

function gui:send_command(command)
    local data = textutils.serialize(command)
    rednet.send(self.host_id, data, PROTOCOL_CONTROL)
    self.waiting_command = true
end

local function gui_loop()
    gui:gui_loop()
end

local function rednet_receive_loop()
    gui:rednet_receive_loop()
end

gui:init_rednet()
parallel.waitForAll(gui_loop, rednet_receive_loop, request_location_update)
