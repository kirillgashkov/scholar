-- Include code blocks from files.
--
-- ```{.lua include="path/to/file.lua" start="1" end="10"}
-- ```
--
-- This filter has security implications, so it should only be used with
-- trusted input.

local function parse_include_attributes(
    attributes -- pandoc.Attributes
)
    local include_filepath = nil
    local start_line_number = nil
    local end_line_number = nil

    for key, value in pairs(attributes) do
        if key == "include" then
            include_filepath = value
        elseif key == "start" then
            start_line_number = tonumber(value)

            if start_line_number == nil then
                io.stderr:write(
                    "Error: 'start' attribute must be an integer.\n"
                )
                os.exit(1)
            end
        elseif key == "end" then
            end_line_number = tonumber(value)

            if end_line_number == nil then
                io.stderr:write(
                    "Error: 'end' attribute must be an integer.\n"
                )
                os.exit(1)
            end
        end
    end

    if include_filepath == nil and (start_line_number ~= nil or end_line_number ~= nil) then
        io.stderr:write(
            "Warning: code block has 'start' or 'end' attribute, but no 'include' attribute.\n"
        )
    end

    return {
        include_filepath = include_filepath,
        start_line_number = start_line_number,
        end_line_number = end_line_number
    }
end


local function remove_include_attributes(
    attributes -- pandoc.Attributes
)
    for key, value in pairs(attributes) do
        if key == "include" or key == "start" or key == "end" then
            attributes[key] = nil
        end
    end
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


local function validate_end_line_number(
    end_line_number -- int
)
    if end_line_number < 1 then
        io.stderr:write(
            "Error: the end line number must be greater than 0.\n"
        )
        os.exit(1)
    end
end


local function validate_start_end_line_numbers(
    start_line_number, -- int
    end_line_number -- int
)
    validate_start_line_number(start_line_number)
    validate_end_line_number(end_line_number)

    if start_line_number > end_line_number then
        io.stderr:write(
            "Error: the start line number must be less than or equal to the end line number.\n"
        )
        os.exit(1)
    end
end


local function load_file(
    filepath, -- string
    start_line_number, -- int or nil
    end_line_number -- int or nil
)
    if start_line_number ~= nil then
        validate_start_line_number(start_line_number)
    end

    if end_line_number ~= nil then
        validate_end_line_number(end_line_number)
    end

    if start_line_number ~= nil and end_line_number ~= nil then
        validate_start_end_line_numbers(start_line_number, end_line_number)
    end

    local file = io.open(filepath, "r")
    local lines = {}
    local line_number = 1

    -- WTF: Our VSCode Lua linter doesn't understand that 'file' is not nil
    -- when we use a guard-style if above.
    if file ~= nil then
        for line in file:lines() do
            if start_line_number == nil or line_number >= start_line_number then
                table.insert(lines, line)
            end

            if end_line_number ~= nil and line_number >= end_line_number then
                break
            end

            line_number = line_number + 1
        end

        file:close()
    else
        io.stderr:write("Error: could not open file '" .. filepath .. "'\n")
        os.exit(1)
    end

    return table.concat(lines, "\n")
end


local function make_code_block(
    code_block_el -- pandoc.CodeBlock
)
    local parsed_attributes = parse_include_attributes(code_block_el.attributes)

    if parsed_attributes.include_filepath == nil then
        return code_block_el
    end

    if code_block_el.text ~= "" then
        io.stderr:write(
            "Warning: code block has 'include' attribute, but also has text. "
            .. "The text will be ignored.\n"
        )
    end

    code_block_el.text = load_file(
        parsed_attributes.include_filepath,
        parsed_attributes.start_line_number,
        parsed_attributes.end_line_number
    )

    remove_include_attributes(code_block_el.attributes)

    return code_block_el
end


return {
    {
        CodeBlock = function (code_block_el)
            return make_code_block(code_block_el)
        end,
    }
}
