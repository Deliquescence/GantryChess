local fen = {}
-- local Square = require("square")
local Piece = require("chess/piece")
local Color = require("chess/color")
local Setup = require("chess/setup")
local Board = require("chess/board")


function fen.parse(str)
    if str == nil then return nil end
    local parts = string.split(str, " ")
    local ranks = parts[1]:split("/")
    if #parts < 1 then
        return nil, "need board data"
    end
    if #ranks ~= 8 then
        return nil, "expected 8 ranks, got " .. #ranks
    end

    local board = Board.new()
    for r = 1, 8 do
        local f = 1
        for c in ranks[r]:gmatch(".") do
            local p = Piece.from_char(c)
            if p ~= nil then
                board.data[Board.index(f, 9 - r)] = p
                f = f + 1
            elseif tonumber(c) then
                for _ = 1, c do
                    board.data[Board.index(f, 9 - r)] = nil
                    f = f + 1
                end
            end
        end
        if f > 9 then
            return nil, string.format("rank %s is too long (%s)", 9 - r, f - 1)
        end
    end

    local color = Color.from_char(parts[2]) or Color.WHITE
    local castling = parts[3]
    local castling_rights = Setup.CastlingRights(
        castling:find("K"),
        castling:find("Q"),
        castling:find("k"),
        castling:find("q")
    )
    local passant_target = parts[4]

    return {
        board = board,
        turn = color,
        castling_rights = castling_rights,
    }
end

-- http://lua-users.org/wiki/SplitJoin
function string:split(sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    ---@diagnostic disable-next-line: discard-returns, param-type-mismatch
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

return fen
