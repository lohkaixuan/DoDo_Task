# make_hash.py
from passlib.context import CryptContext

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

plain = "12345678"
hashed = pwd.hash(plain)
print(hashed)