local function is_table_of_contents_div(
    div -- pandoc.Div
)
    return div.identifier == "table-of-contents"
end


local function check_table_of_contents_div(
    div -- pandoc.Div
)
    if #div.content > 0 then
        warn("'Table of Contents' div isn't empty. Ignoring its content.")
    end
end


return {
    {
        Div = function (
            div -- pandoc.Div
        )
            if not is_table_of_contents_div(div) then
                return div
            end

            check_table_of_contents_div(div)

            local rendered = table.concat({
                "\\makeatletter",
                "\\scholar@tableofcontents",
                "\\makeatother",
            }, "\n")

            return pandoc.RawBlock("latex", rendered)
        end,
    }
}
