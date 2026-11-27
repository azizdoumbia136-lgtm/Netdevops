#!/usr/bin/env python3
"""Verifie qu'une URL repond avec un code HTTP 200."""
import sys
import urllib.error
import urllib.request


def check(url: str, timeout: int = 5) -> bool:
    """Retourne True si l'URL repond 200."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return resp.status == 200
    except (urllib.error.URLError, OSError):
        return False


def main() -> int:
    """Point d'entree du script."""
    if len(sys.argv) != 2:
        print("Usage: healthcheck.py URL")
        return 2
    ok = check(sys.argv[1])
    print("OK" if ok else "KO", sys.argv[1])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
