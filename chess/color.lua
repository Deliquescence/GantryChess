local Color = {
    WHITE = "white",
    BLACK = "black",
}

function Color.from_char(ch)
    if ch == "w" then
        return Color.WHITE
    elseif ch == "b" then
        return Color.BLACK
    else
        return nil
    end
end

-- function Color.Black()
--     return setmetatable({ color = "black" }, Color)
-- end

-- function Color.White()
--     return setmetatable({ color = "white" }, Color)
-- end

return Color
