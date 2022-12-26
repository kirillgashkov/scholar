import re
import subprocess
import sys
from abc import ABC, abstractmethod
from collections.abc import Iterable
from pathlib import Path

import rich
import typer

from scholar.settings import PANDOC_LUA_FILTERS_DIR


class Converter(ABC):
    @abstractmethod
    def convert(self, input_file: Path) -> Path:
        pass


class MarkdownToLaTeXConverter(Converter):
    def __init__(
        self,
        *,
        pandoc_template_file: Path,
        pandoc_extracted_resources_dir: Path,
        pandoc_generated_resources_dir: Path,
        convert_svg_to_pdf_pandoc_json_filter_file: Path,
        make_latex_table_pandoc_lua_filter_file: Path,
        make_latex_code_block_pandoc_lua_filter_file: Path,
        make_latex_code_pandoc_lua_filter_file: Path,
        trim_code_block_pandoc_lua_filter_file: Path,
        include_code_block_pandoc_lua_filter_file: Path,
        pandoc_output_dir: Path,
        latexmk_output_dir: Path,
    ) -> None:
        self.pandoc_template_file = pandoc_template_file
        self.pandoc_extracted_resources_dir = pandoc_extracted_resources_dir
        self.pandoc_generated_resources_dir = pandoc_generated_resources_dir
        self.convert_svg_to_pdf_pandoc_json_filter_file = (
            convert_svg_to_pdf_pandoc_json_filter_file
        )
        self.make_latex_table_pandoc_lua_filter_file = (
            make_latex_table_pandoc_lua_filter_file
        )
        self.make_latex_code_block_pandoc_lua_filter_file = (
            make_latex_code_block_pandoc_lua_filter_file
        )
        self.make_latex_code_pandoc_lua_filter_file = (
            make_latex_code_pandoc_lua_filter_file
        )
        self.include_code_block_pandoc_lua_filter_file = (
            include_code_block_pandoc_lua_filter_file
        )
        self.trim_code_block_pandoc_lua_filter_file = (
            trim_code_block_pandoc_lua_filter_file
        )
        self.pandoc_output_dir = pandoc_output_dir
        self.latexmk_output_dir = latexmk_output_dir

    def convert(self, input_file: Path) -> Path:
        output_file = self.pandoc_output_dir / input_file.with_suffix(".tex").name

        try:
            rich.print("[bold yellow]Running pandoc")
            self._run_pandoc(input_file, output_file)
        except subprocess.CalledProcessError as e:
            rich.print("[bold red]Running pandoc failed")
            raise typer.Exit(1)

        return output_file

    def _run_pandoc(self, input_file: Path, output_file: Path) -> None:
        markdown_pandoc_input_format = _make_pandoc_format(
            "markdown_strict",
            enabled_extensions=[
                # Must-have extensions
                "header_attributes",
                "fenced_divs",
                "bracketed_spans",
                "fenced_code_blocks",
                "backtick_code_blocks",
                "fenced_code_attributes",
                "table_captions",
                "grid_tables",
                "pipe_tables",
                "inline_code_attributes",
                "raw_tex",
                "implicit_figures",
                "link_attributes",
                "citations",
                "yaml_metadata_block",
                "tex_math_dollars",
                # Commonmark-inspired extensions
                "escaped_line_breaks",
                "space_in_atx_header",
                "startnum",
                "all_symbols_escapable",
                "intraword_underscores",
                "shortcut_reference_links",
                # GFM-inspired extensions
                "task_lists",
                "strikeout",
                # Convenience extensions
                "smart",
            ],
        )
        latex_pandoc_output_format = _make_pandoc_format(
            "latex",
            disabled_extensions=["auto_identifiers"],
        )

        # WTF: At the time of writting this the value of this variable is supposed to
        # always pass the regular expression check below because it points to a
        # directory the path elements of which are pre-defined in Scholar's
        # 'settings.py' file. We keep the regular expression check to ensure that we
        # don't pass any unescaped paths to LaTeX and cause mayhem. Obviously this
        # solution is far from ideal but it will work for now.
        minted_package_option_outputdir = self.latexmk_output_dir.relative_to(
            Path.cwd()
        ).as_posix()

        if not re.match(r"^[A-Za-z0-9._\-\/]+$", minted_package_option_outputdir):
            print(
                f"Error: failed to provide a valid value for the 'outputdir' option of the 'minted' package",
                file=sys.stderr,
            )
            typer.Exit(1)

        subprocess.run(
            [
                "pandoc",
                # Format options
                "--from",
                markdown_pandoc_input_format,
                "--to",
                latex_pandoc_output_format,
                # Template options
                "--standalone",
                "--template",
                str(self.pandoc_template_file),
                # Writer options
                "--shift-heading-level-by",
                "-1",
                "--metadata",
                "csquotes=true",
                "--extract-media",
                str(self.pandoc_extracted_resources_dir),
                # Filter options
                "--filter",
                "pandoc-crossref",
                "--lua-filter",
                str(self.make_latex_table_pandoc_lua_filter_file),
                "--lua-filter",
                PANDOC_LUA_FILTERS_DIR / "merge_code_blocks_and_paragraph_captions.lua",
                "--lua-filter",
                str(self.include_code_block_pandoc_lua_filter_file),
                "--lua-filter",
                str(self.trim_code_block_pandoc_lua_filter_file),
                # NOTE: make_latex_code_block filter creates new inlines, therefore
                # it must be run before make_latex_code filter as it operates on
                # inlines.
                "--lua-filter",
                str(self.make_latex_code_block_pandoc_lua_filter_file),
                "--lua-filter",
                str(self.make_latex_code_pandoc_lua_filter_file),
                "--filter",
                str(self.convert_svg_to_pdf_pandoc_json_filter_file),
                # Other options
                "--metadata",
                f"generated-resources-directory={self.pandoc_generated_resources_dir}",
                "--variable",
                f"minted-package-option-outputdir={minted_package_option_outputdir}",
                # I/O options
                "--output",
                str(output_file),
                str(input_file),
            ],
            stdout=sys.stdout,
            stderr=sys.stderr,
            check=True,
        )


class LaTeXToPDFConverter(Converter):
    def __init__(self, *, latexmk_output_dir: Path) -> None:
        self.latexmk_output_dir = latexmk_output_dir

    def convert(self, input_file: Path) -> Path:
        try:
            rich.print("[bold yellow]Running latexmk")
            self._run_latexmk(input_file, self.latexmk_output_dir)
        except subprocess.CalledProcessError as e:
            rich.print("[bold red]Running latexmk failed")
            raise typer.Exit(1)

        return self.latexmk_output_dir / input_file.with_suffix(".pdf").name

    @staticmethod
    def _run_latexmk(input_file: Path, output_dir: Path) -> None:
        subprocess.run(
            [
                "latexmk",
                # Pipeline options
                "-xelatex",
                "-bibtex",
                # Interaction options
                "-interaction=nonstopmode",
                "-halt-on-error",
                "-file-line-error",
                # Other options
                "-shell-escape",  # Needed for 'minted', has security implications
                # I/O options
                "-output-directory=" + str(output_dir),
                str(input_file),
            ],
            stdout=sys.stdout,
            stderr=sys.stderr,
            check=True,
        )


def _make_pandoc_format(
    base_format: str,
    enabled_extensions: Iterable[str] | None = None,
    disabled_extensions: Iterable[str] | None = None,
) -> str:
    pandoc_format = base_format

    for extension in enabled_extensions or []:
        pandoc_format = f"{pandoc_format}+{extension}"

    for extension in disabled_extensions or []:
        pandoc_format = f"{pandoc_format}-{extension}"

    return pandoc_format
