local Role = {
    PAWN = "p",
    KNIGHT = "n",
    BISHOP = "b",
    ROOK = "r",
    QUEEN = "q",
    KING = "k",
}

function Role.from_char(ch)
    if ch == "P" or ch == "p" then
        return Role.PAWN
    elseif ch == "N" or ch == "n" then
        return Role.KNIGHT
    elseif ch == "B" or ch == "b" then
        return Role.BISHOP
    elseif ch == "R" or ch == "r" then
        return Role.ROOK
    elseif ch == "Q" or ch == "q" then
        return Role.QUEEN
    elseif ch == "K" or ch == "k" then
        return Role.KING
    end
end

-- function Role.Pawn()
--     return setmetatable({ role = "pawn" }, Role)
-- end

-- function Role.Knight()
--     return setmetatable({ role = "knight" }, Role)
-- end

-- function Role.Bishop()
--     return setmetatable({ role = "bishop" }, Role)
-- end

-- function Role.Rook()
--     return setmetatable({ role = "rook" }, Role)
-- end

-- function Role.Queen()
--     return setmetatable({ role = "queen" }, Role)
-- end

-- function Role.King()
--     return setmetatable({ role = "king" }, Role)
-- end

function Role:of(color)
    return {
        role = self.role,
        color = self.color,
    }
end

return Role
