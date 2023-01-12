from pathlib import Path
from typing import Any

from scholar.constants import PANDOC_TEMPLATE_FILE
from scholar.settings import Settings


class Style:
    def __init__(
        self,
        *,
        template_file: Path,
        # filter_files: list[Path],  # Not supported yet
        variables: dict[str, Any],
    ):
        self.template_file = template_file
        # self.filter_files = filter_files  # Not supported yet
        self.variables = variables


class GostStyle(Style):
    def __init__(
        self,
        *,
        # title_page: Path | None,  # Implemented somewhere else for now.
        disable_main_section_numbering: bool,
        disable_section_page_breaks: bool,
        disable_numbering_within_section: bool,
    ) -> None:
        super().__init__(
            template_file=PANDOC_TEMPLATE_FILE,
            variables={
                # "title_page": title_page,  # Implemented somewhere else for now.
                "disable_main_section_numbering": disable_main_section_numbering,
                "disable_section_page_breaks": disable_section_page_breaks,
                "disable_numbering_within_section": disable_numbering_within_section,
            },
        )


class GostThesisStyle(GostStyle):
    def __init__(
        self,
        # *,
        # title_page: Path | None = None,  # Implemented somewhere else for now.
    ) -> None:
        super().__init__(
            # title_page=title_page,  # Implemented somewhere else for now.
            disable_main_section_numbering=False,
            disable_section_page_breaks=False,
            disable_numbering_within_section=False,
        )


class GostReportStyle(GostStyle):
    def __init__(
        self,
        # *,
        # title_page: Path | None = None,  # Implemented somewhere else for now.
    ) -> None:
        super().__init__(
            # title_page=title_page,  # Implemented somewhere else for now.
            disable_main_section_numbering=True,
            disable_section_page_breaks=True,
            disable_numbering_within_section=True,
        )


DEFAULT_STYLE = "gost_thesis"


def get_styles(settings: Settings) -> dict[str, Style]:
    return {
        "gost_thesis": GostThesisStyle(),
        "gost_report": GostReportStyle(),
    }


def get_style(settings: Settings) -> Style:
    return get_styles(settings)[settings.style]
