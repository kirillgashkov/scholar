import subprocess
import sys
from abc import ABC, abstractmethod
from collections.abc import Iterable
from pathlib import Path

from rich import print


class Converter(ABC):
    @abstractmethod
    def convert(self, input_file: Path) -> Path:
        pass


class MarkdownToLaTeXConverter(Converter):
    def __init__(self, pandoc_template_file: Path, cache_dir: Path) -> None:
        self.pandoc_template_file = pandoc_template_file
        self.cache_dir = cache_dir

    def convert(self, input_file: Path) -> Path:
        output_file = self.cache_dir / input_file.with_suffix(".tex").name

        try:
            print("[bold yellow]Running pandoc")
            self._run_pandoc(input_file, output_file)
        except subprocess.CalledProcessError as e:
            print("[bold red]Running pandoc failed")
            raise e

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
            ],
        )
        latex_pandoc_output_format = _make_pandoc_format(
            "latex", disabled_extensions=["auto_identifiers", "smart"]
        )

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
                # Filter options
                "--filter",
                "pandoc-crossref",
                # Custom options
                "--shift-heading-level-by",
                "-1",
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
    def __init__(self, cache_dir: Path) -> None:
        self.cache_dir = cache_dir

    def convert(self, input_file: Path) -> Path:
        output_dir = self.cache_dir

        try:
            print("[bold yellow]Running latexmk")
            self._run_latexmk(input_file, output_dir)
        except subprocess.CalledProcessError as e:
            print("[bold red]Running latexmk failed")
            raise e

        return output_dir / input_file.with_suffix(".pdf").name

    def _run_latexmk(self, input_file: Path, output_dir: Path) -> None:
        subprocess.run(
            [
                "latexmk",
                # Conversion options
                "-xelatex",
                "-bibtex",
                # Interaction options
                "-interaction=nonstopmode",
                "-halt-on-error",
                "-file-line-error",
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
