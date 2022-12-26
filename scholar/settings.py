from pathlib import Path
from typing import Any, Callable

from pydantic import BaseSettings, PrivateAttr
from pydantic.env_settings import SettingsSourceCallable
from yaml import safe_load


class Settings(BaseSettings):
    _cli_settings: dict[str, Any] = PrivateAttr()
    _yaml_front_matter_settings: dict[str, Any] = PrivateAttr()
    _yaml_config_file: Path | None = PrivateAttr()

    # TODO: Add settings

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

    with open(settings._yaml_config_file) as f:
        return safe_load(f)
