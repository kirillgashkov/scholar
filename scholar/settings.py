from pathlib import Path

ROOT = Path(__file__).parent


PANDOC_TEMPLATES_DIR = ROOT / "pandoc_templates"

PANDOC_TEMPLATE_FILE = PANDOC_TEMPLATES_DIR / "scholar.tex"


PANDOC_JSON_FILTERS_DIR = ROOT / "pandoc_json_filters"
PANDOC_LUA_FILTERS_DIR = ROOT / "pandoc_lua_filters"

CONVERT_SVG_TO_PDF_PANDOC_JSON_FILTER_FILE = (
    PANDOC_JSON_FILTERS_DIR / "convert_svg_to_pdf.py"
)
MAKE_LATEX_TABLE_PANDOC_LUA_FILTER_FILE = (
    PANDOC_LUA_FILTERS_DIR / "make_latex_table.lua"
)
MAKE_LATEX_LISTING_PANDOC_LUA_FILTER_FILE = (
    PANDOC_LUA_FILTERS_DIR / "make_latex_listing.lua"
)
INCLUDE_CODE_BLOCK_PANDOC_LUA_FILTER_FILE = (
    PANDOC_LUA_FILTERS_DIR / "include_code_block.lua"
)


CACHE_DIR = Path.cwd() / ".scholar"

MD_TO_TEX_CACHE_DIR = CACHE_DIR / "md-to-tex-cache"
TEX_TO_PDF_CACHE_DIR = CACHE_DIR / "tex-to-pdf-cache"

PANDOC_OUTPUT_DIR = MD_TO_TEX_CACHE_DIR / "pandoc-output"
PANDOC_EXTRACTED_RESOURCES_DIR = MD_TO_TEX_CACHE_DIR / "extracted-resources"
PANDOC_GENERATED_RESOURCES_DIR = MD_TO_TEX_CACHE_DIR / "generated-resources"

LATEXMK_OUTPUT_DIR = TEX_TO_PDF_CACHE_DIR / "latexmk-output"
