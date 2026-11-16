"""Exit 0 if the file is strict RFC 8259 JSON in UTF-8. Otherwise print one line and exit 1.

The message never contains the file content. Usage: validate-json.py FILE
"""

import json
import sys


def reject(constant):
    raise ValueError("invalid constant " + constant)


try:
    with open(sys.argv[1], encoding="utf-8") as f:
        json.load(f, parse_constant=reject)
except (ValueError, OSError, RecursionError) as e:  # JSONDecodeError and UnicodeDecodeError are ValueErrors
    print(type(e).__name__ + ": " + str(e))
    sys.exit(1)
