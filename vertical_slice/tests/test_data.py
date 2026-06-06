import importlib.util
import unittest
from pathlib import Path


VALIDATOR_PATH = Path(__file__).resolve().parents[1] / "tools" / "validate_data.py"
SPEC = importlib.util.spec_from_file_location("validate_data", VALIDATOR_PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(VALIDATOR)


class VerticalSliceDataTest(unittest.TestCase):
    def test_data_contracts(self):
        messages = VALIDATOR.validate()
        self.assertGreaterEqual(len(messages), 3)


if __name__ == "__main__":
    unittest.main()

