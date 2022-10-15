local function latex_to_inline(latex)
    return pandoc.RawInline("latex", latex)
end

local function latex_to_block(latex)
    return pandoc.RawBlock("latex", latex)
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


local function vrule_latex(thickness)
    return "!{\\vrule width " .. thickness .. "}"
end


local function hrule_latex(thickness)
    return "\\specialrule{" .. thickness .. "}{0pt}{0pt}"
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


-- Table head


local function table_id_to_latex_label(identifier)
    if identifier == "" then
        return ""
    end

    -- TODO: Add an ability to turn this error into a warning with a setting
    error("table_id_to_latex_label: unexpected non-empty identifier; currently native table IDs are not supported, however, if you still need to reference your tables, consider running the 'pandoc-crossref' filter before this filter, it will extact table IDs, convert them to LaTeX labels and insert them directly into the contents of your captions")
end


local function table_caption_to_first_caption_blocks(caption_el, table_id)
    -- TODO: Don't ignore optional caption_el.short
    local long_caption_content_blocks = caption_el.long
    local long_caption_content_inlines = pandoc.utils.blocks_to_inlines(long_caption_content_blocks)
    local latex_label = table_id_to_latex_label(table_id)

    -- FIXME: What if
    -- 1. long_caption_content_inlines is empty and latex_label is not?
    -- 2. long_caption_content_inlines contains special characters (e.g. '}')?
    -- TODO: Can and should we use pandoc.layout.braces(...) here?
    if #long_caption_content_inlines == 0 and latex_label == "" then
        return pandoc.Blocks({})
    else
        local inlines = pandoc.Inlines({})
        inlines:insert(pandoc.RawInline("latex", "\\caption"))
        inlines:insert(pandoc.RawInline("latex", "{"))
        inlines:extend(long_caption_content_inlines)
        inlines:insert(pandoc.RawInline("latex", "}"))
        inlines:insert(pandoc.Space())
        inlines:insert(pandoc.RawInline("latex", "\\\\")) -- In Pandoc '\tabularnewline' was used instead of '\\'
        return pandoc.Blocks({pandoc.Plain(inlines)})
    end
end


local function table_caption_to_continuation_caption_blocks(caption_el, table_id)
    -- TODO: Don't ignore optional caption_el.short
    local long_caption_content_blocks = caption_el.long
    local long_caption_content_inlines = pandoc.utils.blocks_to_inlines(long_caption_content_blocks)
    local latex_label = table_id_to_latex_label(table_id)

    -- FIXME: What if
    -- 1. long_caption_content_inlines is empty and latex_label is not?
    -- 2. long_caption_content_inlines contains special characters (e.g. '}')?
    -- TODO: Can and should we use pandoc.layout.braces(...) here?
    if #long_caption_content_inlines == 0 and latex_label == "" then
        return pandoc.Blocks({})
    else
        -- We don't insert the caption content here because this is a
        -- continuation caption which shouldn't have any content. Although this
        -- behavior is already secured by our custom Pandoc template, we still
        -- don't insert any content here because we don't want extra '\label's
        -- in our tables which can be introduced by the 'pandoc-crossref'
        -- filter
        local blocks = pandoc.Blocks({})
        blocks:insert(pandoc.RawBlock("latex", "\\captionsetup{style=customTableContinuation}")) -- This class is defined in our custom Pandoc template
        blocks:insert(pandoc.RawBlock("latex", "\\caption[]{} \\\\"))
        -- [] is used here to not mess with short captions in the continuations of a table;
        -- In Pandoc '\tabularnewline' was used instead of '\\'.
        return blocks
    end
end


local function table_head_to_blocks(head_el, caption_el, table_id)
    local head_content_blocks = pandoc.Blocks({})

    head_content_blocks:insert(pandoc.RawBlock("latex", hrule_latex("1pt")))
    for _, row in ipairs(head_el.rows) do
        head_content_blocks:insert(table_row_to_block(row))
        head_content_blocks:insert(pandoc.RawBlock("latex", hrule_latex("0.5pt")))
    end

    local first_caption_blocks = table_caption_to_first_caption_blocks(caption_el, table_id)
    local continuation_caption_blocks = table_caption_to_continuation_caption_blocks(caption_el, table_id)

    local blocks = pandoc.Blocks({})
    blocks:extend(first_caption_blocks)
    blocks:extend(head_content_blocks)
    blocks:insert(pandoc.RawBlock("latex", "\\endfirsthead"))
    blocks:extend(continuation_caption_blocks)
    blocks:extend(head_content_blocks)
    blocks:insert(pandoc.RawBlock("latex", "\\endhead"))
    return blocks
end


-- Table foot


local function table_foot_to_blocks(foot_el)
    if #foot_el.rows ~= 0 then
        -- TODO: Add an ability to turn this error into a warning with a setting
        error("table_foot_to_blocks: unexpected footer rows; currently footer rows are not supported, however, if you still need footer rows, consider creating a custom LaTeX table")
    end

    local blocks = pandoc.Blocks({})
    blocks:insert(pandoc.RawBlock("latex", hrule_latex("0.5pt"))) -- WTF: At the bottom of each table part I need a horizontal rule with 1pt thickness. When a page break occurs in a longtable, one of the middle \specialrule{0.5pt}s will be caught in the crossfire. Usually that rule would stay at the end of the previous table part instead of going to the start of the next one, which means that we already have 0.5pt thickness at the bottom. We add the extra 0.5pt thickness here, so that we had 1pt of total thickness. (Warning: I made an assumption that the middle \specialrule{0.5pt} wouldn't appear on the next page, because in my testing it never did. If it actually can appear there, the output will be a bit wrong but it's not critical)
    blocks:insert(pandoc.RawBlock("latex", "\\endfoot"))
    blocks:insert(pandoc.RawBlock("latex", hrule_latex("1pt")))
    blocks:insert(pandoc.RawBlock("latex", "\\endlastfoot"))
    return blocks
end


-- Table bodies


local function table_bodies_to_blocks(body_els)
    local rows = pandoc.List({})
    
    for _, body_el in ipairs(body_els) do
        rows:extend(body_el.head)
        rows:extend(body_el.body)
    end

    local blocks = pandoc.Blocks({})

    -- FIXME: What if
    -- 1. rows[#rows] is missing/inaccessible (e.g. rows is empty)?
    for i = 1, #rows - 1 do
        blocks:insert(table_row_to_block(rows[i]))
        blocks:insert(pandoc.RawBlock("latex", hrule_latex("0.5pt")))
    end
    blocks:insert(table_row_to_block(rows[#rows]))

    return blocks
end


-- Table


local function table_to_blocks(table_el)
    if type(table_el) ~= "table" then
        error("expected table, got " .. type(table_el))
    end
    
    local blocks = pandoc.Blocks({})

    -- FIXME: What if
    -- 1. table_el.colspecs is missing?
    -- 2. table_el.head is missing?
    -- 3. table_el.caption is missing?
    -- 4. table_el.foot is missing?
    -- 5. table_el.bodies is missing?
    blocks:insert(pandoc.RawBlock("latex", "\\begin{longtable}" .. table_colspecs_to_latex(table_el.colspecs)))
    blocks:extend(table_head_to_blocks(table_el.head, table_el.caption, table_el.attr.identifier))
    blocks:extend(table_foot_to_blocks(table_el.foot))
    blocks:extend(table_bodies_to_blocks(table_el.bodies))
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
