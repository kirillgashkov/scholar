import shutil
from pathlib import Path
from typing import TypeVar

import typer

from scholar.converters import (
    LaTeXToPDFConverter,
    MarkdownToLaTeXConverter,
    PandocFilter,
    PandocFilterType,
)
from scholar.settings import (
    LATEXMK_OUTPUT_DIR,
    PANDOC_EXTRACTED_RESOURCES_DIR,
    PANDOC_GENERATED_RESOURCES_DIR,
    PANDOC_JSON_FILTER_DIR,
    PANDOC_LUA_FILTERS_DIR,
    PANDOC_OUTPUT_DIR,
    PANDOC_TEMPLATE_FILE,
)

T = TypeVar("T")


def main(
    input_file: Path = typer.Argument(
        ...,
        metavar="INPUT",
        exists=True,
        dir_okay=False,
        readable=True,
        help="The input Markdown file.",
    ),
    output_file_or_dir: Path = typer.Option(
        Path.cwd(),
        "--output",
        "-o",
        writable=True,
        help="The output file or directory.",
        show_default="CWD",  # type: ignore[arg-type]  # See https://github.com/tiangolo/typer/issues/158
    ),
    convert_from_tex: bool = typer.Option(
        False,
        "--from-tex",
        help="Convert from LaTeX instead of Markdown.",
    ),
    convert_to_tex: bool = typer.Option(
        False,
        "--to-tex",
        help="Convert to LaTeX instead of PDF.",
    ),
) -> None:
    """
    Convert the INPUT Markdown file to PDF.
    """

    if convert_from_tex:
        tex_file = input_file
    else:
        tex_file = convert_md_to_tex(input_file)

    if convert_to_tex:
        file_to_output = tex_file
    else:
        file_to_output = convert_tex_to_pdf(tex_file)

    try:
        shutil.copy(file_to_output, output_file_or_dir)
    except shutil.SameFileError:
        pass


def convert_md_to_tex(input_file: Path) -> Path:
    PANDOC_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    converter = MarkdownToLaTeXConverter(
        pandoc_template_file=PANDOC_TEMPLATE_FILE,
        pandoc_extracted_resources_dir=PANDOC_EXTRACTED_RESOURCES_DIR,
        pandoc_generated_resources_dir=PANDOC_GENERATED_RESOURCES_DIR,
        pandoc_filters=[
            PandocFilter(
                PANDOC_LUA_FILTERS_DIR / "make_latex_table.lua",
                PandocFilterType.LUA,
            ),
            # NOTE: make_latex_code_block filter creates new inlines, therefore
            # it must be run before make_latex_code filter as it operates on
            # inlines.
            PandocFilter(
                PANDOC_LUA_FILTERS_DIR / "include_code_block.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                PANDOC_LUA_FILTERS_DIR / "trim_code_block.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                PANDOC_LUA_FILTERS_DIR / "make_latex_code_block.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                PANDOC_LUA_FILTERS_DIR / "make_latex_code.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                PANDOC_JSON_FILTER_DIR / "convert_svg_to_pdf.json",
                PandocFilterType.JSON,
            ),
        ],
        pandoc_output_dir=PANDOC_OUTPUT_DIR,
        latexmk_output_dir=LATEXMK_OUTPUT_DIR,
    )
    return converter.convert(input_file)


def convert_tex_to_pdf(input_file: Path) -> Path:
    LATEXMK_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    converter = LaTeXToPDFConverter(latexmk_output_dir=LATEXMK_OUTPUT_DIR)
    return converter.convert(input_file)


if __name__ == "__main__":
    typer.run(main)
