local scholar_filter_id = "com.github.kirillgashkov.scholar.filters.convert_image_from_svg_to_pdf"
local scholar


local function hash_file(
    filepath -- string
)
    local f = assert(io.open(filepath, "rb"))
    local hash = pandoc.utils.sha1(f:read("a"))
    f:close()

    return hash
end


local function can_read_file(
    filepath -- string
)
    local f = io.open(filepath, "r")

    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end


return {
    {
        Meta = function (
            meta -- pandoc.Meta
        )
            scholar = meta.scholar
        end,
    },
    {
        Image = function (
            image -- pandoc.Image
        )
            if not pandoc.text.lower(image.src):match("%.svg$") then
                return
            end

            local input_svg_image_path = image.src

            local filter_cache_dir = (
                scholar.settings.cache_dir .. "/" .. scholar_filter_id
            )
            local output_pdf_image_path = (
                filter_cache_dir
                .. "/"
                .. hash_file(input_svg_image_path)
                .. ".pdf"
            )

            if can_read_file(output_pdf_image_path) then
                image.src = output_pdf_image_path
                return image
            end

            pandoc.pipe("mkdir", {filter_cache_dir}, "")
            pandoc.pipe(
                scholar.settings.rsvg_convert_executable,
                {
                    "--format",
                    "pdf",
                    -- Use 72 dpi instead of the default 96 because
                    -- tools like Figma use the former for exports.
                    "--dpi-x",
                    "72",
                    "--dpi-y",
                    "72",
                    "--output",
                    output_pdf_image_path,
                    input_svg_image_path,
                },
                ""
            )

            image.src = output_pdf_image_path
            return image
        end,
    }
}
