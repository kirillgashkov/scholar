LISTING_PREFIXES = {
    ":",
    "Listing:",
}

local function print_table(
    t -- table
)
    for k, v in pairs(t) do
        print(k, v)
    end
end

local function load_settings(
    meta_el -- pandoc.Meta
)
    LISTING_PREFIXES = (
        meta_el.scholar
        and meta_el.scholar.paragraph_caption
        and meta_el.scholar.paragraph_caption.listing_prefixes
        or LISTING_PREFIXES
    )
end

local function is_code_block(
    block -- pandoc.Block
)
    return block.t == "CodeBlock"
end

local function match_listing_prefix(
    text -- string
)
    for _, prefix in ipairs(LISTING_PREFIXES) do
        if text:sub(1, #prefix) == prefix then
            return prefix
        end
    end

    return nil
end

local function is_paragraph_caption(
    block -- pandoc.Block
)
    if block.t ~= "Para" then
        return false
    end

    local first_inline = block.content[1]

    if first_inline.t ~= "Str" then
        return false
    end

    if match_listing_prefix(first_inline.text) == nil then
        return false
    end

    return true
end

local function parse_paragraph_caption(
    para_caption_el -- pandoc.Para
)
    local inlines = para_caption_el.content:clone()

    local first_inline = inlines[1]
    local prefix = match_listing_prefix(first_inline.text)

    if #prefix == #first_inline.text then
        inlines:remove(1)

        while inlines[1].t == "Space" do
            inlines:remove(1)
        end
    else
        inlines[1].text = first_inline.text:sub(#prefix + 1)
    end

    local last_inline = inlines[#inlines]

    local identifier = nil
    local classes = nil
    local attributes = nil

    if last_inline.t == "Span" then
        identifier = last_inline.identifier
        classes = last_inline.classes
        attributes = last_inline.attributes

        if #last_inline.content > 0 then
            io.stderr:write(
                "Warning: Last span in paragraph caption contains inline elements. Ignoring them.\n"
            )
        end

        inlines:remove(#inlines)
    end

    return {
        caption = inlines,
        identifier = identifier,
        classes = classes,
        attributes = attributes
    }
end


local function merge_code_block_and_paragraph_caption(
    code_block_el, -- pandoc.CodeBlock
    para_caption_el -- pandoc.Para
)
    local parsed = parse_paragraph_caption(para_caption_el)

    local caption = parsed.caption
    local identifier = parsed.identifier
    local classes = parsed.classes
    local attributes = parsed.attributes

    if identifier ~= nil and identifier ~= "" then
        if code_block_el.identifier ~= "" then
            io.stderr:write("Warning: Code block already has an identifier. Overwriting it.\n")
        end

        code_block_el.identifier = identifier
    end

    if classes ~= nil then
        code_block_el.classes:extend(classes)
    end

    if caption ~= nil then
        if code_block_el.attributes["caption"] ~= nil then
            io.stderr:write("Warning: Code block already has a caption. Renderers will decide how to handle this.\n")
        end

        code_block_el.attributes["caption_json"] = pandoc.write(
            pandoc.Pandoc({caption}), "json"
        )
    end

    if attributes ~= nil then
        for k, v in pairs(attributes) do
            code_block_el.attributes[k] = v
        end
    end
end


local function merge_code_blocks_and_paragraph_captions(
    blocks_el -- pandoc.Blocks
)
    for i = #blocks_el-1, 1, -1 do
        local block = blocks_el[i]
        local next_block = blocks_el[i + 1]

        if is_code_block(block) and is_paragraph_caption(next_block) then
            merge_code_block_and_paragraph_caption(block, next_block)
            blocks_el:remove(i + 1)
        end
    end

    for i = 2, #blocks_el do
        local block = blocks_el[i]
        local prev_block = blocks_el[i - 1]

        if is_code_block(block) and is_paragraph_caption(prev_block) then
            merge_code_block_and_paragraph_caption(block, prev_block)
            blocks_el:remove(i - 1)
        end
    end
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
