from pathlib import Path

ROOT = Path(__file__).parent


PANDOC_TEMPLATES_DIR = ROOT / "pandoc_templates"

PANDOC_TEMPLATE_FILE = PANDOC_TEMPLATES_DIR / "scholar.tex"


CACHE_DIR = Path.cwd() / ".scholar"

MD_TO_TEX_CACHE_DIR = CACHE_DIR / "md-to-tex-cache"
TEX_TO_PDF_CACHE_DIR = CACHE_DIR / "tex-to-pdf-cache"

PANDOC_EXTRACTED_RESOURCES_DIR = MD_TO_TEX_CACHE_DIR / "extracted-resources"
