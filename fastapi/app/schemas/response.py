# app/schemas/response.py
from typing import Generic, Optional, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class Envelope(BaseModel, Generic[T]):
    status: int
    message: str
    data: Optional[T] = None
