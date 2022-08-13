import json
import shutil
import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path

import click


def make_pandoc_input_format(
    base_format: str,
    enabled_extensions: Iterable[str] | None = None,
    disabled_extensions: Iterable[str] | None = None,
) -> str:
    if enabled_extensions is None:
        enabled_extensions = []
    if disabled_extensions is None:
        disabled_extensions = []

    return (
        base_format
        + "".join(f"+{extension}" for extension in enabled_extensions)
        + "".join(f"-{extension}" for extension in disabled_extensions)
    )


@click.command()
@click.option(
    "--output",
    "-o",
    type=click.Path(writable=True, path_type=Path),
    help="An output file or directory",
)
@click.help_option("--help", "-h")
@click.argument(
    "input",
    type=click.Path(exists=True, dir_okay=False, readable=True, path_type=Path),
)
def texdown(input: Path, output: Path | None) -> None:
    """Convert the INPUT Markdown file to PDF."""

    if output is None:
        output = Path.cwd()

    subprocess_workdir = Path(".texdown").absolute()
    subprocess_workdir.mkdir(parents=True, exist_ok=True)

    input_markdown_file = input.absolute()
    generated_latex_file = subprocess_workdir / input.with_suffix(".tex").name
    generated_pdf_file = subprocess_workdir / input.with_suffix(".pdf").name
    if output.is_dir():
        output_pdf_file = output.absolute() / input.with_suffix(".pdf").name
    else:
        output_pdf_file = output.absolute()

    pandoc_markdown_extensions = [
        # Required extensions
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
    ]
    pandoc_command = [
        "pandoc",
        "--from",
        make_pandoc_input_format(
            "markdown_strict", enabled_extensions=pandoc_markdown_extensions
        ),
        "--to",
        "latex",
        "--standalone",
        "--output",
        str(generated_latex_file),
        str(input_markdown_file),
    ]

    click.echo(click.style("Running pandoc", fg="yellow", bold=True))
    click.echo(click.style(json.dumps(pandoc_command, indent=4), bold=True))

    subprocess.run(
        pandoc_command,
        stdout=sys.stdout,
        stderr=sys.stderr,
        cwd=subprocess_workdir,
        check=True,
    )

    latexmk_command = [
        "latexmk",
        "-xelatex",
        "-bibtex",
        "-interaction=nonstopmode",
        "-halt-on-error",
        "-file-line-error",
        "-output-directory=" + str(subprocess_workdir),
        str(generated_latex_file),
    ]

    click.echo(click.style("Running latexmk", fg="yellow", bold=True))
    click.echo(click.style(json.dumps(latexmk_command, indent=4), bold=True))

    subprocess.run(
        latexmk_command,
        stdout=sys.stdout,
        stderr=sys.stderr,
        cwd=subprocess_workdir,
        check=True,
    )

    shutil.copy(generated_pdf_file, output_pdf_file)


if __name__ == "__main__":
    texdown()
