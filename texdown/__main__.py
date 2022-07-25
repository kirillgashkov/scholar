from pathlib import Path

import click


@click.command()
@click.option(
    "--output",
    "-o",
    type=click.Path(
        dir_okay=False,  # The path can't be a directory
        writable=True,  # The path must be writable
        path_type=Path,  # Convert the path to pathlib's Path
    ),
    help="A PDF file to output to",
)
@click.argument(
    "input",
    type=click.Path(
        exists=True,  # The path must exist
        readable=True,  # The path must be readable
        path_type=Path,  # Convert the path to pathlib's Path
    ),
)
def texdown(input: Path, output: Path) -> None:
    """Convert the INPUT Markdown file to a PDF."""


if __name__ == "__main__":
    texdown()
