import json
import re
import subprocess
import sys
from abc import ABC, abstractmethod
from collections.abc import Iterable
from enum import Enum
from pathlib import Path
from typing import Any

import panflute
import rich
import typer

from scholar.settings import Settings


class Converter(ABC):
    @abstractmethod
    def convert(self, input_file: Path) -> Path:
        pass


class PandocFilterType(str, Enum):
    LUA = "lua"
    JSON = "json"


class PandocFilter:
    def __init__(
        self, filter_program: Path | str, filter_type: PandocFilterType
    ) -> None:
        self.filter_program = filter_program
        self.filter_type = filter_type


class MarkdownToLaTeXConverter(Converter):
    def __init__(
        self,
        *,
        pandoc_template_file: Path,
        pandoc_lua_filters_dir: Path,
        pandoc_json_filters_dir: Path,
        pandoc_extracted_resources_dir: Path,
        pandoc_generated_resources_dir: Path,
        generated_biblatex_file: Path,
        pandoc_output_dir: Path,
        latexmk_output_dir: Path,
        settings: Settings,
    ) -> None:
        self.pandoc_template_file = pandoc_template_file
        self.pandoc_lua_filters_dir = pandoc_lua_filters_dir
        self.pandoc_json_filters_dir = pandoc_json_filters_dir
        self.pandoc_extracted_resources_dir = pandoc_extracted_resources_dir
        self.pandoc_generated_resources_dir = pandoc_generated_resources_dir
        self.generated_biblatex_file = generated_biblatex_file
        self.pandoc_output_dir = pandoc_output_dir
        self.latexmk_output_dir = latexmk_output_dir
        self.settings = settings

    def convert(self, input_file: Path) -> Path:
        metadata_json_file = (
            self.pandoc_output_dir / input_file.with_suffix(".metadata.json").name
        )
        content_json_file = (
            self.pandoc_output_dir / input_file.with_suffix(".content.json").name
        )
        output_tex_file = self.pandoc_output_dir / input_file.with_suffix(".tex").name

        rich.print("[bold yellow]Generating BibLaTeX from metadata")
        self._generate_biblatex_file()

        rich.print("[bold yellow]Generating Pandoc JSON from metadata")
        self._generate_metadata_json_file(output_metadata_json_file=metadata_json_file)

        try:
            rich.print(
                "[bold yellow]Running Pandoc to generate Pandoc JSON from content"
            )
            self._run_pandoc_from_md_to_json(
                input_md_file=input_file,
                output_content_json_file=content_json_file,
            )
        except subprocess.CalledProcessError as e:
            rich.print("[bold red]Running Pandoc (Markdown to JSON) failed")
            raise typer.Exit(1)

        try:
            rich.print(
                "[bold yellow]Running Pandoc to generate LaTeX from Pandoc JSONs"
            )
            self._run_pandoc_from_jsons_to_tex(
                input_metadata_json_file=metadata_json_file,
                input_content_json_file=content_json_file,
                output_tex_file=output_tex_file,
            )
        except subprocess.CalledProcessError as e:
            rich.print("[bold red]Running Pandoc (JSONs to LaTeX) failed")
            raise typer.Exit(1)

        return output_tex_file

    def _make_markdown_pandoc_input_format(self) -> str:
        return _make_pandoc_format(
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

    def _make_latex_pandoc_output_format(self) -> str:
        return _make_pandoc_format(
            "latex",
            disabled_extensions=["auto_identifiers"],
        )

    def _make_markdown_pandoc_reader_options(self) -> list[str]:
        return [
            "--shift-heading-level-by",
            "-1",
            "--extract-media",
            str(self.pandoc_extracted_resources_dir),
        ]

    def _make_latex_pandoc_writer_filter_options(self) -> list[str]:
        pandoc_filters = [
            PandocFilter(
                self.pandoc_lua_filters_dir / "make_latex_table.lua",
                PandocFilterType.LUA,
            ),
            # NOTE: merge_code_blocks_and_paragraph_captions creates new attributes for
            # code blocks.
            PandocFilter(
                (
                    self.pandoc_lua_filters_dir
                    / "merge_code_blocks_and_paragraph_captions.lua"
                ),
                PandocFilterType.LUA,
            ),
            # NOTE: make_latex_code_block filter creates new inlines, therefore
            # it must be run before make_latex_code filter as it operates on
            # inlines.
            PandocFilter(
                self.pandoc_lua_filters_dir / "include_code_block.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "trim_code_block.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "make_latex_code_block.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "make_latex_code.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "render_references_in_text.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "render_citations_in_text.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "render_references_container.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "render_table_of_contents_container.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_lua_filters_dir / "make_and_render_sections.lua",
                PandocFilterType.LUA,
            ),
            PandocFilter(
                self.pandoc_json_filters_dir / "convert_svg_to_pdf.py",
                PandocFilterType.JSON,
            ),
        ]

        pandoc_filter_options = []
        for pandoc_filter in pandoc_filters:
            if pandoc_filter.filter_type == PandocFilterType.LUA:
                pandoc_filter_options.extend(
                    ["--lua-filter", str(pandoc_filter.filter_program)]
                )
            elif pandoc_filter.filter_type == PandocFilterType.JSON:
                pandoc_filter_options.extend(
                    ["--filter", str(pandoc_filter.filter_program)]
                )
            else:
                raise ValueError(f"Unknown filter type: {pandoc_filter.filter_type}")

        return pandoc_filter_options

    def _make_latex_pandoc_writer_options(self) -> list[str]:
        return [
            "--metadata",
            "csquotes=true",
        ]

    def _convert_string_from_md_to_tex_using_pandoc(
        self, *, input_md_string: str
    ) -> str:
        try:
            return subprocess.check_output(
                [
                    "pandoc",
                    "--from",
                    self._make_markdown_pandoc_input_format(),
                    "--to",
                    self._make_latex_pandoc_output_format(),
                    *self._make_markdown_pandoc_reader_options(),
                    *self._make_latex_pandoc_writer_options(),
                    # NOTE: Filters are not available yet because the 'scholar' metadata
                    # field is not created yet.
                    # # *self._make_latex_pandoc_writer_filter_options(),
                ],
                input=input_md_string,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            rich.print(
                "[bold red]Error: [/bold red]Failed to convert Markdown string to LaTeX."
            )
            raise typer.Exit(1)

    def _generate_biblatex_file(self) -> None:
        biblatex_file_content = ""

        is_first_reference = True

        for reference_id, reference_text_md in self.settings.references.items():
            raw_reference_text_tex = self._convert_string_from_md_to_tex_using_pandoc(
                input_md_string=reference_text_md
            )
            # WTF: Pandoc can add extra whitespace to the the output string even if the
            # input string doesn't have it (particularly at the end of the string).
            reference_text_tex = raw_reference_text_tex.strip()

            if not is_first_reference:
                biblatex_file_content += "\n"

            # NOTE: This is a custom entry type that has to be defined in the template.
            biblatex_file_content += "@scholar{" + reference_id + ",\n"
            biblatex_file_content += "    text = {" + reference_text_tex + "}\n"
            biblatex_file_content += "}\n"

        with open(self.generated_biblatex_file, "w") as f:
            f.write(biblatex_file_content)

    def _generate_metadata_json_file(self, *, output_metadata_json_file: Path) -> None:
        # WTF: At the time of writting this the value of this variable is supposed to
        # always pass the regular expression check below because it points to a
        # directory the path elements of which are pre-defined in Scholar's
        # 'settings.py' file. We keep the regular expression check to ensure that we
        # don't pass any unescaped paths to LaTeX and cause mayhem. Obviously this
        # solution is far from ideal but it will work for now.
        minted_package_option_outputdir = self.latexmk_output_dir.relative_to(
            Path.cwd()
        ).as_posix()

        # WTF: Same for the biblatex resource file.
        biblatex_bibresource = self.generated_biblatex_file.relative_to(
            Path.cwd()
        ).as_posix()

        pattern = re.compile(r"^[A-Za-z0-9._\-\/]+$")

        if not pattern.match(minted_package_option_outputdir):
            rich.print(
                f"[bold red]Error: [/bold red]Failed to provide a valid value for the 'outputdir' option of the 'minted' package",
                file=sys.stderr,
            )
            typer.Exit(1)

        if not pattern.match(biblatex_bibresource):
            rich.print(
                f"[bold red]Error: [/bold red]Failed to provide a valid value for the '\\addbibresouce' command of the 'biblatex' package",
                file=sys.stderr,
            )
            typer.Exit(1)

        metadata = _value_to_metavalue(
            {
                "scholar": {
                    "settings": self.settings.dict(),
                    "variables": {
                        "biblatex_bibresource": biblatex_bibresource,
                    },
                },
                "generated-resources-directory": str(
                    self.pandoc_generated_resources_dir
                ),
                "minted-package-option-outputdir": str(minted_package_option_outputdir),
            }
        )

        with open(output_metadata_json_file, "w") as f:
            json.dump(panflute.Doc(metadata=metadata).to_json(), f, ensure_ascii=False)

    def _run_pandoc_from_md_to_json(
        self, *, input_md_file: Path, output_content_json_file: Path
    ) -> None:
        markdown_pandoc_input_format = self._make_markdown_pandoc_input_format()
        json_pandoc_output_format = "json"

        subprocess.run(
            [
                "pandoc",
                # Format options
                "--from",
                markdown_pandoc_input_format,
                "--to",
                json_pandoc_output_format,
                # Reader options
                *self._make_markdown_pandoc_reader_options(),
                # I/O options
                "--output",
                str(output_content_json_file),
                str(input_md_file),
            ],
            stdout=sys.stdout,
            stderr=sys.stderr,
            check=True,
        )

    def _run_pandoc_from_jsons_to_tex(
        self,
        *,
        input_metadata_json_file: Path,
        input_content_json_file: Path,
        output_tex_file: Path,
    ) -> None:
        json_pandoc_input_format = "json"
        latex_pandoc_output_format = self._make_latex_pandoc_output_format()

        subprocess.run(
            [
                "pandoc",
                # Format options
                "--from",
                json_pandoc_input_format,
                "--to",
                latex_pandoc_output_format,
                # Template options
                "--standalone",
                "--template",
                str(self.pandoc_template_file),
                # Writer options
                *self._make_latex_pandoc_writer_options(),
                *self._make_latex_pandoc_writer_filter_options(),
                # I/O options
                "--output",
                str(output_tex_file),
                # NOTE: Last input argument wins in case of duplicate keys.
                str(input_content_json_file),
                str(input_metadata_json_file),
            ],
            stdout=sys.stdout,
            stderr=sys.stderr,
            check=True,
        )


class LaTeXToPDFConverter(Converter):
    def __init__(self, *, latexmk_output_dir: Path, settings: Settings) -> None:
        self.latexmk_output_dir = latexmk_output_dir
        self.settings = settings

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


def _value_to_metavalue(value: Any) -> panflute.MetaValue:
    if isinstance(value, dict):
        return panflute.MetaMap(**{k: _value_to_metavalue(v) for k, v in value.items()})
    elif isinstance(value, list):
        return panflute.MetaList(*[_value_to_metavalue(v) for v in value])
    elif isinstance(value, bool):
        return panflute.MetaBool(value)
    else:
        return panflute.MetaString(str(value))
