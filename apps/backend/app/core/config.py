import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "AI Workspace API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/v1"
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "ai-workspace-super-secret-jwt-key-32-chars-minimum-security")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 # 7 days
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./ai_workspace.db")
    
    # OpenAI
    OPENAI_API_KEY: str | None = os.getenv("OPENAI_API_KEY", None)
    DEFAULT_AI_MODEL: str = os.getenv("DEFAULT_AI_MODEL", "gpt-4o-mini")
    
    # Storage
    UPLOAD_DIR: str = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "uploads")
    
    # CORS
    BACKEND_CORS_ORIGINS: list[str] = ["*"]

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="allow")

settings = Settings()
