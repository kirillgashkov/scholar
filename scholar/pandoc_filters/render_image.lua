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
-- Image
--


local function is_image_para(
    para -- pandoc.Para
)
    return #para.content == 1 and para.content[1].t == "Image"
end


local function image_para_to_image(
    para -- pandoc.Para
)
    return para.content[1]
end


local function pop_image_id(
    image -- pandoc.Image
)
    local id = image.identifier
    image.identifier = ""

    if id == "" then
        return nil
    end

    return id
end


local function pop_image_caption(
    image -- pandoc.Image
)
    local caption = image.caption
    image.caption = pandoc.Inlines({})

    if caption == pandoc.Inlines({}) then
        return nil
    end

    return caption
end


return {
    {
        Para = function (
            para -- pandoc.Para
        )
            if not is_image_para(para) then
                return para
            end

            local image = image_para_to_image(para)
            local id = pop_image_id(image)
            local caption = pop_image_caption(image)

            local captionable = Captionable:new(id, caption)

            if not captionable:has_caption() then
                return image
            end

            local inlines = pandoc.Inlines({})
            inlines:insert(pandoc.RawInline("latex", "\\begin{figure}\n"))
            inlines:insert(pandoc.RawInline("latex", "\\centering\n"))
            inlines:insert(image)
            inlines:insert(pandoc.RawInline("latex", "\n"))
            inlines:extend(captionable:render_caption())
            inlines:insert(pandoc.RawInline("latex", "\n"))
            inlines:insert(pandoc.RawInline("latex", "\\end{figure}"))
            return pandoc.Plain(inlines)
        end,
    }
}
