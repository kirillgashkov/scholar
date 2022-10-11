local function table_cell_to_inlines(cell)
    local inlines = pandoc.Inlines({})

    if #cell.contents == 1 and cell.contents[1].tag == "Plain" then
        inlines = cell.contents[1].content -- "Plain.content" is "Inlines"
    else
        warn("table_cell_to_inlines: cell.contents is not a simple text block")
        -- TODO: Consider using pandoc.LineBreak as a separator
        inlines = pandoc.utils.blocks_to_inlines(cell.contents)
    end

    -- TODO: Consider returning a single pandoc.Span
    -- inline (check how Pandoc handles this)
    return inlines
end


local function table_row_to_block(table_row_el)
    local inlines = pandoc.Inlines({})

    -- FIXME: What if table_row_el.cells is empty or missing?
    inlines:extend(table_cell_to_inlines(table_row_el.cells[1]))
    for i = 2, #table_row_el.cells do
        inlines:insert(pandoc.Space())
        inlines:insert(pandoc.RawInline("latex", "&"))
        inlines:insert(pandoc.Space())
        inlines:extend(table_cell_to_inlines(table_row_el.cells[i]))
    end
    inlines:insert(pandoc.RawInline("latex", "\\\\"))

    -- TODO: Consider using pandoc.Span with
    -- pandoc.LineBreak instead of pandoc.Plain
    return pandoc.Plain(inlines)
end


local function table_spec_to_latex()
    return "{c c}" -- FIXME: Replace dummy
end


local function table_head_to_blocks()
    return pandoc.Blocks({
        -- FIXME: ...
    })
end


local function table_foot_to_blocks()
    return pandoc.Blocks({
        -- FIXME: ...
    })
end


local function table_body_to_blocks()
    return pandoc.Blocks({
        -- FIXME: Replace dummy
        table_row_to_block({cells = {
            {contents = {pandoc.Plain({pandoc.Str("a")})}},
            {contents = {pandoc.Plain({pandoc.Str("b")})}}
        }}),
        table_row_to_block({cells = {
            {contents = {pandoc.Plain({pandoc.Str("c")})}},
            {contents = {pandoc.Plain({pandoc.Str("d")})}}
        }}),
    })
end


local function table_to_blocks(table_el)
    --[[ Temporary debug prints
    if pandoc.utils.stringify(table_el) ~= "ti" then -- If not the aux table
        print("--------------------")
        -- "table_el.bodies[1].body[1]" selects a table row
        for k, v in pairs(table_el.bodies[1].body[1]) do
            print(k, v)
        end
        print("--------------------")
    end
    --]]

    local blocks = pandoc.Blocks({})

    -- FIXME: Pass arguments to the builder functions
    blocks:insert(pandoc.RawBlock("latex", "\\begin{longtable}" .. table_spec_to_latex()))
    blocks:extend(table_head_to_blocks())
    blocks:extend(table_foot_to_blocks())
    blocks:extend(table_body_to_blocks())
    blocks:insert(pandoc.RawBlock("latex", "\\end{longtable}"))

    return blocks
end


if FORMAT:match("latex") then
    return {
        {
            Table = table_to_blocks,
        }
    }
end
