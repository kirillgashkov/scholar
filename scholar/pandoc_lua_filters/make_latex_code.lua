-- Convert Pandoc code inlines to LaTeX minted blocks.
--
----- USAGE --------------------------------------------------------------------
--
-- Example input code inline:
--
--     The function `greet` is defined in `greet.py`:
--
-- If you need to syntax highlight a code inline, you can use the the following
-- syntax (requires corresponding Pandoc Markdown extensions to be enabled):
--
--     The function greet: `def greet(name): print(f"Hello, {name}!")`{.python}.
--
----- SECURITY IMPLICATIONS ----------------------------------------------------
--
-- The accepted parameters 'start', 'language'  and 'identifier' ('7', 'python'
-- and 'greet' in the examples above) are treated as raw LaTeX code.
--
-- However, the parameter 'caption' is treated as raw Markdown, so it will even
-- be parsed and rendered by Pandoc.


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
