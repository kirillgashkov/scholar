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


class MarkdownToLatexConverter(Converter):
    def __init__(
        self,
        markdown_pandoc_input_format: str,
        latex_pandoc_output_format: str,
        latex_pandoc_template_file: Path,
        pandoc_filters: Iterable[str],
        pandoc_custom_options: Iterable[str],
        cache_dir: Path,
    ) -> None:
        self.markdown_pandoc_input_format = markdown_pandoc_input_format
        self.latex_pandoc_output_format = latex_pandoc_output_format
        self.latex_pandoc_template_file = latex_pandoc_template_file
        self.pandoc_filters = list(pandoc_filters)
        self.pandoc_custom_options = list(pandoc_custom_options)
        self.cache_dir = cache_dir

    def convert(self, input_file: Path) -> Path:
        output_file = self.cache_dir / input_file.with_suffix("tex").name

        try:
            print("[bold yellow]Running pandoc")
            self._run_pandoc(input_file, output_file)
        except subprocess.CalledProcessError as e:
            print("[bold red]Running pandoc failed")
            raise e

        return output_file

    def _run_pandoc(self, input_file: Path, output_file: Path) -> None:
        subprocess.run(
            [
                "pandoc",
                # Format options
                "--from",
                self.markdown_pandoc_input_format,
                "--to",
                self.latex_pandoc_output_format,
                # Template options
                "--standalone",
                "--template",
                str(self.latex_pandoc_template_file),
                # Filter options
                *self._pandoc_filter_options(),
                # Custom options
                *self.pandoc_custom_options,
                # I/O options
                "--output",
                str(output_file),
                str(input_file),
            ],
            stdout=sys.stdout,
            stderr=sys.stderr,
            check=True,
        )

    def _pandoc_filter_options(self) -> Iterable[str]:
        for pandoc_filter in self.pandoc_filters:
            yield "--filter"
            yield pandoc_filter


class LatexToPdfConverter(Converter):
    ...
