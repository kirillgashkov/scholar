from pathlib import Path

ROOT = Path(__file__).parent


PANDOC_TEMPLATES_DIR = ROOT / "pandoc_templates"

PANDOC_TEMPLATE_FILE = PANDOC_TEMPLATES_DIR / "scholar.tex"


PANDOC_FILTERS_DIR = ROOT / "pandoc_filters"

CONVERT_SVG_TO_PDF_PANDOC_FILTER_FILE = PANDOC_FILTERS_DIR / "convert_svg_to_pdf.py"


CACHE_DIR = Path.cwd() / ".scholar"

MD_TO_TEX_CACHE_DIR = CACHE_DIR / "md-to-tex-cache"
TEX_TO_PDF_CACHE_DIR = CACHE_DIR / "tex-to-pdf-cache"

PANDOC_EXTRACTED_RESOURCES_DIR = MD_TO_TEX_CACHE_DIR / "extracted-resources"
PANDOC_GENERATED_RESOURCES_DIR = MD_TO_TEX_CACHE_DIR / "generated-resources"
