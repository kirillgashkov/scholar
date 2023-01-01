local scholar_metadata = {}


local function load_scholar_metadata(
    meta -- pandoc.Meta
)
    scholar_metadata = meta.scholar
end


return {
    {
        Meta = function (meta)
            load_scholar_metadata(meta)
            return meta
        end,
    },
}
