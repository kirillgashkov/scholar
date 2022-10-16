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

local function is_table_id_provided(
    identifier -- string
)
    return identifier ~= ""
end

local function is_main_table_caption_provided(
    main_caption_blocks -- table.Blocks
)
    return #main_caption_blocks ~= 0
end

local function is_lot_table_caption_provided(
    lot_caption_inlines_or_nil -- table.Inlines or nil
)
    return lot_caption_inlines_or_nil ~= nil
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

local function table_rows_to_blocks(
    row_els, -- pandoc.List of pandoc.Row
    separator_block_or_nil -- pandoc.Block-like or nil
)
    local blocks = pandoc.Blocks({})

    for i, row_el in ipairs(row_els) do
        if i ~= 1 and separator_block_or_nil ~= nil then
            blocks:insert(separator_block_or_nil)
        end
        blocks:insert(table_row_to_block(row_el))
    end

    return blocks
end

-- Longtable spec

local function table_colspecs_to_simple_latex_column_descriptors(
    colspec_els -- pandoc.List of pandoc.ColSpec
)
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

local function table_colspecs_to_complex_latex_column_descriptors(
    colspec_els -- pandoc.List of pandoc.ColSpec
)
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

local function make_longtable_spec_latex(
    table_colspec_els -- pandoc.List of pandoc.ColSpec
)
    local default_widths_only = true
    for _, colspec_el in ipairs(table_colspec_els) do
        if colspec_el[2] ~= nil then
            default_widths_only = false
            break
        end
    end

    local latex_column_descriptors = pandoc.List({})
    if default_widths_only then
        latex_column_descriptors = table_colspecs_to_simple_latex_column_descriptors(table_colspec_els)
    else
        latex_column_descriptors = table_colspecs_to_complex_latex_column_descriptors(table_colspec_els)
    end

    local longtable_spec_latex = "{" .. vrule_latex("1pt")
    for i, latex_column_descriptor in ipairs(latex_column_descriptors) do
        if i ~= 1 then
            longtable_spec_latex = longtable_spec_latex .. vrule_latex("0.5pt")
        end

        longtable_spec_latex = longtable_spec_latex .. latex_column_descriptor
    end
    longtable_spec_latex = longtable_spec_latex .. vrule_latex("1pt") .."}"

    return longtable_spec_latex
end

-- Caption

local function table_id_to_latex(
    identifier -- string
)
    if identifier == "" then
        warn(
            "non-empty table IDs are not supported; treating a non-empty table ID as empty"
        )
        -- WTF: Because the 'pandoc-crossref' filter parses the table ID on
        -- itself, converts it to LaTeX's '\label{...}' command and embeds it
        -- into the caption as raw LaTeX
    end

    return ""
end

local function make_caption_block_of_numbered_table_start(
    main_caption_blocks, -- pandoc.Blocks
    lot_caption_inlines_or_nil, -- pandoc.Inlines or nil
    table_id -- string
)
    local inlines = pandoc.Inlines({})

    inlines:insert(latex_to_inline("\\caption"))

    if is_lot_table_caption_provided(lot_caption_inlines_or_nil) then
        inlines:insert(latex_to_inline("["))
        inlines:extend(lot_caption_inlines_or_nil)
        inlines:insert(latex_to_inline("]"))
    end

    if is_main_table_caption_provided(main_caption_blocks) then
        inlines:insert(latex_to_inline("{"))
        inlines:extend(pandoc.utils.blocks_to_inlines(main_caption_blocks))
        inlines:insert(latex_to_inline("}"))
    else
        inlines:insert(latex_to_inline("{"))
        inlines:insert(latex_to_inline("}"))
    end

    if is_table_id_provided(table_id) then
        inlines:insert(latex_to_inline(table_id_to_latex(table_id)))
    end

    -- Pandoc generates captions with '\tabularnewline' instead of '\\'
    inlines:insert(pandoc.Space())
    inlines:insert("\\\\")

    return pandoc.Plain(inlines)
end

local function make_caption_block_of_numbered_table_continuation()
    local blocks = pandoc.Blocks({})

    -- Pandoc generates captions with '\tabularnewline' instead of '\\'
    blocks:insert(latex_to_block("\\captionsetup{style=customNumberedTableContinuation}"))
    blocks:insert(latex_to_block("\\caption[]{} \\\\"))

    return blocks
end

local function make_caption_block_of_unnumbered_table_continuation()
    local blocks = pandoc.Blocks({})

    -- Pandoc generates captions with '\tabularnewline' instead of '\\'
    blocks:insert(latex_to_block("\\captionsetup{style=customUnnumberedTableContinuation}"))
    blocks:insert(latex_to_block("\\caption*{} \\\\"))

    return blocks
end

-- Longtable head

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

local function make_longtable_head_blocks(
    table_head_el, -- pandoc.TableHead
    caption_block_of_table_start_or_nil, -- pandoc.Block-like or nil
    caption_block_of_table_continuation_or_nil -- pandoc.Block-like or nil
)
    local blocks = pandoc.Blocks({})

    local content_blocks = table_head_to_content_blocks(table_head_el)

    if caption_block_of_table_start_or_nil ~= nil then
        blocks:insert(caption_block_of_table_start_or_nil)
    end
    blocks:extend(content_blocks)
    blocks:insert(latex_to_block("\\endfirsthead"))

    if caption_block_of_table_continuation_or_nil ~= nil then
        blocks:insert(caption_block_of_table_continuation_or_nil)
    end
    blocks:extend(content_blocks)
    blocks:insert(latex_to_block("\\endhead"))

    return blocks
end

-- Longtable foot

local function table_foot_to_table_rows(
    foot_el -- pandoc.TableFoot
)
    return foot_el.rows
end

local function make_longtable_foot_blocks(
    table_foot_el -- pandoc.TableFoot
)
    local blocks = pandoc.Blocks({})

    -- WTF: This horizontal rule at the bottom of every table part except
    -- the last is 0.5pt thick (instead of desired 1pt) because this rule
    -- imediately follows a horizontal rule from the table body which has
    -- a 0.5pt thickness already
    blocks:insert(latex_to_block(hrule_latex("0.5pt")))
    blocks:insert(latex_to_block("\\endfoot"))

    for _, row_el in ipairs(table_foot_to_table_rows(table_foot_el)) do
        blocks:insert(latex_to_block(hrule_latex("0.5pt")))
        blocks:insert(table_row_to_block(row_el))
    end
    blocks:insert(latex_to_block(hrule_latex("1pt")))
    blocks:insert(latex_to_block("\\endlastfoot"))

    return blocks
end

-- Longtable body

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

local function make_longtable_body_blocks(
    table_body_els -- pandoc.List of pandoc.TableBody
)
    local blocks = pandoc.Blocks({})

    for i, row_el in ipairs(table_bodies_to_table_rows(table_body_els)) do
        if i ~= 1 then
            blocks:insert(latex_to_block(hrule_latex("0.5pt")))
        end
        blocks:insert(table_row_to_block(row_el))
    end

    return blocks
end

-- Longtable

local function table_to_blocks(
    table_el -- pandoc.Table
)
    local blocks = pandoc.Blocks({})

    local latex_environment_name_of_table
    local caption_block_of_table_start_or_nil
    local caption_block_of_table_continuation

    if (
        is_main_table_caption_provided(table_el.caption.long)
        or is_lot_table_caption_provided(table_el.caption.short)
        or is_table_id_provided(table_el.identifier)
    ) then
        latex_environment_name_of_table = "longtable"
        caption_block_of_table_start_or_nil = (
            make_caption_block_of_numbered_table_start(
                table_el.caption.long,
                table_el.caption.short,
                table_el.identifier
            )
        )
        caption_block_of_table_continuation = (
            make_caption_block_of_numbered_table_continuation()
        )
    else
        latex_environment_name_of_table = "longtable*"
        caption_block_of_table_start_or_nil = nil
        caption_block_of_table_continuation = (
            make_caption_block_of_unnumbered_table_continuation()
        )
    end

    -- WTF: The table foot goes before the table body
    -- because of the way longtables works
    blocks:insert(latex_to_block("\\begin{" .. latex_environment_name_of_table .. "}" .. make_longtable_spec_latex(table_el.colspecs)))
    blocks:extend(make_longtable_head_blocks(table_el.head, caption_block_of_table_start_or_nil, caption_block_of_table_continuation))
    blocks:extend(make_longtable_foot_blocks(table_el.foot))
    blocks:extend(make_longtable_body_blocks(table_el.bodies))
    blocks:insert(latex_to_block("\\end{" .. latex_environment_name_of_table .. "}"))

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
