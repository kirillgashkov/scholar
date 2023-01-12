import sys
from pathlib import Path
from typing import Any, Callable

import rich
from pydantic import (
    BaseModel,
    BaseSettings,
    Extra,
    PrivateAttr,
    ValidationError,
    root_validator,
    validator,
)
from pydantic.env_settings import SettingsSourceCallable
from yaml import safe_load

from scholar.constants import CACHE_DIR


class SettingsGroup(BaseModel):
    class Config:
        extra = Extra.allow

    def _get_unknown_settings(self) -> list[str]:
        unknown_settings = []

        for field_set in self.__fields_set__:
            if field_set not in self.__fields__:
                unknown_settings.append(field_set)
                continue

            value = getattr(self, field_set)

            if isinstance(value, SettingsGroup):
                unknown_settings.extend(
                    f"{field_set}.{extra_setting}"
                    for extra_setting in value._get_unknown_settings()
                )

        return unknown_settings


class SettingsSourceLogEntry(BaseModel):
    source: str
    settings: dict[str, Any]


class Settings(BaseSettings):
    _settings_source_log: list[SettingsSourceLogEntry] = PrivateAttr()

    _cli_settings: dict[str, Any] = PrivateAttr()
    _yaml_front_matter_settings: dict[str, Any] = PrivateAttr()
    _yaml_config_file: Path | None = PrivateAttr()

    cache_dir: Path = CACHE_DIR
    rsvg_convert_executable: str = "rsvg-convert"

    style: str = "gost_thesis"

    title_page: Path | None = None
    references: dict[str, str] = {}

    @validator("cache_dir")
    def cache_dir_must_be_default(cls, v: Path) -> Path:
        if v != CACHE_DIR:
            raise ValueError("Non-default cache_dir is not yet supported.")
        return v

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
        self._settings_source_log = []

        try:
            super().__init__(**init_settings)
        except ValidationError as e:
            loaded_settings_sources = []

            for settings_source_log_entry in self._settings_source_log:
                if settings_source_log_entry.settings:
                    loaded_settings_sources.append(settings_source_log_entry.source)

            settings_sources_hint = (
                "Loaded settings sources: " + ", ".join(loaded_settings_sources)
                if loaded_settings_sources
                else "No settings sources loaded"
            )

            raise InvalidSettingsError(
                validation_errors_detail=str(e),
                settings_sources_hint=settings_sources_hint,
            )

    class Config:
        extra = Extra.allow
        env_prefix = "scholar_"

        @classmethod
        def customise_sources(
            cls,
            init_settings: SettingsSourceCallable,
            env_settings: SettingsSourceCallable,
            file_secret_settings: SettingsSourceCallable,
        ) -> tuple[Callable[["Settings"], dict[str, Any]], ...]:
            return (
                _logged_source("init", init_settings),
                _logged_source("cli", cli_settings_source),
                _logged_source("env", env_settings),
                _logged_source("file_secret", file_secret_settings),
                _logged_source("yaml_front_matter", yaml_front_matter_settings_source),
                _logged_source("yaml_config_file", yaml_config_file_settings_source),
            )

    @root_validator
    def _warn_about_unknown_settings(cls, values: dict[str, Any]) -> dict[str, Any]:
        unknown_settings = []

        for field_set in values:
            if field_set not in cls.__fields__:
                unknown_settings.append(field_set)
                continue

            value = values[field_set]

            if isinstance(value, SettingsGroup):
                unknown_settings.extend(
                    f"{field_set}.{extra_setting}"
                    for extra_setting in value._get_unknown_settings()
                )

        for unknown_setting in unknown_settings:
            rich.print(
                f"[bold yellow]Warning: [/bold yellow]Unknown setting: {unknown_setting}",
                file=sys.stderr,
            )

        return values


def _logged_source(
    source_name: str,
    settings_source: Callable[[Settings], dict[str, Any]],
) -> Callable[[Settings], dict[str, Any]]:
    def wrapper(settings: Settings) -> dict[str, Any]:
        settings_dict = settings_source(settings)

        settings._settings_source_log.append(
            SettingsSourceLogEntry(
                source=source_name,
                settings=settings_dict,
            )
        )

        return settings_dict

    return wrapper


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


class InvalidSettingsError(Exception):
    def __init__(
        self, validation_errors_detail: str, settings_sources_hint: str
    ) -> None:
        self.validation_errors_detail = validation_errors_detail
        self.settings_sources_hint = settings_sources_hint
