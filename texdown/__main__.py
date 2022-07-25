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
def texdown(input: Path, output: Path) -> None:
    """Convert the INPUT Markdown file to a PDF."""


if __name__ == "__main__":
    texdown()
