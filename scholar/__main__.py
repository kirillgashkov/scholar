import shutil
import sys
from pathlib import Path
from typing import Any, Optional, TypeVar

import frontmatter
import rich
import typer

from scholar.constants import (
    LATEXMK_OUTPUT_DIR,
    PANDOC_EXTRACTED_RESOURCES_DIR,
    PANDOC_GENERATED_RESOURCES_DIR,
    PANDOC_JSON_FILTERS_DIR,
    PANDOC_LUA_FILTERS_DIR,
    PANDOC_OUTPUT_DIR,
    PANDOC_TEMPLATE_FILE,
    SCHOLAR_OUTPUT_DIR,
)
from scholar.converters import LaTeXToPDFConverter, MarkdownToLaTeXConverter
from scholar.settings import (
    ConfigFileNotFoundError,
    FailedToLoadConfigFileError,
    InvalidSettingsError,
    Settings,
)

T = TypeVar("T")


def main(
    input_file: Path = typer.Argument(
        ...,
        metavar="INPUT",
        exists=True,
        dir_okay=False,
        readable=True,
        help="The input Markdown file.",
    ),
    output_file_or_dir: Path = typer.Option(
        Path.cwd(),
        "--output",
        "-o",
        writable=True,
        help="The output file or directory.",
        show_default="CWD",  # type: ignore[arg-type]  # See https://github.com/tiangolo/typer/issues/158
    ),
    config_file: Optional[
        Path
    ] = typer.Option(  # See https://github.com/tiangolo/typer/issues/348
        None,
        "--config",
        exists=True,
        dir_okay=False,
        readable=True,
        help="The YAML config file.",
    ),
    convert_from_tex: bool = typer.Option(
        False,
        "--from-tex",
        help="Convert from LaTeX instead of Markdown.",
    ),
    convert_to_tex: bool = typer.Option(
        False,
        "--to-tex",
        help="Convert to LaTeX instead of PDF.",
    ),
) -> None:
    """
    Convert the INPUT Markdown file to PDF.
    """

    if convert_from_tex:
        yaml_front_matter_settings = {}
        md_file = None
    else:
        with open(input_file) as f:
            input_document = frontmatter.load(f)

        yaml_front_matter_settings = input_document.metadata
        md_file = SCHOLAR_OUTPUT_DIR / input_file.name

        SCHOLAR_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        with open(md_file, "w") as f:
            f.write(input_document.content)

    settings = load_settings(
        cli_settings={},
        yaml_front_matter_settings=yaml_front_matter_settings,
        yaml_config_file=config_file,
    )

    if convert_from_tex:
        tex_file = input_file
    else:
        assert md_file is not None
        tex_file = convert_md_to_tex(md_file, settings)

    if convert_to_tex:
        file_to_output = tex_file
    else:
        file_to_output = convert_tex_to_pdf(tex_file, settings)

    try:
        shutil.copy(file_to_output, output_file_or_dir)
    except shutil.SameFileError:
        pass


def load_settings(
    *,
    cli_settings: dict[str, Any],
    yaml_front_matter_settings: dict[str, Any],
    yaml_config_file: Path | None,
) -> Settings:
    try:
        settings = Settings(
            _cli_settings=cli_settings,
            _yaml_front_matter_settings=yaml_front_matter_settings,
            _yaml_config_file=yaml_config_file,
        )
    except ConfigFileNotFoundError as e:
        rich.print(
            f"[bold red]Error: [/bold red]Config file not found: {e.config_file}",
            file=sys.stderr,
        )
        raise typer.Exit(1)
    except FailedToLoadConfigFileError as e:
        rich.print(
            f"[bold red]Error: [/bold red]Failed to load config file: {e.config_file}",
            file=sys.stderr,
        )

        if cause := e.__cause__:
            rich.print(
                f"[bold blue]Detail: [/bold blue]Caused by {type(cause).__name__}: {cause}",
                file=sys.stderr,
            )

        raise typer.Exit(1)
    except InvalidSettingsError as e:
        rich.print(
            f"[bold red]Error: [/bold red]Settings are invalid",
            file=sys.stderr,
        )
        rich.print(
            f"[bold blue]Detail: [/bold blue]{e.validation_errors_detail}",
            file=sys.stderr,
        )
        rich.print(
            f"[bold blue]Hint: [/bold blue]{e.settings_sources_hint}",
            file=sys.stderr,
        )
        raise typer.Exit(1)

    return settings


def convert_md_to_tex(input_file: Path, settings: Settings) -> Path:
    PANDOC_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    converter = MarkdownToLaTeXConverter(
        pandoc_template_file=PANDOC_TEMPLATE_FILE,
        pandoc_lua_filters_dir=PANDOC_LUA_FILTERS_DIR,
        pandoc_json_filters_dir=PANDOC_JSON_FILTERS_DIR,
        pandoc_extracted_resources_dir=PANDOC_EXTRACTED_RESOURCES_DIR,
        pandoc_generated_resources_dir=PANDOC_GENERATED_RESOURCES_DIR,
        pandoc_output_dir=PANDOC_OUTPUT_DIR,
        latexmk_output_dir=LATEXMK_OUTPUT_DIR,
    )
    return converter.convert(input_file)


def convert_tex_to_pdf(input_file: Path, settings: Settings) -> Path:
    LATEXMK_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    converter = LaTeXToPDFConverter(latexmk_output_dir=LATEXMK_OUTPUT_DIR)
    return converter.convert(input_file)


if __name__ == "__main__":
    typer.run(main)
