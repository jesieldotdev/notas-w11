"""Onde o notas-w11 guarda as coisas."""

import json
import os
import secrets as _rand
import tempfile

DATA = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "notas-w11")
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "notas-w11")


def _ensure(path):
    os.makedirs(path, exist_ok=True)
    return path


def state_file():
    """Estado completo do Keep (gkeepapi.dump): a cópia local de todas as notas."""
    return os.path.join(_ensure(DATA), "keep-state.json")


def feed_file():
    """Notas ativas num JSON simples, lido pelo widget do Plasma."""
    return os.path.join(_ensure(DATA), "notes.json")


def device_id():
    """Identificador fixo deste computador para o Google (16 dígitos hexadecimais)."""
    f = os.path.join(_ensure(CONFIG), "device-id")
    try:
        with open(f) as fh:
            value = fh.read().strip()
            if value:
                return value
    except OSError:
        pass
    value = _rand.token_hex(8)
    with open(f, "w") as fh:
        fh.write(value)
    return value


def write_json(path, data):
    """Grava de uma vez (arquivo temporário + rename): quem lê nunca vê metade."""
    _ensure(os.path.dirname(path))
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)
