-- Convert Pandoc code blocks to LaTeX minted blocks.
--
----- USAGE --------------------------------------------------------------------
--
-- Example input code block:
--
--     ```python
--     def greet(name):
--         print(f"Hello, {name}!")
--     ```
--
--     ```{.python #greet caption="A function that greets a person"}
--     def greet(name):
--         print(f"Hello, {name}!")
--     ```
--
-- This filter also recognizes the 'from' attribute used by the
-- 'include_code_block.lua' filter. If the 'from' attribute is present, the
-- filter will set the 'firstline' option of the minted environment:
--
--    ```{.python include="path/to/file.py" from=7}
--    ```
--
----- SECURITY IMPLICATIONS ----------------------------------------------------
--
-- The accepted parameters 'from', 'language'  and 'identifier' ('7', 'python'
-- and 'greet' in the examples above) are treated as raw LaTeX code.
--
-- However, the parameter 'caption' is treated as raw Markdown, so it will even
-- be parsed and rendered by Pandoc.
--
----- LATEX REQUIREMENTS -------------------------------------------------------
--
-- Requires 'caption'...
--
--     \usepackage{caption}
--
-- ...and 'minted' with '[newfloat]' option (it provides better integration with
-- the 'caption' package):
--
--     \usepackage[newfloat]{minted}
--
-- Then you need to define a 'longlisting' environment, which supports spanning
-- over multiple pages:
--
--     \newenvironment{longlisting}{\captionsetup{type=listing}}{}
--
-- Now you can create LaTeX listings when you need a caption or a label:
--
--     \begin{longlisting}
--     \begin{minted}{python}
--     def greet(name):
--         print(f"Hello, {name}!")
--     \end{minted}
--     \caption{A function that greets a person}
--     \label{greet}
--     \end{longlisting}

local function parse_code_classes(
    classes -- pandoc.List of string
)
    local language

    if #classes > 0 then
        language = classes[1]
    else
        language = nil
    end

    return {
        language = language
    }
end


local function parse_code_attributes(
    attributes -- pandoc.Attributes
)
    local caption_inlines = nil
    local start_line_number = nil

    local should_warn_about_extra_captions = false

    for key, value in pairs(attributes) do
        if key == "caption" then
            if caption_inlines ~= nil then
                should_warn_about_extra_captions = true
            else
                caption_inlines = pandoc.utils.blocks_to_inlines(pandoc.read(value).blocks)
            end
        elseif key == "caption_json" then
            if caption_inlines ~= nil then
                should_warn_about_extra_captions = true
            end

            caption_inlines = pandoc.utils.blocks_to_inlines(pandoc.read(value, "json").blocks)
        elseif key == "from" then
            start_line_number = tonumber(value)

            if start_line_number == nil then
                io.stderr:write(
                    "Error: 'from' attribute must be an integer.\n"
                )
                os.exit(1)
            end
        end
    end

    if should_warn_about_extra_captions then
        io.stderr:write(
            "Warning: 'caption' and 'caption_json' attributes are both provided. Ignoring 'caption'.\n"
        )
        io.stderr:write("Hint: Check for extra 'caption' attributes in your document when you are using paragraph captions.\n")
    end

    return {
        caption_inlines = caption_inlines,
        start_line_number = start_line_number
    }
end


local function validate_start_line_number(
    start_line_number -- int
)
    if start_line_number < 1 then
        io.stderr:write(
            "Error: the start line number must be greater than 0.\n"
        )
        os.exit(1)
    end
end


local function latex_to_inline(
    latex -- string
)
    return pandoc.RawInline("latex", latex)
end


local function make_code_block(
    code_block_el -- pandoc.CodeBlock
)
    local identifier = code_block_el.identifier
    local parsed_classes = parse_code_classes(code_block_el.classes)
    local parsed_attributes = parse_code_attributes(code_block_el.attributes)

    -- See https://tex.stackexchange.com/q/18311.
    --
    -- %a matches any alphabetic character
    -- %d matches any digit
    -- %- matches a hyphen
    -- : matches a colon
    if not identifier:match("^[%a%d%-:]*$") then
        io.stderr:write(
            "Warning: identifier contains bad characters: " .. identifier .. "\n"
        )
        io.stderr:write(
            "Hint: identifiers should only contain alphanumeric characters, hyphens, and colons.\n"
        )
    end

    local language
    if parsed_classes.language ~= nil then
        language = parsed_classes.language
    else
        language = "text"
    end

    local caption_inlines = parsed_attributes.caption_inlines
    local start_line_number = parsed_attributes.start_line_number

    if start_line_number ~= nil then
        validate_start_line_number(start_line_number)
    end

    -- \begin{longlisting}
    -- \begin{minted}{python}
    -- def greet(name):
    --     print(f"Hello, {name}!")
    -- \end{minted}
    -- \caption{A function that greets a person}
    -- \label{lst:greet}
    -- \end{longlisting}

    local inlines = pandoc.Inlines({})

    local has_identifier = identifier ~= ""
    local has_caption = caption_inlines ~= nil
    local has_start_line_number = start_line_number ~= nil
    local is_listing = has_identifier or has_caption

    if is_listing then
        inlines:insert(latex_to_inline("\\begin{longlisting}\n"))
    end

    if has_caption then
        inlines:insert(latex_to_inline("\\caption{"))
        inlines:extend(caption_inlines)
        inlines:insert(latex_to_inline("}\n"))
    end

    if has_identifier then
        -- NOTE: We are trusing 'identifier' to be valid latex.
        inlines:insert(latex_to_inline("\\label{" .. identifier .. "}\n"))
    end

    inlines:insert(latex_to_inline("\\begin{minted}"))

    if has_start_line_number then
        inlines:insert(latex_to_inline("[firstnumber=" .. start_line_number .. "]"))
    end

    inlines:insert(latex_to_inline("{" .. language .. "}\n"))

    inlines:extend(
        {
            latex_to_inline(code_block_el.text),
            latex_to_inline("\n"),
            latex_to_inline("\\end{minted}\n"),
        }
    )

    if is_listing then
        inlines:insert(latex_to_inline("\\end{longlisting}"))
    end

    return pandoc.Plain(inlines)
end


if FORMAT:match("latex") then
    return {
        {
            CodeBlock = function (
                code_block_el -- pandoc.CodeBlock
            )
                return make_code_block(code_block_el)
            end,
        }
    }
end
