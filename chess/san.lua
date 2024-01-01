local Role = require("chess/role")
local Color = require("chess/color")
local Piece = require("chess/piece")
local Board = require("chess/board")

local San = {}

function San.parse_move(str)
    if str == nil then return nil end

    if str == "O-O" then
        return {
            kind = "castle",
            castle = "kingside",
        }
    elseif str == "O-O-O" then
        return {
            kind = "castle",
            castle = "queenside",
        }
    end

    local role = Role.from_char(string.sub(str, 1, 1)) or Role.PAWN
    local rank, file, capture, to, promotion
    i = 2
    if string.match(str[i] or "", "[a-h]") then
        file = str[i]
    end
end

function San.parse_square(str)
    if str == nil or #str ~= 2 then
        return nil
    end

    local file = San.parse_file(string.sub(str, 1, 1))
    local rank = San.parse_rank(string.sub(str, 2, 2))
    if file == nil or rank == nil then
        return nil
    end

    return Board.index(file, rank)
end

function San.parse_file(char)
    local file = string.match(char or "", "[a-h]")
    if file == nil then return nil end
    return string.byte(file) - string.byte("a") + 1
end

function San.parse_rank(char)
    local rank = string.match(char or "", "[1-8]")
    if rank == nil then return nil end
    return string.byte(rank) - string.byte("1") + 1
end

return San
