"""Desfoque do KWin atrás das janelas (o vidro dos painéis do Plasma).

O PySide6 não tem o KWindowEffects (KF6 WindowSystem), então chamamos a
função C++ direto da biblioteca, passando os ponteiros C++ da janela e da
região. A região acompanha os cantos arredondados da janela.
Sem a biblioteca (ou fora do KDE), simplesmente não desfoca.
"""

import ctypes

try:
    import shiboken6
    from PySide6.QtCore import QRectF
    from PySide6.QtGui import QPainterPath, QRegion

    _lib = ctypes.CDLL("libKF6WindowSystem.so.6")
    _blur = _lib["_ZN14KWindowEffects16enableBlurBehindEP7QWindowbRK7QRegion"]
    _blur.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_void_p]
    _blur.restype = None
    AVAILABLE = True
except Exception:
    AVAILABLE = False


def _ptr(obj):
    return shiboken6.getCppPointer(obj)[0]


def rounded_region(width, height, radius):
    path = QPainterPath()
    path.addRoundedRect(QRectF(0, 0, width, height), radius, radius)
    return QRegion(path.toFillPolygon().toPolygon())


def blur_behind(window, radius=8.0, enabled=True):
    """Liga (ou desliga) o desfoque atrás de toda a janela, com os cantos arredondados."""
    if not AVAILABLE or window is None:
        return
    region = rounded_region(window.width(), window.height(), radius)
    _blur(_ptr(window), enabled, _ptr(region))
