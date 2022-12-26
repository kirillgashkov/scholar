from dataclasses import dataclass


@dataclass
class Settings:
    """Settings for Scholar.

    Settings are loaded in the following order:

    1. Command line arguments,
    2. Environment variables,
    3. YAML front matter,
    4. YAML configuration file,
    5. Default values.
    """
