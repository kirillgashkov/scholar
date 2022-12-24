--
--
-- NOTE: We are trusing 'start_line_number' to be valid latex.
-- NOTE: We are trusing 'language' to be valid latex.
-- NOTE: We are trusing 'identifier' to be valid latex.


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
    local caption = nil
    local start_line_number = nil

    for key, value in pairs(attributes) do
        if key == "caption" then
            caption = value
        elseif key == "start" then
            start_line_number = tonumber(value)

            if start_line_number == nil then
                io.stderr:write(
                    "Error: 'start' attribute must be an integer.\n"
                )
                os.exit(1)
            end
        end
    end

    return {
        caption = caption,
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

    local caption = parsed_attributes.caption
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
    local has_caption = caption ~= nil
    local has_start_line_number = start_line_number ~= nil
    local is_listing = has_identifier or has_caption

    if is_listing then
        inlines:insert(latex_to_inline("\\begin{longlisting}\n"))
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

    if has_caption then
        inlines:insert(latex_to_inline("\\caption{"))
        inlines:extend(pandoc.utils.blocks_to_inlines(pandoc.read(caption).blocks))
        inlines:insert(latex_to_inline("}\n"))
    end

    if has_identifier then
        -- NOTE: We are trusing 'identifier' to be valid latex.
        inlines:insert(latex_to_inline("\\label{" .. identifier .. "}\n"))
    end

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
