"""Tests for scripts/coverage_gate.py."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import coverage_gate as cg

THRESHOLDS = Path(__file__).resolve().parents[2] / "quality" / "coverage-thresholds.json"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def cobertura(specs: list[tuple[str, int, int]], branch_rate: str = "0.5") -> str:
    """Build Cobertura XML from (filename, lines, hit lines)."""
    classes = []
    for name, total, hit in specs:
        lines = "".join(
            f'<line number="{i + 1}" hits="{1 if i < hit else 0}"/>' for i in range(total)
        )
        classes.append(
            f'<class name="{name}" filename="{name}" line-rate="{hit / total}" '
            f'branch-rate="{branch_rate}"><lines>{lines}</lines></class>'
        )
    return (
        '<?xml version="1.0" ?><coverage><packages><package name="p"><classes>'
        + "".join(classes)
        + "</classes></package></packages></coverage>"
    )


class GateTests(unittest.TestCase):
    """End-to-end through main() on generated and fixture XML."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def gate(self, xml: str) -> int:
        path = self.dir / "cov.xml"
        path.write_text(xml, encoding="utf-8")
        return cg.main(["--thresholds", str(THRESHOLDS), str(path)])

    def engine(self, scoring: int, risk: int, other: int) -> str:
        return cobertura(
            [
                ("meridian_engine/scoring/rules.py", 100, scoring),
                ("meridian_engine/risk/limits.py", 100, risk),
                ("meridian_engine/data/util.py", 100, other),
            ]
        )

    def test_above_floors_pass(self) -> None:
        self.assertEqual(self.gate(self.engine(95, 95, 90)), 0)

    def test_floor_is_inclusive_and_one_under_fails(self) -> None:
        self.assertEqual(self.gate(self.engine(90, 90, 90)), 0)
        self.assertEqual(self.gate(self.engine(89, 95, 100)), 1)
        self.assertEqual(self.gate(self.engine(95, 89, 100)), 1)

    def test_overall_engine_floor(self) -> None:
        self.assertEqual(self.gate(self.engine(95, 95, 60)), 1)
        self.assertEqual(self.gate(self.engine(95, 90, 70)), 0)

    def test_branch_rate_does_not_rescue_lines(self) -> None:
        xml = cobertura([("meridian_engine/scoring/rules.py", 100, 85)], branch_rate="1.0")
        self.assertEqual(self.gate(xml), 1)

    def test_other_components(self) -> None:
        drupal = "web/modules/custom/meridian_ingest/src/Ingest.php"
        self.assertEqual(self.gate(cobertura([(drupal, 100, 69)])), 1)
        self.assertEqual(self.gate(cobertura([(drupal, 100, 70)])), 0)
        self.assertEqual(self.gate(cobertura([("apps/web/lib/format.ts", 100, 79)])), 1)
        self.assertEqual(self.gate(cobertura([("apps/web/components/T.tsx", 100, 80)])), 0)

    def test_routes_have_no_floor(self) -> None:
        xml = cobertura([("apps/web/lib/f.ts", 100, 90), ("apps/web/app/page.tsx", 100, 10)])
        self.assertEqual(self.gate(xml), 0)

    def test_failure_names_the_file(self) -> None:
        failures = cg.evaluate(
            cg.load_coverage([self._write(self.engine(80, 95, 100))]),
            cg.load_thresholds(str(THRESHOLDS)),
        )
        self.assertTrue(any("scoring/rules.py" in f for f in failures))

    def test_bad_inputs_fail_without_traceback(self) -> None:
        self.assertEqual(self.gate("<coverage><packages>"), 1)
        self.assertEqual(self.gate("<coverage><packages/></coverage>"), 1)
        missing = str(self.dir / "nope.xml")
        self.assertEqual(cg.main(["--thresholds", str(THRESHOLDS), missing]), 1)

    def test_unmatched_report_fails(self) -> None:
        self.assertEqual(self.gate(cobertura([("other/file.py", 10, 10)])), 1)

    def test_required_prefix_must_match(self) -> None:
        path = self.dir / "r.xml"
        path.write_text(self.engine(95, 95, 95), encoding="utf-8")
        base = ["--thresholds", str(THRESHOLDS), str(path)]
        self.assertEqual(cg.main(["--require", "meridian_engine/", *base]), 0)
        self.assertEqual(cg.main(["--require", "apps/web/lib/", *base]), 1)

    def test_phpunit_filenames_are_relative_to_the_source(self) -> None:
        """T09: PHPUnit names files relative to its <source>, which holds the module path."""
        source = "/var/www/html/apps/drupal/web/modules/custom/meridian_core/src"

        def report(hit: int) -> str:
            lines = "".join(
                f'<line number="{i + 1}" hits="{1 if i < hit else 0}"/>' for i in range(100)
            )
            return (
                f"<coverage><sources><source>{source}</source></sources><packages>"
                '<package name="Hook/A.php"><classes><class name="A" filename="Hook/A.php">'
                f"<lines>{lines}</lines></class></classes></package></packages></coverage>"
            )

        path = self.dir / "php.xml"
        for hit, expected in ((70, 0), (69, 1)):
            path.write_text(report(hit), encoding="utf-8")
            args = ["--thresholds", str(THRESHOLDS), "--require", "web/modules/custom/meridian_"]
            self.assertEqual(cg.main([*args, str(path)]), expected, hit)

    def test_floor_is_always_a_percentage(self) -> None:
        thr = self.dir / "t.json"
        thr.write_text('{"components": [{"path": "a/", "line": 1}]}', encoding="utf-8")
        self.assertEqual(cg.load_thresholds(str(thr)), [("a/", 0.01)])

    def test_fixture_file(self) -> None:
        argv = ["--thresholds", str(THRESHOLDS), str(FIXTURES / "cobertura_ok.xml")]
        self.assertEqual(cg.main(argv), 0)
        argv = ["--thresholds", str(THRESHOLDS), str(FIXTURES / "cobertura_drop.xml")]
        self.assertEqual(cg.main(argv), 1)

    def _write(self, xml: str) -> str:
        path = self.dir / "w.xml"
        path.write_text(xml, encoding="utf-8")
        return str(path)


class HelperTests(unittest.TestCase):
    """Small pure functions."""

    def test_matches_on_segment_boundary(self) -> None:
        self.assertTrue(cg.matches("meridian_engine/scoring/a.py", "meridian_engine/scoring/"))
        self.assertTrue(cg.matches("services/engine/meridian_engine/x.py", "meridian_engine/"))
        self.assertFalse(cg.matches("xmeridian_engine/x.py", "meridian_engine/"))

    def test_rate(self) -> None:
        self.assertEqual(cg.rate({1: 1, 2: 0}), 0.5)
        self.assertEqual(cg.rate({}), 1.0)


if __name__ == "__main__":
    unittest.main()
