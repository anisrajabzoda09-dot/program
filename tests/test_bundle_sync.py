# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import unittest

from fastapi.testclient import TestClient

from app.crud.crud_bundle import canonical_json, payload_checksum
from app.main import app


class BundleSyncTests(unittest.TestCase):
    def test_checksum_is_stable_for_key_order(self):
        left = {"b": 2, "a": {"текст": "Нигоҳ"}}
        right = {"a": {"текст": "Нигоҳ"}, "b": 2}
        self.assertEqual(canonical_json(left), canonical_json(right))
        self.assertEqual(payload_checksum(left), payload_checksum(right))

    def test_sync_returns_patch_then_304(self):
        with TestClient(app) as client:
            first = client.get(
                "/api/mobile/sync-bundle",
                params={"client_bundle_version": 0, "native_version_code": 24},
            )
            self.assertEqual(first.status_code, 200)
            data = first.json()
            self.assertTrue(data["has_update"])
            self.assertFalse(data["requires_full_reinstall"])
            self.assertGreaterEqual(len(data["patches"]), 1)

            patch = data["patches"][0]
            self.assertEqual(
                patch["checksum"], payload_checksum(patch["payload"])
            )

            unchanged = client.get(
                "/api/mobile/sync-bundle",
                params={
                    "client_bundle_version": data["bundle_version"],
                    "native_version_code": 24,
                },
            )
            self.assertEqual(unchanged.status_code, 304)


if __name__ == "__main__":
    unittest.main()
