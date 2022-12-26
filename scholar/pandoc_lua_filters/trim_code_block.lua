return {
    {
        CodeBlock = function (
            code_block_el -- pandoc.CodeBlock
        )
            code_block_el.text = code_block_el.text:gsub("^\n+", ""):gsub("\n+$", "")
            return code_block_el
        end,
    }
}
