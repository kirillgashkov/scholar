local function is_reference(
    link -- pandoc.Link
)
    return link.content == pandoc.Inlines({pandoc.Str("#")})
end


local function validate_reference(
    link -- pandoc.Link
)
    if link.target:sub(1, 1) ~= "#" then
        error("Reference target doesn't start with '#': " .. link.target)
    end
end


local function reference_to_reference_id(
    link -- pandoc.Link
)
    return link.target:sub(2)
end


return {
    {
        Link = function (
            link -- pandoc.Link
        )
            if not is_reference(link) then
                return link
            end

            validate_reference(link)

            return pandoc.RawInline(
                "latex",
                "\\ref{" .. reference_to_reference_id(link) .. "}"
            )
        end,
    }
}
