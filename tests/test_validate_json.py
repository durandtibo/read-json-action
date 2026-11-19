"""Unit tests (level 1) of scripts/validate-json.py: the strict RFC 8259 syntax check.

They run the script as the action does (a subprocess with the file path as argument) and need
only the Python standard library: `make test`.
"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "validate-json.py"


class ValidateJsonTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)

    def run_script(self, content, name="file.json"):
        path = self.tmp / name
        path.write_bytes(content if isinstance(content, bytes) else content.encode("utf-8"))
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(path)], capture_output=True, text=True, check=False
        )

    def assert_valid(self, content):
        result = self.run_script(content)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout, "")

    def assert_invalid(self, content, error=None):
        result = self.run_script(content)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(result.stdout.splitlines()), 1)
        if error is not None:
            self.assertTrue(result.stdout.startswith(error), result.stdout)
        return result.stdout

    def test_valid_documents(self):
        for content in [
            '{"a": 1}',
            "[]",
            "{}",
            '"text"',
            "42",
            "-1.5e10",
            "true",
            "null",
            '  {"a": [1, 2, {"b": null}]}\n\n',
            '{"unicode": "é€😀", "escaped": "\\u00e9\\n"}',
            '{"big": 123456789012345678901234567890}',
            '{"a": 1}\r\n',
            "[" * 100 + "]" * 100,
        ]:
            with self.subTest(content=content[:30]):
                self.assert_valid(content)

    def test_empty_and_whitespace_only_are_invalid(self):
        for content in ["", " ", "\n\n", "\t"]:
            with self.subTest(content=content):
                self.assert_invalid(content, "JSONDecodeError")

    def test_syntax_errors_are_invalid(self):
        for content in [
            "{invalid",
            '{"a": 1,}',
            "[1, 2,]",
            "{'a': 1}",
            '{"a": 1} extra',
            '{"a": 1}{"b": 2}',
            '{"a": 1',
            '{"a": 01}',
            '{"a": .5}',
            '{"a": "line\nbreak"}',
            "// comment\n{}",
        ]:
            with self.subTest(content=content):
                self.assert_invalid(content, "JSONDecodeError")

    def test_non_standard_constants_are_invalid(self):
        for content in ["NaN", "Infinity", "-Infinity", '{"a": NaN}', "[Infinity]"]:
            with self.subTest(content=content):
                self.assert_invalid(content, "ValueError: invalid constant")

    def test_byte_order_mark_is_invalid(self):
        self.assert_invalid(b'\xef\xbb\xbf{"a": 1}', "JSONDecodeError")

    def test_non_utf8_is_invalid(self):
        self.assert_invalid(b'{"a": "caf\xe9"}', "UnicodeDecodeError")

    def test_missing_file_is_invalid(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.tmp / "missing.json")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertTrue(result.stdout.startswith("FileNotFoundError"), result.stdout)

    def test_directory_is_invalid(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.tmp)], capture_output=True, text=True, check=False
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(result.stdout.splitlines()), 1)

    def test_message_never_contains_the_file_content(self):
        secret = "S3CR3T-TOKEN-VALUE"
        for content in [
            '{"token": "%s",}' % secret,
            "::error::%s" % secret,
            '{"token": "%s"} trailing' % secret,
            "{'token': '%s'}" % secret,
        ]:
            with self.subTest(content=content):
                self.assertNotIn(secret, self.assert_invalid(content))


if __name__ == "__main__":
    unittest.main()
