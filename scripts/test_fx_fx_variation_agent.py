import unittest
from pathlib import Path
import tempfile
import json
import os

from fx_fx_variation_agent import _attempt_context, _retry_count, build_prompt


class FxVariationAgentTests(unittest.TestCase):
    def test_prompt_is_bounded_and_names_patch_contract(self) -> None:
        prompt = build_prompt(
            {
                "candidate_id": "c000007",
                "patch_path": "C:/run/c000007/patch.json",
                "case_spec": {
                    "case_id": "case-007",
                    "optimization_path": "glslc_performance_O",
                    "kind": "shader",
                    "hypothesis": "compile with performance optimization",
                },
                "optimization_catalog": ["glslc_performance_O", "pass_state_noop"],
            }
        )
        self.assertIn("write_file", prompt)
        self.assertIn("C:/run/c000007/patch.json", prompt)
        self.assertIn("glslc_performance_O", prompt)
        self.assertIn("optimization_path 必须逐字等于", prompt)
        self.assertIn("不要调用 list、read、terminal", prompt)

    def test_prompt_includes_compact_offline_guidance(self) -> None:
        prompt = build_prompt(
            {
                "candidate_id": "c000008",
                "patch_path": "C:/run/c000008/patch.json",
                "optimization_catalog": ["component_aliasing"],
                "baseline_guidance": {
                    "measurement_kind": "mali_offline_guidance",
                    "target_core": "Mali G1",
                    "aggregate": {"longest_path_cycle_sum": 5.0},
                    "shaders": [{"file": "sh15", "bound_pipelines": ["arith_total"]}],
                },
            }
        )
        self.assertIn("Mali Offline Compiler guidance", prompt)
        self.assertIn("longest_path_cycle_sum", prompt)
        self.assertIn("不是本机或 V100 的实际 GPU counter", prompt)

    def test_retry_context_is_isolated(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            context_path, patch_path = _attempt_context(
                {
                    "candidate_id": "c000004",
                    "candidate_dir": str(root / "candidate"),
                    "patch_path": str(root / "candidate" / "patch.json"),
                    "shader_dir": str(root / "candidate" / "shaders"),
                    "patch_contract": {"mode": "strict"},
                },
                root / "attempts" / "attempt-01",
            )
            value = json.loads(context_path.read_text(encoding="utf-8"))
            self.assertEqual(value["candidate_dir"], str(root / "attempts" / "attempt-01"))
            self.assertEqual(value["patch_path"], str(patch_path))
            self.assertEqual(patch_path.parent, context_path.parent)

    def test_retry_count_is_bounded(self) -> None:
        old = os.environ.get("FX_VARIATION_RETRY_COUNT")
        try:
            os.environ["FX_VARIATION_RETRY_COUNT"] = "1"
            self.assertEqual(_retry_count(), 1)
            os.environ["FX_VARIATION_RETRY_COUNT"] = "3"
            with self.assertRaises(ValueError):
                _retry_count()
        finally:
            if old is None:
                os.environ.pop("FX_VARIATION_RETRY_COUNT", None)
            else:
                os.environ["FX_VARIATION_RETRY_COUNT"] = old


if __name__ == "__main__":
    unittest.main()
