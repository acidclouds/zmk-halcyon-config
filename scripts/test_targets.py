"""Run: uv run --with pyyaml,pytest pytest scripts/test_targets.py -q"""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def run(yaml_text: str) -> str:
    return subprocess.run(
        [sys.executable, str(REPO / "scripts" / "targets.py"), "/dev/stdin"],
        input=yaml_text, capture_output=True, text=True, check=True,
    ).stdout


def test_prints_one_tab_separated_line_per_target():
    out = run(
        "include:\n"
        "  - board: b//z\n"
        "    shield: s1 s2\n"
        "    cmake-args: -DX=y\n"
        "    snippet: snip\n"
        "    artifact-name: left\n"
        "  - board: b//z\n"
        "    shield: s3\n"
        "    artifact-name: right\n"
    )
    assert out.splitlines() == [
        "left\tb//z\ts1 s2\tsnip\t-DX=y",
        "right\tb//z\ts3\t\t",
    ]


def test_repo_build_yaml_has_left_and_right():
    out = subprocess.run(
        [sys.executable, str(REPO / "scripts" / "targets.py"), str(REPO / "build.yaml")],
        capture_output=True, text=True, check=True,
    ).stdout
    names = [line.split("\t")[0] for line in out.splitlines()]
    assert names == ["elora_left", "elora_right", "settings_reset"]


def test_target_without_shield_falls_back_to_the_board_name():
    out = run(
        "include:\n"
        "  - board: b//z\n"
    )
    assert out.splitlines() == ["b__z\tb//z\t\t\t"]


def test_no_argument_prints_usage_and_exits_with_2():
    p = subprocess.run(
        [sys.executable, str(REPO / "scripts" / "targets.py")],
        capture_output=True, text=True,
    )
    assert p.returncode == 2
    assert p.stderr.strip() == "usage: targets.py build.yaml"
    assert p.stdout == ""
