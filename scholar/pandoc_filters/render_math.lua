local Captionable = {}
Captionable.__index = Captionable

function Captionable:new(
    id, -- string | nil
    caption -- pandoc.Inlines | nil
)
   local o = {}
   setmetatable(o, Captionable)

   o.id = id
   o.caption = caption

   return o
end

function Captionable:has_caption()
    return self.id ~= nil or self.caption ~= nil
end

function Captionable:render_caption()
    local inlines = pandoc.Inlines({})

    if self.caption ~= nil then
        inlines:insert(pandoc.RawInline("latex", "\\caption{"))
        inlines:extend(self.caption)
        inlines:insert(pandoc.RawInline("latex", "}"))
    elseif self.id ~= nil then
        inlines:insert(pandoc.RawInline("latex", "\\caption{}"))
    end

    if self.id ~= nil then
        inlines:insert(pandoc.RawInline("latex", "\\label{" .. self.id .. "}"))
    end

    return inlines
end


--
-- Math
--


local function is_math_para(
    para -- pandoc.Para
)
    return (
        #para.content == 1
        and para.content[1].t == "Math"
        and para.content[1].mathtype == "DisplayMath"
    ) or (
        #para.content == 1
        and para.content[1].t == "Span"
        and #para.content[1].content == 1
        and para.content[1].content[1].t == "Math"
        and para.content[1].content[1].mathtype == "DisplayMath"
    )
end


local function math_para_to_math_span(
    para -- pandoc.Para
)
    if (
        #para.content == 1
        and para.content[1].t == "Math"
        and para.content[1].mathtype == "DisplayMath"
    ) then
        return pandoc.Span(para.content[1])
    end

    return para.content[1]
end


local function get_math_span_id(
    math_span -- pandoc.Span with pandoc.Math
)
    local id = math_span.identifier

    if id == "" then
        return nil
    end

    return id
end


local function math_span_to_math(
    math_span -- pandoc.Span with pandoc.Math
)
    return math_span.content[1]
end


return {
    {
        Para = function (
            para -- pandoc.Para
        )
            if not is_math_para(para) then
                return para
            end

            local math_span = math_para_to_math_span(para)
            local id = get_math_span_id(math_span)
            local caption = nil -- Math does not have captions.

            local math = math_span_to_math(math_span)
            local captionable = Captionable:new(id, caption)

            if captionable.id ~= nil then
                return pandoc.RawBlock("latex", table.concat({
                    "\\begin{equation}\\label{" .. captionable.id .. "}",
                    math.text:gsub("^\n+", ""):gsub("\n+$", ""), -- Leading and trailing newlines are not allowed in "equation" environment.
                    "\\end{equation}",
                }, "\n"))
            else
                -- "equation*" environment requires "amsmath" package.
                return pandoc.RawBlock("latex", table.concat({
                    "\\begin{equation*}",
                    math.text:gsub("^\n+", ""):gsub("\n+$", ""), -- Leading and trailing newlines are not allowed in "equation*" environment.
                    "\\end{equation*}",
                }, "\n"))
            end
        end,
    }
}
