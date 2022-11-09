local OUTSIDE_VRULE_THICKNESS_IN_PT = 1
local OUTSIDE_HRULE_THICKNESS_IN_PT = 1
local INSIDE_VRULE_THICKNESS_IN_PT = 0.5
local INSIDE_HRULE_THICKNESS_IN_PT = 0.5

-- Utility LaTeX builders

local function vrule_latex(
    thickness -- string (e.g. "0.5pt")
)
    return "!{\\vrule width " .. thickness .. "}"
end

local function hrule_latex(
    thickness -- string (e.g. "0.5pt")
)
    return "\\specialrule{" .. thickness .. "}{0pt}{0pt}"
end

-- LaTeX

local function latex_to_inline(
    latex -- string
)
    return pandoc.RawInline("latex", latex)
end

local function latex_to_block(
    latex -- string
)
    return pandoc.RawBlock("latex", latex)
end

-- Utility property checkers

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

local function is_table_cell_simple(
    cell_el -- pandoc.Cell
)
    local cell_blocks = cell_el.contents

    return (
        (#cell_blocks == 0)
        or (#cell_blocks == 1 and cell_blocks[1].tag == "Plain")
        or (#cell_blocks == 1 and cell_blocks[1].tag == "Para")
    )
end

-- Table row

local function table_cell_to_inlines(
    cell_el -- pandoc.Cell
)
    if not is_table_cell_simple(cell_el) then
        warn("nonsimple table cells are not supported; converting a nonsimple cell to simple")
    end

    return pandoc.utils.blocks_to_inlines(cell_el.contents)
end

local function table_row_to_block(
    row_el, -- pandoc.Row
    is_head_row -- boolean
)
    local inlines = pandoc.Inlines({})

    for i, cell_el in ipairs(row_el.cells) do
        if i ~= 1 then
            inlines:insert(latex_to_inline("&"))
            inlines:insert(pandoc.Space())
        end

        if is_head_row then
            -- '\thead' comes from the 'makecell' package
            inlines:insert(latex_to_inline("\\thead{"))
            inlines:extend(table_cell_to_inlines(cell_el))
            inlines:insert(latex_to_inline("}"))
        else
            inlines:extend(table_cell_to_inlines(cell_el))
        end
        inlines:insert(pandoc.Space())
    end
    
    inlines:insert(latex_to_inline("\\\\"))

    return pandoc.Plain(inlines)
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

        -- "\columnwidth - ..." is the width of the table minus the width of
        -- every cell's left and right paddings, minus the thickness of 2
        -- outside vrules, minus the thickness of every inside vrule (a vrule
        -- which is inserted between two cells).
        latex_column_descriptors:insert(
            (
                ">{"
                .. latex_alignment_command
                .. "\\arraybackslash"
                .. "}"
            ) .. (
                "p{"
            
                .. "("
                .. "\\columnwidth"
                .. " - "
                .. string.format("%d", #colspec_els * 2) .. "\\tabcolsep"
                .. " - "
                .. string.format("%.4f", 2 * OUTSIDE_VRULE_THICKNESS_IN_PT) .. "pt"
                .. " - "
                .. string.format("%.4f", (#colspec_els - 1) * INSIDE_VRULE_THICKNESS_IN_PT) .. "pt"
                .. ")"

                .. " * "

                .. "\\real{" .. string.format("%.4f", width) .. "}"

                .. "}"
            )
        )
    end

    return latex_column_descriptors
end

local function longtable_spec_latex(
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

    local longtable_spec_latex = "{" .. vrule_latex(string.format("%.4f", OUTSIDE_VRULE_THICKNESS_IN_PT) .. "pt")
    for i, latex_column_descriptor in ipairs(latex_column_descriptors) do
        if i ~= 1 then
            longtable_spec_latex = longtable_spec_latex .. vrule_latex(string.format("%.4f", INSIDE_VRULE_THICKNESS_IN_PT) .. "pt")
        end

        longtable_spec_latex = longtable_spec_latex .. latex_column_descriptor
    end
    longtable_spec_latex = longtable_spec_latex .. vrule_latex(string.format("%.4f", OUTSIDE_VRULE_THICKNESS_IN_PT) .. "pt") .. "}"

    return longtable_spec_latex
end

-- Caption

local function table_id_to_latex(
    identifier -- string
)
    if identifier == "" then
        warn(
            "nonempty table IDs are not supported; treating a nonempty table ID as empty"
        )
        -- WTF: Because the 'pandoc-crossref' filter parses the table ID on
        -- itself, converts it to LaTeX's '\label{...}' command and embeds it
        -- into the caption as raw LaTeX.
    end

    return ""
end

local function caption_block_of_numbered_table_start(
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
    inlines:insert(latex_to_inline("\\\\"))

    return pandoc.Plain(inlines)
end

local function caption_block_of_numbered_table_continuation()
    local inlines = pandoc.Inlines({})

    -- Pandoc generates captions with '\tabularnewline' instead of '\\'
    inlines:insert(latex_to_inline("\\captionsetup{style=customNumberedTableContinuation}"))
    inlines:insert(latex_to_inline("\\caption[]{} \\\\"))

    return pandoc.Plain(inlines)
end

local function caption_block_of_unnumbered_table_continuation()
    local inlines = pandoc.Inlines({})

    -- Pandoc generates captions with '\tabularnewline' instead of '\\'
    inlines:insert(latex_to_inline("\\captionsetup{style=customUnnumberedTableContinuation}"))
    inlines:insert(latex_to_inline("\\caption*{} \\\\"))

    return pandoc.Plain(inlines)
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
            blocks:insert(latex_to_block(hrule_latex(string.format("%.4f", OUTSIDE_HRULE_THICKNESS_IN_PT) .. "pt")))
        end
        blocks:insert(table_row_to_block(row_el, true))
        blocks:insert(latex_to_block(hrule_latex(string.format("%.4f", INSIDE_HRULE_THICKNESS_IN_PT) .. "pt")))
    end

    return blocks
end

local function longtable_head_blocks(
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

local function longtable_foot_blocks(
    table_foot_el -- pandoc.TableFoot
)
    local blocks = pandoc.Blocks({})

    -- WTF: This horizontal rule at the bottom of every table part except
    -- the last accounts for a fact that there is already an inside horizontal
    -- rule from the table body at the bottom of the part because of the way
    -- longtables work.
    blocks:insert(latex_to_block(hrule_latex(string.format("%.4f", OUTSIDE_HRULE_THICKNESS_IN_PT - INSIDE_HRULE_THICKNESS_IN_PT) .. "pt")))
    blocks:insert(latex_to_block("\\endfoot"))

    for _, row_el in ipairs(table_foot_to_table_rows(table_foot_el)) do
        blocks:insert(latex_to_block(hrule_latex(string.format("%.4f", INSIDE_HRULE_THICKNESS_IN_PT) .. "pt")))
        blocks:insert(table_row_to_block(row_el, false))
    end
    blocks:insert(latex_to_block(hrule_latex(string.format("%.4f", OUTSIDE_HRULE_THICKNESS_IN_PT) .. "pt")))
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

local function longtable_body_blocks(
    table_body_els -- pandoc.List of pandoc.TableBody
)
    local blocks = pandoc.Blocks({})

    for i, row_el in ipairs(table_bodies_to_table_rows(table_body_els)) do
        if i ~= 1 then
            blocks:insert(latex_to_block(hrule_latex(string.format("%.4f", INSIDE_HRULE_THICKNESS_IN_PT) .. "pt")))
        end
        blocks:insert(table_row_to_block(row_el, false))
    end

    return blocks
end

-- Longtable

local function longtable_blocks(
    table_el -- pandoc.Table
)
    local blocks = pandoc.Blocks({})

    local is_table_numbered = (
        is_main_table_caption_provided(table_el.caption.long)
        or is_lot_table_caption_provided(table_el.caption.short)
        or is_table_id_provided(table_el.identifier)
    )

    local latex_environment_name_of_table
    local caption_block_of_table_start_or_nil
    local caption_block_of_table_continuation
    
    if is_table_numbered then
        latex_environment_name_of_table = "longtable"
        caption_block_of_table_start_or_nil = caption_block_of_numbered_table_start(table_el.caption.long, table_el.caption.short, table_el.identifier)
        caption_block_of_table_continuation = caption_block_of_numbered_table_continuation()
    else
        latex_environment_name_of_table = "longtable*"
        caption_block_of_table_start_or_nil = nil
        caption_block_of_table_continuation = caption_block_of_unnumbered_table_continuation()
    end

    -- WTF: The table foot goes before the table body
    -- because of the way longtables works.
    blocks:insert(latex_to_block("\\begin{" .. latex_environment_name_of_table .. "}" .. longtable_spec_latex(table_el.colspecs)))
    blocks:extend(longtable_head_blocks(table_el.head, caption_block_of_table_start_or_nil, caption_block_of_table_continuation))
    blocks:extend(longtable_foot_blocks(table_el.foot))
    blocks:extend(longtable_body_blocks(table_el.bodies))
    blocks:insert(latex_to_block("\\end{" .. latex_environment_name_of_table .. "}"))

    return blocks
end

-- Module exports

if FORMAT:match("latex") then
    return {
        {
            Table = function (table_el)
                return longtable_blocks(table_el)
            end,
        }
    }
end
