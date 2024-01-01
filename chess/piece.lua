local Role = require("chess/role")
local Color = require("chess/color")
local Piece = {
}

function Piece.from_char(ch)
    local color = nil
    local role = Role.from_char(ch)
    if role == nil then return nil end

    if ch == ch:upper() then
        color = Color.WHITE
    else
        color = Color.BLACK
    end

    local p = {
        role = role,
        color = color,
    }
    return setmetatable(p, { __index = Piece })
end

function Piece:to_char()
    if self.color == Color.WHITE then
        return string.upper(self.role)
    else
        return string.lower(self.role)
    end
end

return Piece
