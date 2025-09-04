# app/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    MONGO_URI: str
    MONGO_DB: str = "dodotask"

    JWT_SECRET: str = "change-me"
    JWT_ALG: str = "HS256"
    TOKEN_EXPIRE_MINUTES: int = 60   # <— matches .env key

    # pydantic v2 config
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
        env_ignore_empty=True,
    )

settings = Settings()
