from pathlib import Path
from typing import Any

from scholar.settings import Settings


class Style:
    def __init__(
        self,
        *,
        # template_file: Path,  # Not supported yet
        # filter_files: list[Path],  # Not supported yet
        variables: dict[str, Any],
    ):
        # self.template_file = template_file  # Not supported yet
        # self.filter_files = filter_files  # Not supported yet
        self.variables = variables


class GostStyle(Style):
    def __init__(
        self,
        *,
        title_page: Path | None,
        disable_main_section_numbering: bool,
        disable_section_page_breaks: bool,
        disable_numbering_within_section: bool,
    ):
        super().__init__(
            variables={
                "title_page": title_page,
                "disable_main_section_numbering": disable_main_section_numbering,
                "disable_section_page_breaks": disable_section_page_breaks,
                "disable_numbering_within_section": disable_numbering_within_section,
            },
        )


class GostThesisStyle(GostStyle):
    def __init__(self, *, title_page: Path | None = None):
        super().__init__(
            title_page=title_page,
            disable_main_section_numbering=False,
            disable_section_page_breaks=False,
            disable_numbering_within_section=False,
        )


class GostReportStyle(GostStyle):
    def __init__(self, *, title_page: Path | None = None):
        super().__init__(
            title_page=title_page,
            disable_main_section_numbering=True,
            disable_section_page_breaks=True,
            disable_numbering_within_section=True,
        )


def get_styles(settings: Settings) -> dict[str, Style]:
    return {
        "gost_thesis": GostThesisStyle(title_page=settings.title_page),
        "gost_report": GostReportStyle(title_page=settings.title_page),
    }


def get_style(settings: Settings) -> Style:
    return get_styles(settings)[settings.style]
