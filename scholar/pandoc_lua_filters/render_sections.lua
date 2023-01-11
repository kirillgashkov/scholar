return {
    {
        Pandoc = function (
            doc -- pandoc.Pandoc
        )
            return pandoc.Pandoc(
                -- Creates Divs beginning at each Header and containing
                -- following content until the next Header of comparable level.
                --
                -- Each created Div gets a ".section" class and its header's
                -- classes and identifiers. Also the identifier is moved from
                -- the header to the Div.
                pandoc.utils.make_sections(false, nil, doc.blocks),
                doc.meta
            )
        end
    }
}
