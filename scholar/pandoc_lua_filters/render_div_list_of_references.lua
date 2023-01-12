local function is_references_container(
    div -- pandoc.Div
)
    return div.identifier == "references"
end


local function check_references_container(
    div -- pandoc.Div
)
    if #div.content > 0 then
        warn("References container isn't empty. Ignoring its content.")
    end
end


return {
    {
        Div = function (
            div -- pandoc.Div
        )
            if not is_references_container(div) then
                return div
            end

            check_references_container(div)

            local rendered_references = table.concat({
                "\\nocite{*}",
                "\\printbibliography[env=scholar,heading=none]",
            }, "\n")

            return pandoc.RawBlock("latex", rendered_references)
        end,
    }
}
