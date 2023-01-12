local function is_list_of_references_div(
    div -- pandoc.Div
)
    return div.identifier == "list-of-references"
end


local function check_list_of_references_div(
    div -- pandoc.Div
)
    if #div.content > 0 then
        warn("'List of References' div isn't empty. Ignoring its content.")
    end
end


return {
    {
        Div = function (
            div -- pandoc.Div
        )
            if not is_list_of_references_div(div) then
                return div
            end

            check_list_of_references_div(div)

            local rendered_references = table.concat({
                "\\nocite{*}",
                "\\printbibliography[env=scholar,heading=none]",
            }, "\n")

            return pandoc.RawBlock("latex", rendered_references)
        end,
    }
}
