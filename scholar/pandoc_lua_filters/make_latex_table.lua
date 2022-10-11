local function make_table_spec_as_string()
    return "{c c}" -- FIXME: Replace dummy
end


local function make_table_head_as_blocks()
    return pandoc.Blocks({
        -- FIXME: ...
    })
end


local function make_table_foot_as_blocks()
    return pandoc.Blocks({
        -- FIXME: ...
    })
end


local function make_table_body_as_blocks()
    return pandoc.Blocks({
        -- FIXME: Replace dummy
        pandoc.RawBlock("latex", "a & b \\\\"),
        pandoc.RawBlock("latex", "c & d \\\\"),
    })
end


local function make_table_as_blocks(table_element)
    local blocks = pandoc.Blocks({})

    -- FIXME: Pass arguments to the builder functions
    blocks:insert(pandoc.RawBlock("latex", "\\begin{longtable}" .. make_table_spec_as_string()))
    blocks:extend(make_table_head_as_blocks())
    blocks:extend(make_table_foot_as_blocks())
    blocks:extend(make_table_body_as_blocks())
    blocks:insert(pandoc.RawBlock("latex", "\\end{longtable}"))

    return blocks
end


if FORMAT:match("latex") then
    return {
        {
            Table = make_table_as_blocks,
        }
    }
end
