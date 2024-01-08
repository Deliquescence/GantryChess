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

function Board.file_name(file)
    return string.char(string.byte("a") + file - 1)
end

function Board.square_name(index)
    local file = Board.file(index)
    local rank = Board.rank(index)
    return Board.file_name(file) .. rank
end

function Board.index(file, rank)
    return file + ((rank - 1) * 8)
end

function Board.file(index)
    return bit.band(index - 1, 7) + 1
end

function Board.rank(index)
    return bit.brshift(index - 1, 3) + 1
end

local function signum(i)
    if i < 0 then
        return -1
    elseif i > 0 then
        return 1
    else
        return 0
    end
end

-- from exclusive, to inclusive
function Board.ray(from, to)
    local ffile = Board.file(from)
    local frank = Board.rank(from)
    local tfile = Board.file(to)
    local trank = Board.rank(to)
    local file = ffile
    local rank = frank

    return function()
        local horizontal = tfile - file
        local vertical = trank - rank
        if math.abs(horizontal) ~= math.abs(vertical) and horizontal ~= 0 and vertical ~= 0 then
            return
        end
        if file == tfile and rank == trank then
            return
        end

        file = file + signum(horizontal)
        rank = rank + signum(vertical)
        return Board.index(file, rank)
    end
end

return Board
