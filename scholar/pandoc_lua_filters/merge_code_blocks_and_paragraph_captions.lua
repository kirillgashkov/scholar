local function load_settings(
    meta_el -- pandoc.Meta
)
end

local function merge_code_blocks_and_paragraph_captions(
    blocks_el -- pandoc.Blocks
)
end

return {
    {
        Meta = function (meta_el)
            load_settings(meta_el)
            return meta_el
        end,
    },
    {
        Blocks = function (blocks_el)
            merge_code_blocks_and_paragraph_captions(blocks_el)
            return blocks_el
        end
    },
}
