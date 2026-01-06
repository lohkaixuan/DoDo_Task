# ==================================================
# Program Name   : hash.py
# Purpose        : Utility script for generating and testing bcrypt password
#                  hashes used during development and security validation.
# Developer      : Miss. Yap Shuet Khey
# Student ID     : TP074066
# Course         : Bachelor of Software Engineering (Hons)
# Created Date   : 25 August 2025
# Last Modified  : 25 August 2025
# ==================================================

from passlib.context import CryptContext

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

plain = "12345678"
hashed = pwd.hash(plain)
print(hashed)