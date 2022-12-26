from pathlib import Path
from typing import Any, Callable

from pydantic import BaseModel, BaseSettings, Extra, PrivateAttr
from pydantic.env_settings import SettingsSourceCallable
from yaml import safe_load


class SettingsGroup(BaseModel):
    class Config:
        extra = Extra.forbid


class ParagraphCaptionSettingsGroup(SettingsGroup):
    listing_prefixes: list[str] = [":", "Listing:"]


class Settings(BaseSettings):
    _cli_settings: dict[str, Any] = PrivateAttr()
    _yaml_front_matter_settings: dict[str, Any] = PrivateAttr()
    _yaml_config_file: Path | None = PrivateAttr()

    paragraph_caption: ParagraphCaptionSettingsGroup = ParagraphCaptionSettingsGroup()

    def __init__(
        self,
        *,
        _cli_settings: dict[str, Any] | None = None,
        _yaml_front_matter_settings: dict[str, Any] | None = None,
        _yaml_config_file: Path | None = None,
        **init_settings: Any,
    ) -> None:
        self._cli_settings = _cli_settings or {}
        self._yaml_front_matter_settings = _yaml_front_matter_settings or {}
        self._yaml_config_file = _yaml_config_file

        super().__init__(**init_settings)

    class Config:
        env_prefix = "scholar_"

        @classmethod
        def customise_sources(
            cls,
            init_settings: SettingsSourceCallable,
            env_settings: SettingsSourceCallable,
            file_secret_settings: SettingsSourceCallable,
        ) -> tuple[Callable[["Settings"], dict[str, Any]], ...]:
            return (
                init_settings,
                cli_settings_source,
                env_settings,
                file_secret_settings,
                yaml_front_matter_settings_source,
                yaml_config_file_settings_source,
            )


def cli_settings_source(settings: Settings) -> dict[str, Any]:
    return settings._cli_settings


def yaml_front_matter_settings_source(settings: Settings) -> dict[str, Any]:
    return settings._yaml_front_matter_settings


def yaml_config_file_settings_source(settings: Settings) -> dict[str, Any]:
    if not settings._yaml_config_file:
        return {}

    try:
        with open(settings._yaml_config_file) as f:
            return safe_load(f)
    except Exception as e:
        is_config_file_not_found_error = (
            isinstance(e, FileNotFoundError)
            and Path(e.filename) == settings._yaml_config_file
        )

        if is_config_file_not_found_error:
            raise ConfigFileNotFoundError(settings._yaml_config_file) from e

        raise FailedToLoadConfigFileError(settings._yaml_config_file) from e


class ConfigFileNotFoundError(Exception):
    def __init__(self, config_file: Path) -> None:
        self.config_file = config_file


class FailedToLoadConfigFileError(Exception):
    def __init__(self, config_file: Path) -> None:
        self.config_file = config_file
