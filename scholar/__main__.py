from pathlib import Path

import typer


def main(
    input_path: Path = typer.Argument(
        ...,
        metavar="INPUT",
        exists=True,
        dir_okay=False,
        readable=True,
        help="The input Markdown file.",
    ),
    output_path: Path = typer.Option(
        Path.cwd(),
        "--output",
        "-o",
        writable=True,
        help="The output file or directory.",
        show_default="CWD",
    ),
    convert_to_tex: bool = typer.Option(
        False,
        "--to-tex",
        help="Convert to LaTeX instead of PDF.",
    ),
    convert_from_tex: bool = typer.Option(
        False,
        "--from-tex",
        help="Convert from LaTeX instead of Markdown.",
    ),
):
    """
    Convert the INPUT Markdown file to PDF.
    """
    ...


if __name__ == "__main__":
    typer.run(main)
