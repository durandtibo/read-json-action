"""Check that the inputs and outputs of README.md match action.yaml (level 1, `make test`).

action.yaml is read with regular expressions because the standard library has no YAML parser.
It relies on the layout of action.yaml: two-space indented names under `inputs:` and `outputs:`,
and `default: "x"` lines.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def action_names(section):
    """Return the names declared under a top-level section (`inputs` or `outputs`)."""
    text = (ROOT / "action.yaml").read_text(encoding="utf-8")
    block = re.search(rf"^{section}:\n((?:(?:  .*)?\n)+)", text, re.MULTILINE).group(1)
    return re.findall(r"^  ([a-z][a-z-]*):$", block, re.MULTILINE)


def readme_names(first_header_cell):
    """Return the names in the first column of the README table whose header starts the row."""
    text = (ROOT / "README.md").read_text(encoding="utf-8")
    table = re.search(rf"^\| {first_header_cell} .*\n\|.*\n((?:\|.*\n)+)", text, re.MULTILINE)
    return re.findall(r"^\| `([^`]+)`", table.group(1), re.MULTILINE)


class ReadmeSyncTest(unittest.TestCase):
    def test_readme_inputs_match_action_inputs(self):
        self.assertEqual(readme_names("Input"), action_names("inputs"))

    def test_readme_outputs_match_action_outputs(self):
        self.assertEqual(readme_names("Output"), action_names("outputs"))

    def test_readme_default_of_fail_on_error_matches_action(self):
        action = (ROOT / "action.yaml").read_text(encoding="utf-8")
        default = re.search(r'^    default: "([^"]*)"$', action, re.MULTILINE).group(1)
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        row = re.search(r"^\| `fail-on-error` \|[^|]*\| ([^|]*) \|", readme, re.MULTILINE).group(1)
        self.assertEqual(row.strip(), f"`{default}`")


if __name__ == "__main__":
    unittest.main()
