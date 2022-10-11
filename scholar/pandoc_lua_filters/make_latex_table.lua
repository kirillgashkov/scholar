local function make_table_cell_as_inlines(cell)
    local inlines = pandoc.Inlines({})

    if #cell.contents == 1 and cell.contents[1].tag == "Plain" then
        inlines = cell.contents[1].content -- "Plain.content" is "Inlines"
    else
        warn("make_table_cell_as_inlines: cell.contents is not a simple text block")
        -- TODO: Consider using pandoc.LineBreak as separator
        inlines = pandoc.utils.blocks_to_inlines(cell.contents)
    end

    return inlines
end


local function make_table_row_as_block(cells)
    local inlines = pandoc.Inlines({})

    inlines:extend(make_table_cell_as_inlines(cells[1]))
    for i = 2, #cells do
        inlines:insert(pandoc.Space())
        inlines:insert(pandoc.RawInline("latex", "&"))
        inlines:insert(pandoc.Space())
        inlines:extend(make_table_cell_as_inlines(cells[i]))
    end
    inlines:insert(pandoc.RawInline("latex", "\\\\"))

    -- TODO: Consider using pandoc.Span with
    -- pandoc.LineBreak instead of pandoc.Plain
    return pandoc.Plain(inlines)
end


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
        make_table_row_as_block({
            {contents = {pandoc.Plain({pandoc.Str("a")})}},
            {contents = {pandoc.Plain({pandoc.Str("b")})}}
        }),
        make_table_row_as_block({
            {contents = {pandoc.Plain({pandoc.Str("c")})}},
            {contents = {pandoc.Plain({pandoc.Str("d")})}}
        }),
        make_table_row_as_block({
            {contents = {pandoc.Plain({pandoc.Str("e")})}},
            {contents = {pandoc.Plain({pandoc.Str("f")})}}
        }),
    })
end


local function make_table_as_blocks(table_element)
    --[[ Temporary debug prints
    print("--------------------")
    for k, v in pairs(table_element) do
        print(k, v)
    end
    print("--------------------")
    --]]

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
