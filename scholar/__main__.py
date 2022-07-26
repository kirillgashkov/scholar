import shutil
from pathlib import Path
from typing import TypeVar

import typer

from scholar.converters import LaTeXToPDFConverter, MarkdownToLaTeXConverter
from scholar.settings import (
    CONVERT_SVG_TO_PDF_PANDOC_JSON_FILTER_FILE,
    MAKE_LATEX_TABLE_PANDOC_LUA_FILTER_FILE,
    MD_TO_TEX_CACHE_DIR,
    PANDOC_EXTRACTED_RESOURCES_DIR,
    PANDOC_GENERATED_RESOURCES_DIR,
    PANDOC_TEMPLATE_FILE,
    TEX_TO_PDF_CACHE_DIR,
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
    MD_TO_TEX_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    converter = MarkdownToLaTeXConverter(
        PANDOC_TEMPLATE_FILE,
        PANDOC_EXTRACTED_RESOURCES_DIR,
        PANDOC_GENERATED_RESOURCES_DIR,
        CONVERT_SVG_TO_PDF_PANDOC_JSON_FILTER_FILE,
        MAKE_LATEX_TABLE_PANDOC_LUA_FILTER_FILE,
        MD_TO_TEX_CACHE_DIR,
    )
    return converter.convert(input_file)


def convert_tex_to_pdf(input_file: Path) -> Path:
    TEX_TO_PDF_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    converter = LaTeXToPDFConverter(TEX_TO_PDF_CACHE_DIR)
    return converter.convert(input_file)


if __name__ == "__main__":
    typer.run(main)
