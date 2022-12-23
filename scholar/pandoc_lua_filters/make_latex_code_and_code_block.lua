--
--
-- NOTE: We are trusing the language to be valid latex.
-- NOTE: We are trusing the identifier to be valid latex.


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

    for key, value in pairs(attributes) do
        if key == "caption" then
            caption = value
        end
    end

    return {
        caption = caption
    }
end


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
    local is_listing = has_identifier or has_caption

    if is_listing then
        inlines:insert(latex_to_inline("\\begin{longlisting}\n"))
    end

    inlines:extend(
        {
            -- NOTE: We are trusing the language to be valid latex.
            latex_to_inline("\\begin{minted}{" .. language .. "}\n"),
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
        -- NOTE: We are trusing the identifier to be valid latex.
        inlines:insert(latex_to_inline("\\label{" .. identifier .. "}\n"))
    end

    if is_listing then
        inlines:insert(latex_to_inline("\\end{longlisting}\n"))
    end

    return pandoc.Plain(inlines)
end


if FORMAT:match("latex") then
    return {
        {
            -- Code = function (
            --     code_el -- pandoc.Code
            -- )
            --     return make_code(code)
            -- end,

            CodeBlock = function (
                code_block_el -- pandoc.CodeBlock
            )
                return make_code_block(code_block_el)
            end,
        }
    }
end
