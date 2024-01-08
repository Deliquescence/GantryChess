local Fen = require("chess/fen")
local San = require("chess/san")
local Board = require("chess/board")

-- local parsed = Fen.parse("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b Qkq - 0 1")
local parsed = Fen.parse("5R1Q/8/4p1k1/8/4P1K1/r7/p7/r7 w - - 0 54")

-- print(textutils.serialize(parsed.board))
-- print(parsed.board)
-- print(parsed.board:to_string())

-- print(Board.index(1, 1))
-- print(Board.file(1))
-- print(Board.rank(1))
-- print()
-- print(Board.index(8, 8))
-- print(Board.file(64))
-- print(Board.rank(64))
-- print()
-- print(Board.index(7, 2))
-- print(Board.file(15))
-- print(Board.rank(15))

-- print(Board.square_name(64))

for s in Board.ray(24, 6) do
    print(Board.square_name(s))
end

-- print (San.parse_square("a1"))
-- print (San.parse_square("h8"))
-- print (San.parse_square("h7"))
-- print (San.parse_square("g8"))
