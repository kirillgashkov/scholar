from collections.abc import Callable
from pathlib import Path
from typing import TypeVar

import typer

T = TypeVar("T")


class MutuallyExclusiveOptionGroup:
    def __init__(self) -> None:
        self.other_param: typer.CallbackParam | None = None

    def make_callback(self) -> Callable[[typer.Context, typer.CallbackParam, T], T]:
        def callback(ctx: typer.Context, param: typer.CallbackParam, value: T) -> T:
            if self.other_param:
                raise typer.BadParameter(
                    f"'{param.name}' is mutually exclusive with '{self.other_param.name}'"
                )
            else:
                self.other_param = param

            return value

        return callback


conversion_mode_callback_for_mutual_exclusivity = (
    MutuallyExclusiveOptionGroup().make_callback()
)


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
        show_default="CWD",  # type: ignore[arg-type]  # See https://github.com/tiangolo/typer/issues/158
    ),
    convert_to_tex: bool = typer.Option(
        False,
        "--to-tex",
        help="Convert to LaTeX instead of PDF.",
        callback=conversion_mode_callback_for_mutual_exclusivity,
    ),
    convert_from_tex: bool = typer.Option(
        False,
        "--from-tex",
        help="Convert from LaTeX instead of Markdown.",
        callback=conversion_mode_callback_for_mutual_exclusivity,
    ),
) -> None:
    """
    Convert the INPUT Markdown file to PDF.
    """


if __name__ == "__main__":
    typer.run(main)
