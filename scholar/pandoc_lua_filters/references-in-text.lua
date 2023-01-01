local scholar_metadata = {}


local function load_scholar_metadata(
    meta -- pandoc.Meta
)
    scholar_metadata = meta.scholar or {}
end


local function is_reference(
    link -- pandoc.Link
)
    return link.content == pandoc.Inlines({pandoc.Str("@")})
end


local function validate_reference(
    link -- pandoc.Link
)
    if link.target:sub(1, 1) ~= "#" then
        error("Reference target must start with '#'.")
    end
end


local function is_reference_citation(
    link -- pandoc.Link
)
    local references = scholar_metadata.references or {}
    return references[link.target:sub(2)] ~= nil
end


local function reference_to_reference_id(
    link -- pandoc.Link
)
    return link.target:sub(2)
end


local function reference_to_latex_cite_inline(
    link -- pandoc.Link
)
    return pandoc.RawInline(
        "latex",
        "\\cite{" .. reference_to_reference_id(link) .. "}"
    )
end


local function reference_to_latex_ref_inline(
    link -- pandoc.Link
)
    return pandoc.RawInline(
        "latex",
        "\\ref{" .. reference_to_reference_id(link) .. "}"
    )
end


return {
    {
        Meta = function (meta)
            load_scholar_metadata(meta)
            return meta
        end,
    },
    {
        Link = function (
            link -- pandoc.Link
        )
            if not is_reference(link) then
                return link
            end

            validate_reference(link)

            if is_reference_citation(link) then
                return reference_to_latex_cite_inline(link)
            else
                return reference_to_latex_ref_inline(link)
            end
        end,
    }
}
