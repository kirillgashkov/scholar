from pathlib import Path

import click


@click.command()
@click.option(
    "--output",
    "-o",
    type=click.Path(dir_okay=False, writable=True, path_type=Path),
    help="A PDF file to output to",
)
@click.argument(
    "input",
    type=click.Path(exists=True, readable=True, path_type=Path),
)
def texdown(input: Path, output: Path) -> None:
    """Convert the INPUT Markdown file to a PDF."""


if __name__ == "__main__":
    texdown()
