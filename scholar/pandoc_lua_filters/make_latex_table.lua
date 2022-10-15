local function latex_to_inline(latex)
    return pandoc.RawInline("latex", latex)
end

local function latex_to_block(latex)
    return pandoc.RawBlock("latex", latex)
end

--

local function vrule_latex(thickness)
    return "!{\\vrule width " .. thickness .. "}"
end

local function hrule_latex(thickness)
    return "\\specialrule{" .. thickness .. "}{0pt}{0pt}"
end

--

local function table_cell_to_inlines(cell_el)
    local inlines = pandoc.Inlines({})

    -- FIXME: What if
    -- 1. cell_el.contents is missing/inaccessible?
    -- 2. cell_el.contents[1] is missing/inaccessible?
    -- 3. cell_el.contents[1].tag is missing/inaccessible?
    -- 4. cell_el.contents[1].content is missing/inaccessible?
    if #cell_el.contents == 1 and cell_el.contents[1].tag == "Plain" then
        inlines = cell_el.contents[1].content -- "Plain.content" is "Inlines"
    else
        warn("table_cell_to_inlines: cell.contents is not a simple text block")
        -- TODO: Consider using pandoc.LineBreak as a separator
        inlines = pandoc.utils.blocks_to_inlines(cell_el.contents)
    end

    -- TODO: Consider returning a single pandoc.Span
    -- inline (check how Pandoc handles this)
    return inlines
end

local function table_row_to_block(row_el)
    local inlines = pandoc.Inlines({})

    -- FIXME: What if
    -- 1. row_el.cells is missing/inaccessible?
    -- 2. row_el.cells[1] is missing/inaccessible (e.g. list is empty)?
    -- 3. row_el.cells[i] is missing/inaccessible?
    inlines:extend(table_cell_to_inlines(row_el.cells[1]))
    for i = 2, #row_el.cells do
        inlines:insert(pandoc.Space())
        inlines:insert(pandoc.RawInline("latex", "&"))
        inlines:insert(pandoc.Space())
        inlines:extend(table_cell_to_inlines(row_el.cells[i]))
    end
    inlines:insert(pandoc.Space())
    inlines:insert(pandoc.RawInline("latex", "\\\\"))

    -- TODO: Consider using pandoc.Span with
    -- pandoc.LineBreak instead of pandoc.Plain
    return pandoc.Plain(inlines)
end

-- Table colspecs

local function table_colspecs_to_simple_latex_column_descriptors(colspec_els)
    local latex_column_descriptors = pandoc.List({})

    for _, colspec_el in ipairs(colspec_els) do
        local alignment = colspec_el[1]

        if alignment == "AlignLeft" then
            latex_column_descriptors:insert("l")
        elseif alignment == "AlignRight" then
            latex_column_descriptors:insert("r")
        elseif alignment == "AlignCenter" then
            latex_column_descriptors:insert("c")
        elseif alignment == "AlignDefault" then
            latex_column_descriptors:insert("l")
        end
    end

    return latex_column_descriptors
end

local function table_colspecs_to_complex_latex_column_descriptors(colspec_els)
    local latex_column_descriptors = pandoc.List({})

    for _, colspec_el in ipairs(colspec_els) do
        local alignment = colspec_el[1]
        local width = colspec_el[2] or 0

        local latex_alignment_command
        if alignment == "AlignLeft" then
            latex_alignment_command = "\\raggedright"
        elseif alignment == "AlignRight" then
            latex_alignment_command = "\\raggedleft"
        elseif alignment == "AlignCenter" then
            latex_alignment_command = "\\centering"
        elseif alignment == "AlignDefault" then
            latex_alignment_command = "\\raggedright"
        end

        -- "\columnwidth - {#colspec_els * 2}\tabcolsep" is the width of the
        -- table minus the width of every cell's left and right paddings
        latex_column_descriptors:insert(">{" .. latex_alignment_command .. "\\arraybackslash}" .. "p{(\\columnwidth - " .. string.format("%d", #colspec_els * 2) .. "\\tabcolsep) * \\real{" .. string.format("%.4f", width) .. "}}")
    end

    return latex_column_descriptors
end

local function table_colspecs_to_latex(colspec_els)
    local default_widths_only = true
    for _, colspec_el in ipairs(colspec_els) do
        if colspec_el[2] ~= nil then
            default_widths_only = false
            break
        end
    end

    local latex_column_descriptors = pandoc.List({})
    if default_widths_only then
        latex_column_descriptors = table_colspecs_to_simple_latex_column_descriptors(colspec_els)
    else
        latex_column_descriptors = table_colspecs_to_complex_latex_column_descriptors(colspec_els)
    end

    -- FIXME: What if latex_column_descriptors is empty?
    local latex_colspecs = "{" .. vrule_latex("1pt")
    for i = 1, #latex_column_descriptors - 1 do
        latex_colspecs = latex_colspecs .. latex_column_descriptors[i] .. vrule_latex("0.5pt")
    end
    latex_colspecs = latex_colspecs .. latex_column_descriptors[#latex_column_descriptors] .. vrule_latex("1pt") .. "}"
    
    return latex_colspecs
end

-- Table head to blocks

local function table_caption_to_main_caption_block(
    caption_el, -- pandoc.Caption
    table_id -- string
)
    -- TODO: Implement
end

local function table_caption_to_continuation_caption_block(
    caption_el, -- pandoc.Caption
    table_id -- string
)
    -- TODO: Implement
end

local function table_head_to_table_rows(
    head_el -- pandoc.TableHead
)
    return head_el.rows
end

local function table_head_to_content_blocks(
    head_el -- pandoc.TableHead
)
    local blocks = pandoc.Blocks({})

    for i, row_el in ipairs(table_head_to_table_rows(head_el)) do
        if i == 1 then
            blocks:insert(latex_to_block(hrule_latex("1pt")))
        end
        blocks:insert(table_row_to_block(row_el))
        blocks:insert(latex_to_block(hrule_latex("0.5pt")))
    end

    return blocks
end

local function is_table_caption_empty(
    caption_el -- pandoc.Caption
)
    return #caption_el.long == 0 and caption_el.short == nil
end

local function is_table_id_empty(
    identifier -- string
)
    return identifier == ""
end

local function table_head_to_blocks(
    head_el, -- pandoc.TableHead
    table_caption_el, -- pandoc.Caption
    table_id -- string
)
    local blocks = pandoc.Blocks({})

    local content_blocks = table_head_to_content_blocks(head_el)
    local has_caption = not is_table_caption_empty(table_caption_el)
    local has_identifier = not is_table_id_empty(table_id)

    if has_caption or has_identifier then
        blocks:insert(table_caption_to_main_caption_block(table_caption_el, table_id))
    end
    blocks:extend(content_blocks)
    blocks:insert(latex_to_block("\\endfirsthead"))

    if has_caption or has_identifier then
        blocks:insert(table_caption_to_continuation_caption_block(table_caption_el, table_id))
    end
    blocks:extend(content_blocks)
    blocks:insert(latex_to_block("\\endhead"))

    return blocks
end

-- Table foot to blocks

local function table_foot_to_table_rows(
    foot_el -- pandoc.TableFoot
)
    return foot_el.rows
end

local function table_foot_to_blocks(
    foot_el -- pandoc.TableFoot
)
    local blocks = pandoc.Blocks({})

    -- WTF: This horizontal rule at the bottom of every table part except
    -- the last is 0.5pt thick (instead of desired 1pt) because this rule
    -- imediately follows a horizontal rule from the table body which has
    -- a 0.5pt thickness already
    blocks:insert(latex_to_block(hrule_latex("0.5pt")))
    blocks:insert(latex_to_block("\\endfoot"))

    for _, row_el in ipairs(table_foot_to_table_rows(foot_el)) do
        blocks:insert(latex_to_block(hrule_latex("0.5pt")))
        blocks:insert(table_row_to_block(row_el))
    end
    blocks:insert(latex_to_block(hrule_latex("1pt")))
    blocks:insert(latex_to_block("\\endlastfoot"))

    return blocks
end

-- Table bodies to blocks

local function table_body_to_table_rows(
    body_el -- pandoc.TableBody
)
    local rows = pandoc.List({})

    rows:extend(body_el.head)
    rows:extend(body_el.body)

    return rows
end

local function table_bodies_to_table_rows(
    body_els -- pandoc.List of pandoc.TableBody
)
    local rows = pandoc.List({})

    for _, body_el in ipairs(body_els) do
        rows:extend(table_body_to_table_rows(body_el))
    end

    return rows
end

local function table_bodies_to_blocks(
    body_els -- pandoc.List of pandoc.TableBody
)
    local blocks = pandoc.Blocks({})

    for i, row_el in ipairs(table_bodies_to_table_rows(body_els)) do
        if i ~= 1 then
            blocks:insert(latex_to_block(hrule_latex("0.5pt")))
        end
        blocks:insert(table_row_to_block(row_el))
    end

    return blocks
end

-- Table to blocks

local function table_to_blocks(
    table_el -- pandoc.Table
)
    local blocks = pandoc.Blocks({})

    -- WTF: The table foot goes before the table body
    -- because of the way longtables works
    blocks:insert(latex_to_block("\\begin{longtable}" .. table_colspecs_to_latex(table_el.colspecs)))
    blocks:extend(table_head_to_blocks(table_el.head, table_el.caption, table_el.identifier))
    blocks:extend(table_foot_to_blocks(table_el.foot))
    blocks:extend(table_bodies_to_blocks(table_el.bodies))
    blocks:insert(latex_to_block("\\end{longtable}"))

    return blocks
end

-- Module exports

if FORMAT:match("latex") then
    return {
        {
            Table = function (table_el)
                return table_to_blocks(table_el)
            end,
        }
    }
end
