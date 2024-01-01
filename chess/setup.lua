local Setup = {}

function Setup.new(board, turn, castling_rights, passant_target)
    local s = {
        board = board,
        turn = turn,
        castling_rights = castling_rights,
        passant_target = passant_target,
    }
    return setmetatable(s, { __index = Setup })
end

function Setup.CastlingRights(white_kingside, white_queenside, black_kingside, black_queensize)
    return {
        white = {
            kingside = white_kingside and true or false,
            queenside = white_queenside and true or false,
        },
        black = {
            kingside = black_kingside and true or false,
            queenside = black_queensize and true or false,
        },
    }
end

return Setup
