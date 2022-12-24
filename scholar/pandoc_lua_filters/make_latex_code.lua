--
--
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


local function latex_to_inline(
    latex -- string
)
    return pandoc.RawInline("latex", latex)
end


local function make_code(
    code -- pandoc.Code
)
    local parsed_classes = parse_code_classes(code.classes)

    local language = parsed_classes.language
    if parsed_classes.language ~= nil then
        language = parsed_classes.language
    else
        language = "text"
    end

    -- \mintinline{python}{def greet(name): print(f"Hello, {name}!")}

    local inlines = pandoc.Inlines({})

    inlines:extend(
        {
            -- NOTE: We are trusing 'language' to be valid latex.
            --
            -- NOTE: We are using backticks to delimit the code, minted allows
            --       it and it makes it more intutive to write in markdown.
            latex_to_inline("\\mintinline{" .. language .. "}`"),
            latex_to_inline(code.text),
            latex_to_inline("`"),
        }
    )

    return inlines
end


if FORMAT:match("latex") then
    return {
        {
            Code = function (
                code_el -- pandoc.Code
            )
                return make_code(code_el)
            end,
        }
    }
end
