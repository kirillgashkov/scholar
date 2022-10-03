from typing import Any

from pandocfilters import Image, toJSONFilter  # type: ignore


def make_latex_table(
    object_type: str,
    object_value: Any,
    output_format: str,
    document_metadata: dict[str, Any],
):
    pass


if __name__ == "__main__":
    toJSONFilter(make_latex_table)
