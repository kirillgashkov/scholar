return {
    {
        CodeBlock = function (
            code_block_el -- pandoc.CodeBlock
        )
            code_block_el.text = code_block_el.text:gsub("^%s+", ""):gsub("%s+$", "")
            return code_block_el
        end,
    }
}
