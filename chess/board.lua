local Board = {}
local Piece = require("chess/piece")

function Board.new()
    local b = {
        data = {}
    }
    return setmetatable(b, { __index = Board })
end

function Board:to_string()
    local str = ""
    for rank = 8, 1, -1 do
        for file = 1, 8 do
            local piece = self.data[Board.index(file, rank)]
            local c = piece and piece:to_char() or " "
            str = str .. c
        end
        str = str .. "\n"
    end

    return str
end

function Board.index(file, rank)
    return file + ((rank - 1) * 8)
end

return Board
