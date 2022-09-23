import subprocess
import sys
from hashlib import sha256
from pathlib import Path
from typing import Any

from pandocfilters import Image, toJSONFilter  # type: ignore


def convert_svg_to_pdf(
    object_type: str,
    object_value: Any,
    output_format: str,
    document_metadata: dict[str, Any],
) -> Any:
    if output_format != "latex":
        return None

    if object_type != "Image":
        return None

    image_attributes, image_caption, [image_path_as_str, image_id] = object_value
    image_path = Path(image_path_as_str)

    if image_path.suffix.lower() != ".svg":
        return None

    filter_generated_resources_dirpath = _get_filter_generated_resources_dirpath(
        document_metadata
    )

    svg_image_path = image_path
    pdf_image_path = _get_pdf_image_path(
        svg_image_path, filter_generated_resources_dirpath
    )

    if not pdf_image_path.exists():
        filter_generated_resources_dirpath.mkdir(parents=True, exist_ok=True)
        _run_rsvg_convert(svg_image_path, pdf_image_path)

    return Image(image_attributes, image_caption, [str(pdf_image_path), image_id])


def _get_filter_generated_resources_dirpath(document_metadata: dict[str, Any]) -> Path:
    return (
        Path(document_metadata["generated_resources_dir"]["c"]) / "convert_svg_to_pdf"
    )


def _get_pdf_image_path(
    svg_image_path: Path, filter_generated_resources_dirpath: Path
) -> Path:
    with open(svg_image_path, "rb") as f:
        filename = str(sha256(f.read()).hexdigest()) + ".pdf"

    return filter_generated_resources_dirpath / filename


def _run_rsvg_convert(input_svg_image_path: Path, output_pdf_image_path: Path) -> None:
    subprocess.run(
        [
            "rsvg-convert",
            "--format",
            "pdf",
            "--output",
            str(output_pdf_image_path),
            str(input_svg_image_path),
        ],
        stdout=sys.stdout,
        stderr=sys.stderr,
        check=True,
    )


if __name__ == "__main__":
    toJSONFilter(convert_svg_to_pdf)
