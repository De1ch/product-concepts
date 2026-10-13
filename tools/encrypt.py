#!/usr/bin/env python3
"""Шифрует HTML-концепт в index.html с формой пароля.

Пароль берётся из переменной окружения CONCEPT_PASSWORD и нигде не сохраняется.
    CONCEPT_PASSWORD='...' python3 tools/encrypt.py path/to/concept.html index.html

Шифрование: PBKDF2-SHA256 (600 000 итераций) → AES-256-GCM, gzip перед шифрованием.
В репозиторий попадает только шифротекст; исходный HTML не коммитится.
"""
import base64, gzip, json, os, secrets, sys
from pathlib import Path
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ITER = 600_000

def main():
    if len(sys.argv) != 3:
        sys.exit('usage: CONCEPT_PASSWORD=... encrypt.py <concept.html> <index.html>')
    pw = os.environ.get('CONCEPT_PASSWORD', '')
    if len(pw) < 10:
        sys.exit('CONCEPT_PASSWORD не задан или короче 10 символов')
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    salt, iv = secrets.token_bytes(16), secrets.token_bytes(12)
    key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=ITER).derive(pw.encode())
    ct = AESGCM(key).encrypt(iv, gzip.compress(src.read_bytes(), 9), None)
    b64 = lambda b: base64.b64encode(b).decode()
    payload = json.dumps({'v': 1, 'iter': ITER, 'salt': b64(salt), 'iv': b64(iv), 'ct': b64(ct)})
    tpl = (Path(__file__).parent / 'template.html').read_text(encoding='utf-8')
    dst.write_text(tpl.replace('__PAYLOAD__', payload), encoding='utf-8')
    print(f'{dst}: {dst.stat().st_size // 1024} KB')

if __name__ == '__main__':
    main()
