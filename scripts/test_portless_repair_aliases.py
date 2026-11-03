import unittest
import importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location("portless_alias_repair", Path(__file__).with_name("portless-repair-aliases.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
repair = module.repair


class AliasRepairTests(unittest.TestCase):
    def test_live_and_replaced_targets_survive(self):
        calls = []
        snapshots = iter([{'trr': 4000, 'api.trr': 4001}, {'trr': 4000, 'api.trr': 4002}])
        self.assertEqual(repair(read=lambda: next(snapshots), active=lambda port: port == 4000,
                                run=lambda *args, **kwargs: calls.append(args)), [])
        self.assertEqual(calls, [])

    def test_only_unchanged_dead_alias_is_removed(self):
        calls = []
        self.assertEqual(repair(read=lambda: {'admin.trr': 4002}, active=lambda port: False,
                                run=lambda args, **kwargs: calls.append(args)), ['admin.trr'])
        self.assertEqual(calls, [['portless', 'alias', '--remove', 'admin.trr']])


if __name__ == '__main__':
    unittest.main()
