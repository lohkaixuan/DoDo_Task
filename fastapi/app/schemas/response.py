# ==================================================
# Program Name   : response.py
# Purpose        : Standard API response envelope schema (uniform status/message/data wrapper)
# Developer      : Miss. Yap Shuet Khey
# Student ID     : TP074066
# Course         : Bachelor of Software Engineering (Hons)
# Created Date   : 18 August 2025
# Last Modified  : 20 October 2025
# ==================================================

from typing import Generic, Optional, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class Envelope(BaseModel, Generic[T]):
    status: int
    message: str
    data: Optional[T] = None
