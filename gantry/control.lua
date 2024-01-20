-- clockwise input into gearshift
SIDE_AXIS_CONTROL = "back"
SIDE_THROTTLE = "left" -- redstone enabled means double speed
SIDE_STICKER = "right"
SIDE_GEARSHIFT = "top"
SIDE_HEAD_CLUTCH = "front"

SECONDARY_AXIS_POWER_LEVEL = 2

PISTON_DEBOUNCE = 0.8
STICKER_DEBOUNCE = 0.20

local SIDE_MODEM = "bottom"
PROTOCOL_CONTROL = "gantry_control"
PROTOCOL_CONTROL_ACK = "gantry_control_ack"

local firmware = require("firmware")

local control = {
    holding = nil,
}

function control:init()
    print("Initializing...")

    rednet.open(SIDE_MODEM)
    rednet.host(PROTOCOL_CONTROL, "gantry0_control")

    for _, side in pairs(redstone.getSides()) do
        -- Stop axis movement, reset everything else
        local enable = side == SIDE_AXIS_CONTROL
        redstone.setOutput(side, enable)
    end

    firmware:request_location_update()

    print("Checking if payload is attached")
    firmware:lower_piston()
    self:init_check_head()

    if not firmware:at_valid_location() then
        print("Bad location, resetting")
        firmware:reset_location()
    end
end

function control:init_check_head(second_check)
    local status = firmware:get_head_status()
    if status:find("error") then
        print("Error: head returned " .. status)
        error()
    elseif status == "none" and not second_check then
        print("No payload, making sure sticker is disabled")
        firmware:raise_piston()
        firmware:lower_piston()
        self:init_check_head(true)
    elseif status == "none" and second_check then
        print("Sticker clean")
    elseif second_check then
        print("Payload still attached, cycling again")
        firmware:raise_piston()
        firmware:toggle_sticker()
        firmware:lower_piston()
    else
        print("Found " .. status .. " on head")
        if not firmware:at_valid_location() then
            print("Location bad, but have payload. Moving to 0 0.")
            firmware:reset_location()
            self:init_check_head(true)
        else
            print("Location good, unsticking.")
            firmware:raise_piston()
            firmware:toggle_sticker()
            firmware:lower_piston()
            self:init_check_head(true)
        end
    end
end

function control:transport_from_to(fp, fs, tp, ts, paranoid)
    if paranoid == nil then paranoid = true end

    local destination_contents = self:read_spot_contents(tp, ts)
    if destination_contents == "unknown" then
        if paranoid then
            print("Don't know if destination is occupied, going to check")
            firmware:move_to(tp, ts)
            control:inspect_spot()
            self:transport_from_to(fp, fs, tp, ts, false)
        else
            self:transport_from_to_unchecked(fp, fs, tp, ts)
        end
    elseif destination_contents == "none" then
        self:transport_from_to_unchecked(fp, fs, tp, ts)
    else
        print("Destination is already occupied by " .. destination_contents .. ", cannot transport")
        error()
    end
end

function control:transport_from_to_unchecked(fp, fs, tp, ts)
    firmware:move_to(fp, fs)
    self:grab()

    firmware:move_to(tp, ts)
    self:release()
end

function control:grab()
    firmware:raise_piston()
    local status = firmware:get_head_status()
    if status:find("error") then
        print("Can't grab here because of error head status " .. status)
        firmware:lower_piston()
        error()
    elseif status == "none" then
        print("Warning: grabbing nothing")
        self.holding = nil
    else
        print("Grabbing " .. status)
        self.holding = status
    end
    firmware:toggle_sticker()
    firmware:lower_piston()
    self:write_spot_contents("none")
end

function control:release()
    firmware:raise_piston()
    firmware:toggle_sticker()
    firmware:lower_piston()
    self:write_spot_contents(self.holding or "none")
    self.holding = nil
end

function control:inspect_spot()
    firmware:raise_piston()
    local status = firmware:get_head_status()

    print(string.format("Found %s at %s %s", status,
        firmware.current_location.primary,
        firmware.current_location.secondary))
    firmware:lower_piston()
    self:write_spot_contents(status)

    return status
end

function control:write_spot_contents(contents, primary, secondary)
    if primary == nil then primary = firmware.current_location.primary end
    if secondary == nil then secondary = firmware.current_location.secondary end

    local path = self:get_state_file_path(primary, secondary)
    local file = fs.open(path, "w")
    file.write(contents)
    file.close()
end

function control:read_spot_contents(primary, secondary)
    local path = self:get_state_file_path(primary, secondary)
    if fs.exists(path) then
        local file = fs.open(path, "r")
        local contents = file.readAll()
        file.close()
        return contents
    else
        return "unknown"
    end
end

function control:get_state_file_path(primary, secondary)
    return "/grid_state/" .. primary .. "/" .. secondary
end

function control:host_control_rpc()
    print("Waiting for control commands")
    while true do
        local _id, message = rednet.receive(PROTOCOL_CONTROL)
        if message == nil then
            print("Exiting control listen loop")
            return
        end
        print()
        print(message)
        local data = textutils.unserialize(message)
        if data.command == "move_to" then
            firmware:move_to(data.primary, data.secondary)
            rednet.broadcast(message, PROTOCOL_CONTROL_ACK)
        elseif data.command == "transport" then
            local destination_contents = self:read_spot_contents(data.tp, data.ts)
            if destination_contents ~= "none" and destination_contents ~= "unknown" then
                data.error = string.format("Cannot transport to %s %s, occupied by %s",
                    data.tp, data.ts, destination_contents)
                rednet.broadcast(textutils.serialize(data), PROTOCOL_CONTROL_ACK)
            else
                self:transport_from_to(data.fp, data.fs, data.tp, data.ts)
                rednet.broadcast(message, PROTOCOL_CONTROL_ACK)
            end
        elseif data.command == "inspect" then
            if data.primary ~= nil and data.secondary ~= nil then
                firmware:move_to(data.primary, data.secondary)
            end
            data.contents = self:inspect_spot()
            data.primary = firmware.current_location.primary
            data.secondary = firmware.current_location.secondary
            rednet.broadcast(textutils.serialize(data), PROTOCOL_CONTROL_ACK)
        elseif data.command == "read_contents" then
            data.contents = self:read_spot_contents(data.primary, data.secondary)
            rednet.broadcast(textutils.serialize(data), PROTOCOL_CONTROL_ACK)
        end
    end
end

control:init()
control:host_control_rpc()
