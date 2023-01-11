local function has_value(arr, val)
    for _, value in ipairs(arr) do
        if value == val then
            return true
        end
    end
    return false
end

return {
    {
        Header = function (
            header -- pandoc.Header
        )
            if not has_value(header.classes, "tocless") then
                return nil
            end

            local blocks = pandoc.Blocks({})

            blocks:insert(pandoc.RawBlock("latex", table.concat({
                "\\makeatletter",
                "\\begin{scholar@tocless}",
                "\\makeatother",
            }, "")))

            blocks:insert(header)

            blocks:insert(pandoc.RawBlock("latex", table.concat({
                "\\makeatletter",
                "\\end{scholar@tocless}",
                "\\makeatother",
            }, "")))

            return blocks
        end,
    }
}
