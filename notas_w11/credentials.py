"""O token do Keep fica no cofre de senhas do KDE (KWallet, via Secret Service).

Sem cofre disponível, cai num arquivo legível só pelo usuário (0600).
"""

import json
import os

from . import paths

SERVICE = "notas-w11"
KEY = "google-keep"


def _keyring():
    try:
        import keyring
        keyring.get_keyring()
        return keyring
    except Exception:
        return None


def _fallback():
    return os.path.join(paths.CONFIG, "credentials.json")


def save(email, token):
    data = json.dumps({"email": email, "token": token})
    kr = _keyring()
    if kr:
        try:
            kr.set_password(SERVICE, KEY, data)
            return
        except Exception:
            pass
    os.makedirs(paths.CONFIG, exist_ok=True)
    fd = os.open(_fallback(), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(data)


def load():
    kr = _keyring()
    if kr:
        try:
            data = kr.get_password(SERVICE, KEY)
            if data:
                return json.loads(data)
        except Exception:
            pass
    try:
        with open(_fallback()) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def clear():
    kr = _keyring()
    if kr:
        try:
            kr.delete_password(SERVICE, KEY)
        except Exception:
            pass
    try:
        os.remove(_fallback())
    except OSError:
        pass
