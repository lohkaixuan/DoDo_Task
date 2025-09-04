# app/utils/response.py
from fastapi import status as http
from app.schemas.response import Envelope  # or: from ..schemas.response import Envelope

def ok(data=None, message: str = "OK", status_code: int = http.HTTP_200_OK):
    return Envelope(status=status_code, message=message, data=data)

def created(data=None, message: str = "Created"):
    return Envelope(status=http.HTTP_201_CREATED, message=message, data=data)

def no_content(message: str = "No Content"):
    return Envelope(status=http.HTTP_204_NO_CONTENT, message=message, data=None)

def fail(message: str = "Error", status_code: int = http.HTTP_400_BAD_REQUEST, data=None):
    return Envelope(status=status_code, message=message, data=data)
