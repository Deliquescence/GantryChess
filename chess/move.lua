local Move = {
    KINDS = {
        Normal = "Normal",
        EnPassant = "EnPassant",
        Castle = "Castle",
    }
}

function Move.Normal(role, from, capture, to, promotion)
    local move = {
        role = role,
        from = from,
        capture = capture,
        to = to,
        promotion = promotion,
        kind = Move.KINDS.Normal,
    }
    return move
end

function Move.EnPassant(from, to)
    local move = {
        from = from,
        to = to,
        kind = Move.KINDS.EnPassant,
    }
    return move
end

function Move.Castle(king, rook)
    local move = {
        king = king,
        rook = rook,
        kind = Move.KINDS.Castle,
    }
    return move
end

return Move
