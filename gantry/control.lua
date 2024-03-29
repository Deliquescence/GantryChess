local config = require("config").control

local firmware = require("firmware")

local control = {
    holding = nil,
}

function control:init()
    -- Try and stop movement as soon as possible to avoid chunk shearing gantry shaft
    redstone.setOutput(config.SIDE_AXIS_CONTROL, true)
    print("Initializing...")

    rednet.open(config.SIDE_MODEM)
    rednet.host(PROTOCOL_CONTROL, "gantry0_control")

    for _, side in pairs(redstone.getSides()) do
        -- Stop axis movement, reset everything else
        local enable = side == config.SIDE_AXIS_CONTROL
        redstone.setOutput(side, enable)
    end

    firmware:request_location_update()

    print("Checking if payload is attached")
    firmware:lower_piston()
    self:init_check_head()
    self:inspect_spot()

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
        if firmware:at_valid_location() then
            print("Location good")
            local saved_contents = self:read_spot_contents(firmware.current_location.primary,
                firmware.current_location.secondary)
            if saved_contents == "none" then
                print("Don't think there's anything in this spot, unsticking")
                firmware:raise_piston()
                firmware:toggle_sticker()
                firmware:lower_piston()
                return self:init_check_head(true)
            else
                print("Something may already be here")
            end
        else
            print("Location bad, but have payload.")
            firmware:reset_location()
        end

        local safe_primary, safe_secondary = self:find_empty_spot()
        if safe_primary == nil then
            print("Nowhere safe to put payload, apparently")
            error()
        end
        print("Should be able to place at " .. safe_primary .. " " .. safe_secondary)
        firmware:move_to(safe_primary, safe_secondary)
        self:init_check_head(true)
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
    local lower_status = firmware:get_head_status()
    if lower_status == "none" and status ~= "none" then
        print("Sticker toggle was in wong state, need to grab again")
        return control:grab()
    end
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
    local lower_status = firmware:get_head_status()
    if lower_status ~= "none" then
        print("Sticker toggle was in wong state, need to release " .. lower_status)
        firmware:toggle_sticker()
        return control:inspect_spot()
    end
    self:write_spot_contents(status)

    return status
end

function control:write_spot_contents(contents, primary, secondary)
    if primary == nil then primary = firmware.current_location.primary end
    if secondary == nil then secondary = firmware.current_location.secondary end
    if not primary or not secondary then
        return
    end

    local path = self:get_state_file_path(primary, secondary)
    local file = fs.open(path, "w")
    file.write(contents)
    file.close()
end

function control:read_spot_contents(primary, secondary)
    if not primary or not secondary then
        return "unknown"
    end
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

function control:find_empty_spot(allow_unknown)
    for s = 0, GANTRY_N_SECONDARY_AXIS do
        for p = 0, GANTRY_N_PRIMARY_AXIS do
            local contents = self:read_spot_contents(p, s)
            if contents == "none" then
                return p, s
            elseif contents == "unknown" and allow_unknown then
                return p, s
            end
        end
    end
    if allow_unknown then
        return nil
    else
        return self:find_empty_spot(true)
    end
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

if pcall(debug.getlocal, 4, 1) then
    -- print("in package")
    return control
else
    -- print("in main script")
    control:init()
    control:host_control_rpc()
end
