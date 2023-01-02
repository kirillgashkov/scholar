local function is_citation(
    link -- pandoc.Link
)
    return link.content == pandoc.Inlines({pandoc.Str("@")})
end


local function validate_citation(
    link -- pandoc.Link
)
    if link.target:sub(1, 1) ~= "#" then
        error("Citation target doesn't start with '#': " .. link.target)
    end
end


local function citation_to_citation_id(
    link -- pandoc.Link
)
    return link.target:sub(2)
end


return {
    {
        Link = function (
            link -- pandoc.Link
        )
            if not is_citation(link) then
                return link
            end

            validate_citation(link)

            return pandoc.RawInline(
                "latex",
                "\\cite{" .. citation_to_citation_id(link) .. "}"
            )
        end,
    }
}
