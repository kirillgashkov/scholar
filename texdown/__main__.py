import shutil
import subprocess
import sys
from pathlib import Path

import click


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

    click.echo(click.style("Running pandoc", fg="yellow", bold=True))

    pandoc_command = [
        "pandoc",
        "--from",
        "markdown",
        "--to",
        "latex",
        "--standalone",
        "--output",
        str(generated_latex_file),
        str(input_markdown_file),
    ]
    subprocess.run(
        pandoc_command,
        stdout=sys.stdout,
        stderr=sys.stderr,
        cwd=subprocess_workdir,
        check=True,
    )

    click.echo(click.style("Running latexmk", fg="yellow", bold=True))

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
