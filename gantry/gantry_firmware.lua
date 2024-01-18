PROTOCOL_LOCATION = "gantry_location"
PROTOCOL_HEAD = "gantry_head"

local firmware = {
    current_location = {
        primary = nil,
        secondary = nil,
    },
    moving_to = {
        primary = nil,
        secondary = nil,
        axis = nil,
    },
}

function firmware:get_head_status()
    for i = 0, 10, 1 do
        rednet.broadcast("get_head_status", PROTOCOL_HEAD)
        local id, message = rednet.receive(PROTOCOL_HEAD, 1)
        if message ~= nil then
            return message
        end
    end
    print("Error: head not responding to status request")
    error()
end

function firmware:set_high_speed(enable)
    if enable == nil then enable = true end
    redstone.setOutput(SIDE_THROTTLE, enable)
end

function firmware:can_go_fast()
    if self.moving_to.axis == nil
        or self.current_location.primary == nil
        or self.current_location.secondary == nil then
        return true
    end
    local distance = math.abs(self.moving_to[self.moving_to.axis] - self.current_location[self.moving_to.axis])
    return distance > 1
end

function firmware:at_valid_location()
    return self.current_location.primary ~= nil and
        self.current_location.secondary ~= nil
end

function firmware:move_to(primary, secondary)
    print()
    print("moving to " .. primary .. ", " .. secondary)
    self.moving_to.primary = primary
    self.moving_to.secondary = secondary
    self:move_axis("primary", primary)
    self:move_axis("secondary", secondary)
end

function firmware:move_axis(axis, to)
    self.moving_to.axis = axis
    redstone.setOutput(SIDE_THROTTLE, self:can_go_fast())
    if to < self.current_location[axis] then
        if axis == "primary" then
            self:move_backward()
        else
            self:move_left()
        end
        self:wait_for_movement(axis, to)
    elseif to > self.current_location[axis] then
        if axis == "primary" then
            self:move_forward()
        else
            self:move_right()
        end
        self:wait_for_movement(axis, to)
    end
    self.moving_to.axis = nil
    self:halt_axis(axis)
end

function firmware:reset_location()
    print("Moving primary axis to 0")
    self:move_backward()
    self:wait_for_movement("primary", 0)

    print("Moving secondary axis to 0")
    self:move_left()
    self:wait_for_movement("secondary", 0)
end

function firmware:wait_for_movement(axis, target)
    while true do
        local _id, message = rednet.receive(PROTOCOL_LOCATION, 5)
        if message == nil then
            print("No message within timeout, sending broadcast")
            rednet.broadcast("update_location", PROTOCOL_LOCATION)
        else
            self:parse_location_update(message)
            local fast = self:can_go_fast()
            self:set_high_speed(fast)
            if message:find(axis .. "_" .. target) then
                self.moving_to[axis] = nil
                return true
            end
        end
    end
end

function firmware:request_location_update(timeout)
    if timeout == nil then timeout = 5 end

    print("Broadcasting to get current location")
    rednet.broadcast("update_location", PROTOCOL_LOCATION)
    while true do
        local _id, message = rednet.receive(PROTOCOL_LOCATION, timeout)
        if message == nil then
            return
        else
            self:parse_location_update(message)
        end
    end
end

function firmware:parse_location_update(message)
    if message == nil then return end

    local _, primary = message:find("primary_")
    local _, secondary = message:find("secondary_")
    if primary then
        self.current_location.primary = tonumber(message:sub(primary + 1))
        print("primary at " .. self.current_location.primary)
    elseif secondary then
        self.current_location.secondary = tonumber(message:sub(secondary + 1))
        print("secondary at " .. self.current_location.secondary)
    end
end

function firmware:move_forward()
    redstone.setOutput(SIDE_AXIS_CONTROL, false)
    redstone.setOutput(SIDE_GEARSHIFT, false)
end

function firmware:move_backward()
    redstone.setOutput(SIDE_AXIS_CONTROL, false)
    redstone.setOutput(SIDE_GEARSHIFT, true)
end

function firmware:move_left()
    redstone.setAnalogOutput(SIDE_AXIS_CONTROL, SECONDARY_AXIS_POWER_LEVEL - 1)
    redstone.setOutput(SIDE_GEARSHIFT, true)
end

function firmware:move_right()
    redstone.setAnalogOutput(SIDE_AXIS_CONTROL, SECONDARY_AXIS_POWER_LEVEL - 1)
    redstone.setOutput(SIDE_GEARSHIFT, false)
end

function firmware:halt_axis(axis)
    -- print("HALT " .. axis)
    if axis == "primary" then
        redstone.setAnalogOutput(SIDE_AXIS_CONTROL, SECONDARY_AXIS_POWER_LEVEL - 1)
    else
        redstone.setOutput(SIDE_AXIS_CONTROL, true)
    end
end

function firmware:raise_piston()
    self:set_high_speed(true)
    redstone.setOutput(SIDE_GEARSHIFT, true)
    redstone.setOutput(SIDE_HEAD_CLUTCH, true)
    sleep(PISTON_DEBOUNCE)
    redstone.setOutput(SIDE_HEAD_CLUTCH, false)
    sleep(PISTON_DEBOUNCE)
end

function firmware:lower_piston()
    self:set_high_speed(true)
    redstone.setOutput(SIDE_GEARSHIFT, false)
    redstone.setOutput(SIDE_HEAD_CLUTCH, true)
    sleep(PISTON_DEBOUNCE)
    redstone.setOutput(SIDE_HEAD_CLUTCH, false)
    sleep(PISTON_DEBOUNCE)
end

function firmware:toggle_sticker()
    sleep(STICKER_DEBOUNCE)
    redstone.setOutput(SIDE_STICKER, true)
    sleep(STICKER_DEBOUNCE)
    redstone.setOutput(SIDE_STICKER, false)
    sleep(STICKER_DEBOUNCE)
end

return firmware
