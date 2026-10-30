"""Functional tests for the mizu-l2d model cache (M1 fetch manifest + M2 ledger).

No network: downloads are never exercised, only the pure logic (manifest
enumeration, path safety) and the ledger/quota/eviction policy against
temporary fixture directories.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPTS = Path("/home/thuanc177/Projects/Tools/mizu-l2d/scripts")
CACHE_TOOL = SCRIPTS / "mizu-l2d-cache.py"


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_cache(args, l2d_dir, config):
    return subprocess.run(
        [sys.executable, "-I", "-B", str(CACHE_TOOL),
         "--l2d-dir", str(l2d_dir), "--config", str(config)] + args,
        capture_output=True, text=True)


def make_prefab(l2d_dir, name, size_kb, mtime=None):
    d = l2d_dir / name
    (d / "motions").mkdir(parents=True)
    (d / f"{name}.model3.json").write_text("{}", encoding="utf-8")
    (d / "motions" / "a.motion3.json").write_bytes(os.urandom(size_kb * 1024))
    if mtime is not None:
        os.utime(d, (mtime, mtime))
    return d


class LedgerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.l2d = Path(self.tmp.name) / "l2d"
        self.l2d.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def test_touch_and_persist(self):
        led = load_module(SCRIPTS / "l2d_ledger.py", "l2d_ledger")
        led.touch(self.l2d, "gaoxiong_7", when=1000)
        led.set_bytes(self.l2d, "gaoxiong_7", 12345)
        led.set_pinned(self.l2d, "gaoxiong_7", True)
        data = led.load(self.l2d)
        entry = data["prefabs"]["gaoxiong_7"]
        self.assertEqual(entry["last_used"], 1000)
        self.assertEqual(entry["bytes"], 12345)
        self.assertTrue(entry["pinned"])
        self.assertTrue((self.l2d / ".ledger.json").is_file())

    def test_load_tolerates_missing_and_corrupt(self):
        led = load_module(SCRIPTS / "l2d_ledger.py", "l2d_ledger")
        self.assertEqual(led.load(self.l2d)["prefabs"], {})
        (self.l2d / ".ledger.json").write_text("not json{", encoding="utf-8")
        self.assertEqual(led.load(self.l2d)["prefabs"], {})

    def test_quota_default(self):
        led = load_module(SCRIPTS / "l2d_ledger.py", "l2d_ledger")
        self.assertEqual(led.quota_bytes({"quota_bytes": 0}), 2 * 1024 * 1024 * 1024)
        self.assertEqual(led.quota_bytes({"quota_bytes": 5}), 5)


class FetchManifestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fm = load_module(SCRIPTS / "fetch-model.py", "fetch_model")

    def _fixture(self, tmp, unsafe=False):
        rel = "../evil.moc3" if unsafe else "model.moc3"
        model3 = {
            "FileReferences": {
                "Moc": rel,
                "Textures": ["tex/atlas.png"],
                "Motions": {"idle": [{"File": "motions/idle.motion3.json",
                                      "Sound": "sounds/ignored.wav"}]},
                "Physics": "physics.json",
            }
        }
        p = Path(tmp) / "x.model3.json"
        p.write_text(json.dumps(model3), encoding="utf-8")
        return p

    def test_enumerates_referenced_files_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            rels = self.fm.model_files(self._fixture(tmp))
            self.assertEqual(rels, ["model.moc3", "tex/atlas.png",
                                    "motions/idle.motion3.json", "physics.json"])

    def test_refuses_unsafe_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(SystemExit):
                self.fm.model_files(self._fixture(tmp, unsafe=True))


class CachePolicyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.l2d = self.base / "l2d"
        self.l2d.mkdir()
        self.config = self.base / "config.toml"
        self.config.write_text('schema = 1\n\n[wall]\nmodel = "c"\n', encoding="utf-8")
        now = time.time()
        # a = oldest, b = pinned, c = active, d = newest
        make_prefab(self.l2d, "a", 60, mtime=now - 4000)
        make_prefab(self.l2d, "b", 60, mtime=now - 3000)
        make_prefab(self.l2d, "c", 60, mtime=now - 2000)
        make_prefab(self.l2d, "d", 60, mtime=now - 1000)
        # seed the ledger: pin b, leave last_used to mtime seeding
        subprocess.run([sys.executable, "-I", "-B", str(CACHE_TOOL),
                        "--l2d-dir", str(self.l2d), "--config", str(self.config),
                        "pin", "b"], capture_output=True, text=True, check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_status_reports_total_and_flags(self):
        r = run_cache(["status"], self.l2d, self.config)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("4 models, 1 pinned", r.stdout)
        self.assertIn("ACTIVE", r.stdout)
        self.assertIn("pinned", r.stdout)

    def test_evict_refuses_active_and_pinned(self):
        r = run_cache(["evict", "c"], self.l2d, self.config)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("active model", r.stdout)
        self.assertTrue((self.l2d / "c").is_dir())
        r = run_cache(["evict", "b"], self.l2d, self.config)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("pinned", r.stdout)
        self.assertTrue((self.l2d / "b").is_dir())

    def test_evict_removes_unpinned_model(self):
        r = run_cache(["evict", "a"], self.l2d, self.config)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse((self.l2d / "a").exists())
        ledger = json.loads((self.l2d / ".ledger.json").read_text())
        self.assertNotIn("a", ledger["prefabs"])

    def test_enforce_evicts_oldest_first_and_keeps_guards(self):
        # 4 × ~60KB; quota ~157KB forces two evictions: a (oldest) then d.
        # b is pinned and c is active, so both must survive.
        r = run_cache(["enforce", "--quota", "0.00015"], self.l2d, self.config)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.l2d / "b").is_dir())
        self.assertTrue((self.l2d / "c").is_dir())
        self.assertFalse((self.l2d / "a").exists())
        self.assertFalse((self.l2d / "d").exists())
        ledger = json.loads((self.l2d / ".ledger.json").read_text())
        self.assertNotIn("a", ledger["prefabs"])
        self.assertLessEqual(
            sum(e.get("bytes", 0) for e in ledger["prefabs"].values()),
            int(0.00015 * 1024 ** 3) + 1024)

    def test_enforce_dry_run_keeps_everything(self):
        r = run_cache(["enforce", "--quota", "0.00015", "--dry-run"], self.l2d, self.config)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("would evict", r.stdout)
        for name in ("a", "b", "c", "d"):
            self.assertTrue((self.l2d / name).is_dir())

    def test_verify_flags_missing_manifest(self):
        r = run_cache(["verify"], self.l2d, self.config)
        self.assertEqual(r.returncode, 2)
        self.assertIn("no manifest", r.stdout)


if __name__ == "__main__":
    unittest.main()
