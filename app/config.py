from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    MONGO_URI: str
    MONGO_DB: str = "dodotask"
    JWT_SECRET: str
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60*24

    class Config:
        env_file = ".env"

settings = Settings()
