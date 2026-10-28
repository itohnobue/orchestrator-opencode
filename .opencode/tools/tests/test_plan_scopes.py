# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest", "wcmatch", "pathspec"]
# ///
"""Acceptance tests for `.opencode/tools/plan_scopes.py`.

Every fixture repo is created at test time under `tmp_path`; no binary or text
fixture is committed. All assertions check exact numbers, not just exit codes.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

TOOL = Path(__file__).resolve().parents[1] / "plan_scopes.py"

BEGIN = "<!-- plan-scopes:begin -->"
END = "<!-- plan-scopes:end -->"


# --------------------------------------------------------------------------
# Fixture helpers
# --------------------------------------------------------------------------


class Repo:
    def __init__(self, base: Path):
        self.root = base
        (base / "tmp").mkdir(parents=True, exist_ok=True)
        self.plan_file = base / "tmp" / "glm-plan.md"

    def file(self, rel: str, lines: int = 1, newline: str = "\n", trailing: bool = True) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        data = ("x" + newline) * lines
        if lines and not trailing:
            data = data[: -len(newline)]
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write(data)
        return path

    def many(self, prefix: str, count: int, lines: int = 100) -> list:
        paths = []
        for index in range(count):
            rel = "%s/f%02d.py" % (prefix, index)
            if lines:
                self.file(rel, lines)
            else:  # an empty file still counts as one file with 0 LOC
                self.file(rel, 0)
            paths.append(rel)
        return paths

    def write_plan(self, *sections: str, declared: str = "small") -> Path:
        body = "\n\n".join(sections)
        text = (
            "# Plan\n\nSize: %s (size=%s)\n\n```toml plan-scopes\n%s\n```\n"
            % (declared, declared, body)
        )
        with open(self.plan_file, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
        return self.plan_file

    def run(self, command: str, *extra: str):
        return subprocess.run(
            [sys.executable, str(TOOL), command, "--plan", str(self.plan_file), "--root", str(self.root), *extra],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

    def text(self) -> str:
        with open(self.plan_file, "r", encoding="utf-8", newline="") as handle:
            return handle.read()

    def section(self) -> str:
        text = self.text()
        assert BEGIN in text, "no generated section:\n" + text
        start = text.index(BEGIN)
        stop = text.index(END) + len(END)
        return text[start:stop]

    def rows(self) -> dict:
        """Scope-table rows without the `reads LOC` column (audited columns only)."""
        out = {}
        for line in self.section().split("\n"):
            if not line.startswith("| ") or line.startswith("| id ") or set(line) <= {"|", "-"}:
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) == 7:
                cells = cells[:5] + cells[6:]
            out[cells[0]] = cells
        return out

    def reads_column(self, scope_id: str) -> int:
        for line in self.section().split("\n"):
            if not line.startswith("| ") or line.startswith("| id ") or set(line) <= {"|", "-"}:
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) == 7 and cells[0] == scope_id:
                return int(cells[5])
        raise AssertionError("no scope-table row for %s" % scope_id)

    def reads_bullets(self, scope_id: str) -> list:
        lines = self.section().split("\n")
        try:
            start = lines.index("#### %s" % scope_id)
        except ValueError:
            raise AssertionError("no Files block for %s" % scope_id)
        out = []
        in_reads = False
        for line in lines[start + 1 :]:
            if line.startswith("#### ") or line.startswith("## "):
                break
            if line == "reads (not audited):":
                in_reads = True
                continue
            if in_reads and line.startswith("- "):
                out.append(line)
        return out

    def files_section(self) -> list:
        lines = self.section().split("\n")
        start = lines.index("### Files")
        stop = lines.index("## Packing")
        return [line for line in lines[start:stop] if line.startswith("- ")]

    def packing_line(self, stage: str) -> str:
        prefix = "Stage packing %s: " % stage
        for line in self.section().split("\n"):
            if line.startswith(prefix):
                return line[len(prefix) :]
        raise AssertionError("no packing line for stage %s" % stage)

    def warnings_block(self) -> list:
        lines = self.section().split("\n")
        start = lines.index("## Warnings") + 2
        out = []
        for line in lines[start:]:
            if line == END:
                break
            out.append(line)
        return out


def q(value: str) -> str:
    return json.dumps(value)


def scope(
    sid: str,
    files=(),
    spans=(),
    stage: str = "s2",
    agent=None,
    role: str = "primary",
    exclude=(),
    cohesive=None,
    category="module-complete",
    splits=(),
    reads=(),
    klass=None,
) -> str:
    out = ["[[scope]]", "id = %s" % q(sid), "stage = %s" % q(stage), "agent = %s" % q(agent or "agent-" + sid), "role = %s" % q(role)]
    out.append("files = [%s]" % ", ".join(q(f) for f in files))
    if spans:
        out.append("spans = [%s]" % ", ".join(q(s) for s in spans))
    if reads:
        out.append("reads = [%s]" % ", ".join(q(r) for r in reads))
    if exclude:
        out.append("exclude = [%s]" % ", ".join(q(e) for e in exclude))
    if cohesive is not None:
        out.append("cohesive = %s" % ("true" if cohesive else "false"))
    if category:
        out.append("category = %s" % q(category))
    if klass:
        out.append("class = %s" % q(klass))
    for part in splits:
        out.append("")
        out.append("[[scope.split]]")
        out.append("id = %s" % q(part["id"]))
        out.append("files = [%s]" % ", ".join(q(f) for f in part.get("files", [])))
        if part.get("spans"):
            out.append("spans = [%s]" % ", ".join(q(s) for s in part["spans"]))
        if part.get("reads"):
            out.append("reads = [%s]" % ", ".join(q(r) for r in part["reads"]))
        if part.get("class"):
            out.append("class = %s" % q(part["class"]))
        if part.get("agent"):
            out.append("agent = %s" % q(part["agent"]))
    return "\n".join(out)


def stage(sid: str, kind: str = "discover", intersections=(), second_opinions=()) -> str:
    out = ["[stage.%s]" % sid, "kind = %s" % q(kind)]
    if intersections:
        out.append("intersections = [%s]" % ", ".join(q(i) for i in intersections))
    if second_opinions:
        out.append("second_opinions = [%s]" % ", ".join(q(i) for i in second_opinions))
    return "\n".join(out)


def single(repo: Repo, files, **kwargs):
    """Write a plan with one scope named 'core'."""
    sid = kwargs.pop("sid", "core")
    repo.write_plan(scope(sid, files=files, **kwargs))
    return repo.run("resolve")


# --------------------------------------------------------------------------
# File-count boundaries: 15 / 16 / 20 / 21
# --------------------------------------------------------------------------


def test_fifteen_files_no_split(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 15, 100)
    result = single(repo, ["src/core/*.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "15", "1500", "no split"]
    assert repo.packing_line("s2") == (
        "primaries=1 + intersection=0 + second opinions=0 \u2192 read-heavy agents=1, "
        "in-scope LOC=1500, capacity=1 \u00d7 5,000, utilisation=30.0%"
    )
    assert len(repo.files_section()) == 15
    assert len(files) == 15


def test_sixteen_files_requires_a_cut(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 16, 100)
    result = single(repo, ["src/core/*.py"], cohesive=False)
    assert result.returncode == 2
    assert (
        "scope core must split (files=16 in 16-20 band (cohesive=false, max file LOC=100)); "
        "supply [[scope.split]] blocks (see propose)" in result.stderr
    )
    assert BEGIN not in repo.text()


def test_sixteen_files_with_a_valid_cut_splits(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    result = single(
        repo,
        ["src/core/*.py"],
        cohesive=False,
        splits=[
            {"id": "core-a", "files": files[:8]},
            {"id": "core-b", "files": files[8:]},
        ],
    )
    assert result.returncode == 0, result.stderr
    rows = repo.rows()
    assert rows["core-a"] == ["core-a", "s2", "agent-core-core-a", "8", "800", "no split"]
    assert rows["core-b"] == ["core-b", "s2", "agent-core-core-b", "8", "800", "no split"]
    assert "core" not in rows
    assert repo.packing_line("s2") == (
        "primaries=2 + intersection=0 + second opinions=0 \u2192 read-heavy agents=2, "
        "in-scope LOC=1600, capacity=2 \u00d7 5,000, utilisation=16.0%"
    )


def test_twenty_files_cohesive_accepts(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 20, 100)
    result = single(repo, ["src/core/*.py"], cohesive=True)
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "20", "2000", "no split"]


def test_twenty_files_not_cohesive_must_split(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 20, 100)
    result = single(repo, ["src/core/*.py"], cohesive=False)
    assert result.returncode == 2
    assert "files=20 in 16-20 band" in result.stderr


def test_twenty_files_cohesive_but_a_file_over_300_must_split(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 19, 100)
    repo.file("src/core/big.py", 301)
    result = single(repo, ["src/core/*.py"], cohesive=True)
    assert result.returncode == 2
    assert "cohesive=true, max file LOC=301" in result.stderr
    assert len(files) == 19


def test_twenty_files_cohesive_at_exactly_300_accepted(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 19, 100)
    repo.file("src/core/big.py", 300)
    result = single(repo, ["src/core/*.py"], cohesive=True)
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "20", "2200", "no split"]


def test_twenty_one_files_must_split(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 21, 200)  # 4,200 LOC — above the thin-stub floor
    result = single(repo, ["src/core/*.py"])
    assert result.returncode == 2
    assert "scope core must split (files=21 > 20)" in result.stderr


# --------------------------------------------------------------------------
# LOC boundaries: 4,999 / 5,000 / 5,001
# --------------------------------------------------------------------------


def test_loc_4999_no_split(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 2500)
    repo.file("src/b.py", 2499)
    result = single(repo, ["src/*.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "2", "4999", "no split"]


def test_loc_5000_no_split(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 2500)
    repo.file("src/b.py", 2500)
    result = single(repo, ["src/*.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "2", "5000", "no split"]


def test_loc_5001_must_split(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 2500)
    repo.file("src/b.py", 2501)
    result = single(repo, ["src/*.py"])
    assert result.returncode == 2
    assert "scope core must split (LOC=5001 > 5000)" in result.stderr


# --------------------------------------------------------------------------
# Merge-back floor: 2,999 / 3,000
# --------------------------------------------------------------------------


def test_merge_back_at_2999(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 1499)
    repo.file("src/b.py", 1500)
    result = single(
        repo,
        ["src/*.py"],
        splits=[{"id": "core-a", "files": ["src/a.py"]}, {"id": "core-b", "files": ["src/b.py"]}],
    )
    assert result.returncode == 0, result.stderr
    assert "merge-back: core (2 parts -> parent)" in repo.warnings_block()
    assert repo.rows() == {"core": ["core", "s2", "agent-core", "2", "2999", "no split"]}


def test_no_merge_back_at_3000(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/big.py", 3000)
    result = single(repo, ["src/big.py"], splits=[{"id": "core-a", "files": ["src/big.py"]}])
    assert result.returncode == 0, result.stderr
    assert not any("merge-back" in line for line in repo.warnings_block())
    rows = repo.rows()
    assert rows == {"core-a": ["core-a", "s2", "agent-core-core-a", "1", "3000", "no split"]}


def test_two_part_cut_over_the_file_cap_is_kept(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    result = single(
        repo,
        ["src/core/*.py"],
        cohesive=False,
        splits=[{"id": "core-a", "files": files[:9]}, {"id": "core-b", "files": files[9:]}],
    )
    assert result.returncode == 0, result.stderr
    assert not any("merge-back" in line for line in repo.warnings_block())
    assert set(repo.rows()) == {"core-a", "core-b"}


# --------------------------------------------------------------------------
# Thin stub and single-file escape
# --------------------------------------------------------------------------


def test_thin_stub_over_twenty_files_under_3000(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 21, 100)  # 2,100 LOC over 21 files
    result = single(repo, ["src/core/*.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "21", "2100", "thin stub"]
    assert "thin-stub: 21 files, 2100 LOC" in repo.warnings_block()


def test_thin_stub_boundary_at_3000_splits_required(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 21, 143)  # 3,003 LOC — no longer a thin stub
    result = single(repo, ["src/core/*.py"])
    assert result.returncode == 2
    assert "files=21 > 20" in result.stderr


def test_single_file_over_5000_escapes(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/big.py", 6000)
    result = single(repo, ["src/big.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "6000", "single-file escape"]
    assert "single-file escape: src/big.py 6000 LOC" in repo.warnings_block()


def test_single_file_over_5000_with_span_does_not_escape(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/big.py", 6000)
    result = single(repo, ["src/big.py"], spans=["src/big.py:1-10"])
    assert result.returncode == 2
    assert "must split" in result.stderr


# --------------------------------------------------------------------------
# Split validation
# --------------------------------------------------------------------------


def test_split_with_a_lost_file_exits_2(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    result = single(
        repo,
        ["src/core/*.py"],
        cohesive=False,
        splits=[{"id": "core-a", "files": files[:7]}, {"id": "core-b", "files": files[7:15]}],
    )
    assert result.returncode == 2
    assert "lost file(s): src/core/f15.py" in result.stderr


def test_split_with_a_duplicated_file_exits_2(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    result = single(
        repo,
        ["src/core/*.py"],
        cohesive=False,
        splits=[
            {"id": "core-a", "files": files[:9]},
            {"id": "core-b", "files": files[8:]},
        ],
    )
    assert result.returncode == 2
    assert "file(s) in two parts: src/core/f08.py" in result.stderr


def test_split_part_over_the_caps_exits_2(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 400)  # 6,400 LOC total
    result = single(
        repo,
        ["src/core/*.py"],
        cohesive=False,
        splits=[
            {"id": "core-a", "files": files[:14]},  # 5,600 LOC — still over
            {"id": "core-b", "files": files[14:]},
        ],
    )
    assert result.returncode == 2
    assert "split part core-a of scope core still must split (LOC=5600 > 5000)" in result.stderr


# --------------------------------------------------------------------------
# Spans
# --------------------------------------------------------------------------


def test_span_counts_end_minus_start_plus_one(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/models.py", 1000)
    result = single(repo, ["src/models.py"], spans=["src/models.py:100-199"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "1100", "no split"]
    assert repo.files_section() == [
        "- src/models.py \u2014 1000 LOC",
        "- src/models.py:100-199 \u2014 100 LOC (span)",
    ]


def test_span_beyond_the_file_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/models.py", 1000)
    result = single(repo, ["src/models.py"], spans=["src/models.py:900-1001"])
    assert result.returncode == 2
    assert "span out of range: src/models.py:900-1001 (file has 1000 lines)" in result.stderr


def test_span_on_a_file_without_trailing_newline_uses_splitlines(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/nt.py", 10, trailing=False)  # wc -l = 9, splitlines = 10
    result = single(repo, ["src/nt.py"], spans=["src/nt.py:10-10"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "10", "no split"]


# --------------------------------------------------------------------------
# Resolution failures
# --------------------------------------------------------------------------


def test_missing_explicit_path_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 10)
    result = single(repo, ["src/nope.py"])
    assert result.returncode == 2
    assert "pattern matched nothing: src/nope.py" in result.stderr


def test_empty_glob_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 10)
    result = single(repo, ["src/*.zzz"])
    assert result.returncode == 2
    assert "pattern matched nothing: src/*.zzz" in result.stderr


def test_directory_match_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/core/a.py", 10)
    result = single(repo, ["src/core"])
    assert result.returncode == 2
    assert "pattern matched a directory, not a file: src/core" in result.stderr


def test_empty_files_and_spans_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.write_plan(scope("core", files=[]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "scope core has no files" in result.stderr


def test_unknown_key_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.write_plan(
        "[stage.s2]\nkind = \"discover\"\n\n[[scope]]\nid = \"core\"\nstage = \"s2\"\n"
        "agent = \"a\"\nrole = \"primary\"\nfiles = [\"src/*.py\"]\ncolour = \"blue\"\n"
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "unknown key(s) in [[scope]] #1: colour" in result.stderr


def test_missing_spec_block_exits_2(tmp_path):
    repo = Repo(tmp_path)
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write("# Plan\n\nsize=small\n\nNo spec block here.\n")
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "expected exactly one '```toml plan-scopes' block, found 0" in result.stderr


def test_two_spec_blocks_exit_2(tmp_path):
    repo = Repo(tmp_path)
    body = scope("core", files=["src/*.py"])
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(
            "size=small\n\n```toml plan-scopes\n%s\n```\n\n```toml plan-scopes\n%s\n```\n"
            % (body, body)
        )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "expected exactly one '```toml plan-scopes' block, found 2" in result.stderr


def test_missing_required_key_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.write_plan(
        "[stage.s2]\n\n[[scope]]\nid = \"core\"\nstage = \"s2\"\nagent = \"a\"\n"
        "files = [\"src/*.py\"]\n"
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "is missing required key 'role'" in result.stderr


# --------------------------------------------------------------------------
# Exclude, dedupe, overlap
# --------------------------------------------------------------------------


def test_exclude_removes_the_vendored_directory(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/app.py", 100)
    repo.file("src/vendor/v.py", 900)
    result = single(repo, ["src/**/*.py"], exclude=["src/vendor/**"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "100", "no split"]
    assert repo.files_section() == ["- src/app.py \u2014 100 LOC"]


def test_duplicate_match_inside_one_scope_is_counted_once(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 40)
    repo.file("src/b.py", 60)
    result = single(repo, ["src/*.py", "src/a.py", "src/./a.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "2", "100", "no split"]
    assert repo.files_section() == ["- src/a.py \u2014 40 LOC", "- src/b.py \u2014 60 LOC"]


def test_file_in_two_scopes_is_kept_and_reported_as_overlap(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/shared.py", 100)
    repo.file("src/one.py", 200)
    repo.file("src/two.py", 300)
    repo.write_plan(
        scope("alpha", files=["src/shared.py", "src/one.py"]),
        scope("beta", files=["src/shared.py", "src/two.py"]),
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    rows = repo.rows()
    assert rows["alpha"] == ["alpha", "s2", "agent-alpha", "2", "300", "no split"]
    assert rows["beta"] == ["beta", "s2", "agent-beta", "2", "400", "no split"]
    assert "overlap: src/shared.py in alpha, beta" in repo.warnings_block()
    # the file is read by both agents, so it is counted twice in the packing total
    assert repo.packing_line("s2") == (
        "primaries=2 + intersection=0 + second opinions=0 \u2192 read-heavy agents=2, "
        "in-scope LOC=700, capacity=2 \u00d7 5,000, utilisation=7.0%"
    )


# --------------------------------------------------------------------------
# wc -l parity
# --------------------------------------------------------------------------


def test_no_trailing_newline_warns_and_counts_newlines(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/x.py", 10, trailing=False)
    result = single(repo, ["src/x.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "9", "no split"]
    assert "no trailing newline: wc -l=9, splitlines=10 (src/x.py)" in repo.warnings_block()
    assert repo.files_section() == ["- src/x.py \u2014 9 LOC"]


def test_empty_file_counts_zero(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/empty.py", 0)
    result = single(repo, ["src/empty.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "0", "no split"]
    assert repo.warnings_block() == ["None"]


def test_crlf_file_counts_newlines(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/x.py", 100, newline="\r\n")
    result = single(repo, ["src/x.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "100", "no split"]
    assert repo.warnings_block() == ["None"]


def test_path_with_spaces_and_unicode(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/dir with space/\u00fc.py", 30)
    result = single(repo, ["src/dir with space/*.py"])
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "30", "no split"]
    assert repo.files_section() == ["- src/dir with space/\u00fc.py \u2014 30 LOC"]


# --------------------------------------------------------------------------
# Packing
# --------------------------------------------------------------------------


def test_packing_arithmetic_with_intersection_and_second_opinions(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/p1.py", 1000)
    repo.file("src/p2.py", 2000)
    repo.file("src/i.py", 500)
    repo.write_plan(
        stage("s2", intersections=["inter"], second_opinions=["p1", "inter"]),
        scope("p1", files=["src/p1.py"]),
        scope("p2", files=["src/p2.py"]),
        scope("inter", files=["src/i.py"], role="intersection"),
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.packing_line("s2") == (
        "primaries=2 + intersection=1 + second opinions=2 \u2192 read-heavy agents=5, "
        "in-scope LOC=5000, capacity=5 \u00d7 5,000, utilisation=20.0%"
    )
    under = [line for line in repo.section().split("\n") if line.startswith("- p1 ") or line.startswith("- p2 ")]
    assert under == ["- p1 1000 \u2014 not merged: module-complete", "- p2 2000 \u2014 not merged: module-complete"]


def test_second_opinion_not_in_stage_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/p1.py", 100)
    repo.write_plan(
        stage("s2", second_opinions=["ghost"]),
        scope("p1", files=["src/p1.py"]),
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "stage s2: second opinion 'ghost' is not a primary/intersection scope of that stage" in result.stderr


def test_intersection_scope_is_not_cap_checked(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/i.py", 6000)
    repo.write_plan(
        stage("s2", intersections=["inter"]),
        scope("inter", files=["src/i.py"], role="intersection"),
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.rows()["inter"] == ["inter", "s2", "agent-inter", "1", "6000", "no split"]
    # intersections are not primaries: no size suggestion and no under-target bullet
    assert repo.packing_line("s2") == (
        "primaries=0 + intersection=1 + second opinions=0 \u2192 read-heavy agents=1, "
        "in-scope LOC=6000, capacity=1 \u00d7 5,000, utilisation=120.0%"
    )


# --------------------------------------------------------------------------
# Size check
# --------------------------------------------------------------------------


def test_size_override_when_the_declared_class_is_smaller(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 16, 200)  # 16 files / 3,200 LOC -> medium
    repo.write_plan(scope("core", files=["src/core/*.py"], cohesive=True), declared="small")
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    block = repo.section()
    assert "suggested: medium" in block
    assert "size override: declared small, resolved medium" in block
    assert "files=16 LOC=3200" in block


def test_no_override_when_the_declared_class_is_larger(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 16, 200)  # -> medium
    repo.write_plan(scope("core", files=["src/core/*.py"], cohesive=True), declared="large")
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    block = repo.section()
    assert "suggested: medium" in block
    assert "size override:" not in block
    assert "files=16 LOC=3200" in block


def test_size_suggests_large_over_thirty_files(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 31, 90)  # thin stub, 31 files / 2,790 LOC
    repo.write_plan(scope("core", files=["src/core/*.py"]), declared="medium")
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert "suggested: large" in repo.section()
    assert "size override: declared medium, resolved large" in repo.section()
    assert "files=31 LOC=2790" in repo.section()


# --------------------------------------------------------------------------
# Determinism, idempotence, check
# --------------------------------------------------------------------------


def test_resolve_twice_is_byte_identical(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/b.py", 100)
    repo.file("src/a.py", 200)
    repo.write_plan(scope("core", files=["src/*.py"]))
    assert repo.run("resolve").returncode == 0
    first = repo.plan_file.read_bytes()
    assert repo.run("resolve").returncode == 0
    second = repo.plan_file.read_bytes()
    assert first == second
    # the Files list is sorted by path, not by glob order
    assert repo.files_section() == ["- src/a.py \u2014 200 LOC", "- src/b.py \u2014 100 LOC"]


def test_resolve_is_idempotent_with_a_dry_run_then_a_real_run(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    before = repo.plan_file.read_bytes()
    dry = repo.run("resolve", "--dry-run")
    assert dry.returncode == 0, dry.stderr
    assert repo.plan_file.read_bytes() == before
    assert repo.run("resolve").returncode == 0
    after = repo.plan_file.read_bytes()
    assert after != before
    assert repo.run("resolve").returncode == 0
    assert repo.plan_file.read_bytes() == after


def test_check_is_clean_after_resolve(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    assert repo.run("resolve").returncode == 0
    result = repo.run("check")
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.strip() == "check: clean (1 scopes)"


def test_check_catches_a_hand_edited_loc(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    assert repo.run("resolve").returncode == 0
    text = repo.text().replace("- src/a.py \u2014 100 LOC", "- src/a.py \u2014 99 LOC")
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert "LOC drift: src/a.py recorded 99, wc -l=100" in result.stdout


def test_check_catches_a_missing_file(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    assert repo.run("resolve").returncode == 0
    (repo.root / "src/a.py").unlink()
    result = repo.run("check")
    assert result.returncode == 1
    assert "missing or not a regular file: src/a.py" in result.stdout


def test_check_reports_a_missing_generated_section(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    result = repo.run("check")
    assert result.returncode == 1
    assert "generated section missing (no plan-scopes markers)" in result.stdout


def test_check_catches_a_hand_edited_packing_line(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    assert repo.run("resolve").returncode == 0
    text = repo.text().replace("in-scope LOC=100,", "in-scope LOC=999,")
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert "packing line drift for stage s2" in result.stdout


def test_check_exits_2_on_an_input_error(tmp_path):
    repo = Repo(tmp_path)
    repo.write_plan(scope("core", files=["src/nope.py"]))
    result = repo.run("check")
    assert result.returncode == 2
    assert "pattern matched nothing" in result.stderr


def test_check_reports_drift_when_the_spec_now_violates_the_caps(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 15, 100)
    repo.write_plan(scope("core", files=["src/core/*.py"]))
    assert repo.run("resolve").returncode == 0
    for index in range(3):
        repo.file("src/core/extra%d.py" % index, 400)  # 18 files now, 2,700 LOC
    result = repo.run("check")
    assert result.returncode == 1, result.stdout + result.stderr
    assert "must split" in result.stdout


# --------------------------------------------------------------------------
# propose
# --------------------------------------------------------------------------


def test_propose_groups_an_uncut_scope_by_directory(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/w/a", 8, 200)
    repo.many("src/w/b", 8, 200)
    repo.write_plan(scope("writer", files=["src/w/**/*.py"], cohesive=False))
    result = repo.run("propose")
    assert result.returncode == 0, result.stderr
    assert "scope writer must split (files=16 in 16-20 band" in result.stdout
    assert "- writer-a: a \u2014 8 files, 1600 LOC" in result.stdout
    assert "- writer-b: b \u2014 8 files, 1600 LOC" in result.stdout
    assert BEGIN not in repo.text()


def test_propose_prints_nothing_for_a_clean_plan(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    result = repo.run("propose")
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "propose: no scope requires a split cut"


def test_propose_splits_a_group_that_still_exceeds_the_caps(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/w/a", 12, 400)  # 4,800 LOC in one directory
    repo.many("src/w/b", 4, 100)
    repo.file("src/w/a/huge.py", 300)
    repo.write_plan(scope("writer", files=["src/w/**/*.py"], cohesive=False))
    result = repo.run("propose")
    assert result.returncode == 0, result.stderr
    assert "scope writer must split (LOC=5500 > 5000)" in result.stdout
    # group a still exceeds the LOC cap and has no deeper directory to cut on
    assert "- writer-a: a \u2014 13 files, 5100 LOC" in result.stdout
    assert "- writer-b: b \u2014 4 files, 400 LOC" in result.stdout


def test_uncategorized_under_target_primary_is_reported(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"], category=None))
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert "- core 100 \u2014 not merged: uncategorized" in repo.section()
    assert "uncategorized: core (100 LOC) has no category" in repo.warnings_block()


# --------------------------------------------------------------------------
# JSON output
# --------------------------------------------------------------------------


def test_json_result_shape(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.file("src/b.py", 60)
    repo.write_plan(
        stage("s2", second_opinions=["core"]),
        scope("core", files=["src/*.py"], spans=["src/a.py:1-10"]),
    )
    result = repo.run("resolve", "--json")
    assert result.returncode == 0, result.stderr
    doc = json.loads(result.stdout)
    assert doc["ok"] is True
    assert doc["plan"] == "tmp/glm-plan.md"
    assert doc["errors"] == []
    api = doc["scopes"][0]
    assert api["id"] == "core"
    assert api["files_n"] == 2
    assert api["loc"] == 170
    assert api["verdict"] == "no split"
    assert api["files"] == [
        {"path": "src/a.py", "loc": 100, "kind": "file"},
        {"path": "src/a.py", "loc": 10, "kind": "span", "span": [1, 10]},
        {"path": "src/b.py", "loc": 60, "kind": "file"},
    ]
    assert doc["packing"]["s2"]["read_heavy_agents"] == 2
    assert doc["packing"]["s2"]["in_scope_loc"] == 340
    assert doc["packing"]["s2"]["capacity"] == 10000
    assert doc["packing"]["s2"]["utilisation"] == "3.4%"
    assert doc["size"]["declared"] == "small"
    assert doc["size"]["suggested"] is None
    assert doc["warnings"] == []


def test_json_error_is_reported_with_exit_2(tmp_path):
    repo = Repo(tmp_path)
    repo.write_plan(scope("core", files=["src/nope.py"]))
    result = repo.run("resolve", "--json")
    assert result.returncode == 2
    doc = json.loads(result.stdout)
    assert doc["ok"] is False
    assert doc["errors"] == ["pattern matched nothing: src/nope.py"]


# --------------------------------------------------------------------------
# Star-scope (overlapping wildcard matches two scopes)
# --------------------------------------------------------------------------


def test_default_root_is_the_parent_of_tmp(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"]))
    result = subprocess.run(
        [sys.executable, str(TOOL), "resolve", "--plan", str(repo.plan_file)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "100", "no split"]


def test_plan_with_an_invalid_utf8_byte_round_trips(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    body = scope("core", files=["src/*.py"])
    payload = (
        b"# Plan \xff\n\nsize=small\n\n```toml plan-scopes\n"
        + body.encode("utf-8")
        + b"\n```\n"
    )
    with open(repo.plan_file, "wb") as handle:
        handle.write(payload)
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    written = repo.plan_file.read_bytes()
    assert b"\xff" in written
    assert b"| core | s2 | agent-core | 1 | 100 | 0 | no split |" in written


# --------------------------------------------------------------------------
# reads: oracle reads count in the packing line, never in the caps
# --------------------------------------------------------------------------


def test_reads_count_in_packing_but_not_in_caps_or_size(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 900)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/models.py"]))
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    # the table keeps the audited LOC and reports the reads separately
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "100", "no split"]
    assert repo.reads_column("core") == 900
    # ... and the packing line sums both for the agent
    assert repo.packing_line("s2") == (
        "primaries=1 + intersection=0 + second opinions=0 \u2192 read-heavy agents=1, "
        "in-scope LOC=1000, capacity=1 \u00d7 5,000, utilisation=20.0%"
    )
    # the size class sees only the audited volume
    assert "files=1 LOC=100" in repo.section()
    assert "suggested: none" in repo.section()
    assert "size override:" not in repo.section()
    # the under-target band uses the same basis as the packing line
    assert "- core 1000 \u2014 not merged: module-complete" in repo.section()
    assert repo.reads_bullets("core") == ["- src/models.py \u2014 900 LOC (read-only)"]


def test_reads_do_not_trigger_a_split(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 10, 100)  # audited: 10 files / 1,000 LOC
    repo.many("src/oracle", 30, 200)  # reads: 30 files / 6,000 LOC
    repo.write_plan(
        scope("core", files=["src/core/*.py"], reads=["src/oracle/*.py"])
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "10", "1000", "no split"]
    assert repo.reads_column("core") == 6000
    assert repo.packing_line("s2") == (
        "primaries=1 + intersection=0 + second opinions=0 \u2192 read-heavy agents=1, "
        "in-scope LOC=7000, capacity=1 \u00d7 5,000, utilisation=140.0%"
    )
    assert "files=10 LOC=1000" in repo.section()
    assert "suggested: none" in repo.section()
    assert repo.run("check").returncode == 0


def test_duplicate_audited_and_read_is_counted_once(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/shared.py", 100)
    repo.file("src/oracle.py", 50)
    repo.write_plan(scope("core", files=["src/shared.py"], reads=["src/shared.py", "src/oracle.py"]))
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.reads_column("core") == 150  # the reads list itself
    # audited wins: in-scope = 100 audited + 50 read-only, not 250
    assert repo.packing_line("s2") == (
        "primaries=1 + intersection=0 + second opinions=0 \u2192 read-heavy agents=1, "
        "in-scope LOC=150, capacity=1 \u00d7 5,000, utilisation=3.0%"
    )
    assert repo.reads_bullets("core") == [
        "- src/oracle.py \u2014 50 LOC (read-only)",
        "- src/shared.py \u2014 100 LOC",
    ]
    assert repo.run("check").returncode == 0


def test_read_span_is_counted_and_rendered_as_a_span(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 1000)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/models.py:10-19"]))
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.reads_column("core") == 10
    assert repo.packing_line("s2").endswith("in-scope LOC=110, capacity=1 \u00d7 5,000, utilisation=2.2%")
    assert repo.reads_bullets("core") == [
        "- src/models.py:10-19 \u2014 10 LOC (span) (read-only)"
    ]


def test_read_span_out_of_range_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 1000)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/models.py:900-1001"]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "span out of range: src/models.py:900-1001 (file has 1000 lines)" in result.stderr


def test_read_pattern_matching_nothing_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/nope/*.py"]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "pattern matched nothing: src/nope/*.py" in result.stderr


def test_reads_only_scope_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/models.py", 900)
    repo.write_plan(scope("core", files=[], reads=["src/models.py"]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "scope core has no audited files" in result.stderr


def test_exclude_applies_to_reads(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/oracle.py", 50)
    repo.file("src/vendor/v.py", 900)
    repo.write_plan(
        scope(
            "core",
            files=["src/main.py"],
            reads=["src/oracle.py", "src/vendor/*.py"],
            exclude=["src/vendor/**"],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.reads_column("core") == 50
    assert repo.reads_bullets("core") == ["- src/oracle.py \u2014 50 LOC (read-only)"]


def test_reads_on_split_parts_are_summed_in_packing(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    repo.file("src/oracle/one.py", 200)
    repo.file("src/oracle/two.py", 300)
    repo.write_plan(
        scope(
            "core",
            files=["src/core/*.py"],
            cohesive=False,
            splits=[
                {"id": "core-a", "files": files[:8], "reads": ["src/oracle/one.py"]},
                {"id": "core-b", "files": files[8:], "reads": ["src/oracle/two.py"]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    rows = repo.rows()
    assert rows["core-a"] == ["core-a", "s2", "agent-core-core-a", "8", "800", "no split"]
    assert rows["core-b"] == ["core-b", "s2", "agent-core-core-b", "8", "800", "no split"]
    assert repo.reads_column("core-a") == 200
    assert repo.reads_column("core-b") == 300
    assert repo.packing_line("s2") == (
        "primaries=2 + intersection=0 + second opinions=0 \u2192 read-heavy agents=2, "
        "in-scope LOC=2100, capacity=2 \u00d7 5,000, utilisation=21.0%"
    )
    assert repo.run("check").returncode == 0


def test_check_catches_a_hand_edited_read_loc(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 900)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/models.py"]))
    assert repo.run("resolve").returncode == 0
    text = repo.text().replace(
        "- src/models.py \u2014 900 LOC (read-only)",
        "- src/models.py \u2014 899 LOC (read-only)",
    )
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert "LOC drift: src/models.py recorded 899, wc -l=900" in result.stdout


def test_check_catches_a_removed_read_bullet(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 900)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/models.py"]))
    assert repo.run("resolve").returncode == 0
    text = repo.text().replace("\n- src/models.py \u2014 900 LOC (read-only)", "")
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert "reads LOC drift: core recorded 0, computed 900" in result.stdout
    assert "reads LOC column drift: core recorded 900, computed 900" not in result.stdout


def test_check_catches_a_read_counted_twice_in_the_packing_line(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/shared.py", 100)
    repo.file("src/oracle.py", 50)
    repo.write_plan(scope("core", files=["src/shared.py"], reads=["src/shared.py", "src/oracle.py"]))
    assert repo.run("resolve").returncode == 0
    text = repo.text().replace("in-scope LOC=150,", "in-scope LOC=250,")
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert (
        "in-scope LOC drift: stage s2 recorded 250, section sums to 150 "
        "(audited + read-only)" in result.stdout
    )


def test_check_catches_a_missing_read_file(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 900)
    repo.write_plan(scope("core", files=["src/main.py"], reads=["src/models.py"]))
    assert repo.run("resolve").returncode == 0
    (repo.root / "src/models.py").unlink()
    result = repo.run("check")
    assert result.returncode == 1
    assert "missing or not a regular file: src/models.py (read)" in result.stdout


def test_resolve_with_reads_is_byte_identical_on_a_second_run(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 900)
    repo.many("src/oracle", 3, 200)
    repo.write_plan(
        scope("core", files=["src/main.py"], reads=["src/models.py", "src/oracle/*.py"])
    )
    assert repo.run("resolve").returncode == 0
    first = repo.plan_file.read_bytes()
    assert repo.run("resolve").returncode == 0
    assert repo.plan_file.read_bytes() == first
    result = repo.run("check")
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.strip() == "check: clean (1 scopes)"


def test_json_exposes_reads_and_reads_loc(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/main.py", 100)
    repo.file("src/models.py", 900)
    repo.write_plan(
        scope("core", files=["src/main.py"], reads=["src/models.py", "src/models.py:1-10"])
    )
    result = repo.run("resolve", "--json")
    assert result.returncode == 0, result.stderr
    api = json.loads(result.stdout)["scopes"][0]
    assert api["loc"] == 100
    assert api["reads_loc"] == 910
    assert api["reads"] == [
        {"path": "src/models.py", "loc": 900, "kind": "file"},
        {"path": "src/models.py", "loc": 10, "kind": "span", "span": [1, 10]},
    ]
    # no audited path is among the reads, so read-only == reads
    packing = json.loads(result.stdout)["packing"]["s2"]
    assert packing["in_scope_loc"] == 1010


# --------------------------------------------------------------------------
# scope class: the size axis counts source files and source LOC only
# --------------------------------------------------------------------------


def test_size_of_an_all_source_plan_is_unchanged(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 16, 200)  # 16 files / 3,200 LOC, all source
    repo.write_plan(scope("core", files=["src/core/*.py"], cohesive=True), declared="small")
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    block = repo.section()
    assert "suggested: medium" in block
    assert "size override: declared small, resolved medium" in block
    assert "source files=16 LOC=3200" in block
    assert "files=16 LOC=3200" in block
    assert "other files=" not in block
    assert repo.run("check").returncode == 0


def test_non_source_volume_does_not_raise_the_size_class(tmp_path):
    """The real replay case: 9,385 source LOC + 2,419 test LOC -> medium, no override."""
    repo = Repo(tmp_path)
    for name, lines in (("a1", 1500), ("a2", 1600), ("a3", 1600)):
        repo.file("src/%s.py" % name, lines)
    for name, lines in (("b1", 1600), ("b2", 1600), ("b3", 1485)):
        repo.file("src/%s.py" % name, lines)
    for index, lines in enumerate((500, 500, 500, 500, 419)):
        repo.file("tests/t%d.py" % index, lines)
    repo.write_plan(
        scope("src-a", files=["src/a*.py"]),
        scope("src-b", files=["src/b*.py"]),
        scope("suite", files=["tests/*.py"], klass="test"),
        declared="medium",
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    block = repo.section()
    assert "suggested: medium" in block
    assert "size override:" not in block
    assert "source files=6 LOC=9385" in block
    assert "other files=5 LOC=2419" in block
    assert "files=11 LOC=11804" in block
    assert repo.run("check").returncode == 0


def test_source_volume_alone_over_ten_thousand_suggests_large(tmp_path):
    repo = Repo(tmp_path)
    for prefix, sizes in (("a", (1400, 1400, 1200)), ("b", (1400, 1400, 1200)), ("c", (1000, 1000, 1000))):
        for index, lines in enumerate(sizes):
            repo.file("src/%s%d.py" % (prefix, index), lines)
    repo.write_plan(
        scope("src-a", files=["src/a*.py"]),
        scope("src-b", files=["src/b*.py"]),
        scope("src-c", files=["src/c*.py"]),
        declared="medium",
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    block = repo.section()
    assert "suggested: large" in block
    assert "size override: declared medium, resolved large" in block
    assert "source files=9 LOC=11000" in block
    assert "files=9 LOC=11000" in block
    assert "other files=" not in block


def test_test_class_scope_over_the_per_scope_cap_still_must_split(tmp_path):
    repo = Repo(tmp_path)
    repo.many("tests/suite", 21, 200)  # 21 files / 4,200 LOC
    repo.write_plan(scope("suite", files=["tests/suite/*.py"], klass="test"))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "scope suite must split (files=21 > 20)" in result.stderr


def test_unknown_class_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 100)
    repo.write_plan(scope("core", files=["src/*.py"], klass="tests"))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "scope core: unknown class 'tests' (allowed: build, config, docs, source, test)" in result.stderr


def test_check_catches_a_size_line_computed_without_classes(tmp_path):
    repo = Repo(tmp_path)
    for name, lines in (("a1", 1500), ("a2", 1600), ("a3", 1600)):
        repo.file("src/%s.py" % name, lines)
    for index, lines in enumerate((500, 500, 500, 500, 419)):
        repo.file("tests/t%d.py" % index, lines)
    repo.write_plan(
        scope("src-a", files=["src/a*.py"]),
        scope("suite", files=["tests/*.py"], klass="test"),
        declared="medium",
    )
    assert repo.run("resolve").returncode == 0
    text = repo.text().replace(
        "source files=3 LOC=4700", "source files=8 LOC=7119"
    )
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert "size source totals missing or changed (expected 'source files=3 LOC=4700')" in result.stdout


def test_check_catches_a_hand_edited_scope_class(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/a.py", 4000)
    repo.file("tests/t.py", 3000)
    repo.write_plan(
        scope("src-a", files=["src/a.py"]),
        scope("suite", files=["tests/t.py"], klass="test"),
        declared="medium",
    )
    assert repo.run("resolve").returncode == 0
    # flip the test scope to source: 7,000 source LOC would now suggest medium anyway,
    # so the section's source/other totals no longer match the recomputation
    text = repo.text().replace('class = "test"', 'class = "source"')
    with open(repo.plan_file, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    result = repo.run("check")
    assert result.returncode == 1
    assert "size source totals missing or changed" in result.stdout


def test_split_parts_inherit_the_parent_class(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("tests/suite", 16, 100)  # 16 files / 1,600 LOC
    repo.write_plan(
        scope(
            "suite",
            files=["tests/suite/*.py"],
            cohesive=False,
            klass="test",
            splits=[{"id": "suite-a", "files": files[:8]}, {"id": "suite-b", "files": files[8:]}],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    block = repo.section()
    assert "source files=0 LOC=0" in block
    assert "other files=16 LOC=1600" in block
    assert "suggested: none" in block
    assert set(repo.rows()) == {"suite-a", "suite-b"}
    assert json.loads(repo.run("resolve", "--json").stdout)["scopes"][0]["class"] == "test"


def test_unknown_class_on_a_split_part_exits_2(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    repo.write_plan(
        scope(
            "core",
            files=["src/core/*.py"],
            cohesive=False,
            splits=[
                {"id": "core-a", "files": files[:8], "class": "tests"},
                {"id": "core-b", "files": files[8:]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "unknown class 'tests'" in result.stderr


# --------------------------------------------------------------------------
# split polish: warning dedupe, derived agents, in-file (span) splits
# --------------------------------------------------------------------------


def test_split_parts_get_derived_agent_ids(tmp_path):
    repo = Repo(tmp_path)
    core = repo.many("src/core", 7, 100)
    solver = repo.many("src/solver", 9, 100)
    repo.write_plan(
        scope(
            "cpp-kriging",
            files=["src/core/*.py", "src/solver/*.py"],
            agent="s2-discover-cpp-kriging",
            cohesive=False,
            splits=[
                {"id": "core", "files": core},
                {"id": "solver", "files": solver},
            ],
            category=None,
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    rows = repo.rows()
    assert rows["core"][2] == "s2-discover-cpp-kriging-core"
    assert rows["solver"][2] == "s2-discover-cpp-kriging-solver"
    assert rows["core"][3:5] == ["7", "700"]
    assert rows["solver"][3:5] == ["9", "900"]


def test_duplicate_agent_across_two_parts_exits_2(tmp_path):
    repo = Repo(tmp_path)
    files = repo.many("src/core", 16, 100)
    repo.write_plan(
        scope(
            "core",
            files=["src/core/*.py"],
            cohesive=False,
            splits=[
                {"id": "core-a", "files": files[:8], "agent": "s2-dup"},
                {"id": "core-b", "files": files[8:], "agent": "s2-dup"},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "stage s2: duplicate agent id 's2-dup' used by scopes core-a and core-b" in result.stderr


def test_split_warning_text_appears_once(tmp_path):
    repo = Repo(tmp_path)
    repo.many("src/core", 15, 100)
    repo.file("src/core/notrail.py", 27 - 1)  # 26 newlines, no trailing newline
    with open(repo.root / "src/core/notrail.py", "wb") as handle:
        handle.write(b"x\n" * 26 + b"x")
    files = ["src/core/f%02d.py" % i for i in range(15)] + ["src/core/notrail.py"]
    repo.write_plan(
        scope(
            "core",
            files=["src/core/*.py"],
            cohesive=False,
            splits=[
                {"id": "core-a", "files": files[:8]},
                {"id": "core-b", "files": files[8:]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    warnings = repo.warnings_block()
    assert warnings == ["no trailing newline: wc -l=26, splitlines=27 (src/core/notrail.py)"]
    assert len(warnings) == 1


def test_in_file_split_covers_the_whole_file(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/models.py", 6000)
    repo.write_plan(
        scope(
            "models",
            files=["src/models.py"],
            splits=[
                {"id": "models-a", "spans": ["src/models.py:1-3000"]},
                {"id": "models-b", "spans": ["src/models.py:3001-6000"]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    rows = repo.rows()
    assert rows["models-a"] == ["models-a", "s2", "agent-models-models-a", "1", "3000", "no split"]
    assert rows["models-b"] == ["models-b", "s2", "agent-models-models-b", "1", "3000", "no split"]
    assert repo.files_section() == [
        "- src/models.py:1-3000 \u2014 3000 LOC (span)",
        "- src/models.py:3001-6000 \u2014 3000 LOC (span)",
    ]
    assert repo.run("check").returncode == 0


def test_in_file_split_with_a_gap_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/models.py", 6000)
    repo.write_plan(
        scope(
            "models",
            files=["src/models.py"],
            splits=[
                {"id": "models-a", "spans": ["src/models.py:1-3000"]},
                {"id": "models-b", "spans": ["src/models.py:3002-6000"]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "gap in src/models.py: lines 3001-3001 not covered by split parts" in result.stderr


def test_in_file_split_with_an_overlap_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/models.py", 6000)
    repo.write_plan(
        scope(
            "models",
            files=["src/models.py"],
            splits=[
                {"id": "models-a", "spans": ["src/models.py:1-3000"]},
                {"id": "models-b", "spans": ["src/models.py:3000-6000"]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 2
    assert (
        "overlap in src/models.py: lines 1-3000 (models-a) and 3000-6000 (models-b)"
        in result.stderr
    )


def test_in_file_split_reports_no_false_warnings(tmp_path):
    """A legal span split is not an overlap, and the replaced parent's escape
    verdict must not survive as a warning."""
    repo = Repo(tmp_path)
    repo.file("src/models.py", 6000)
    repo.write_plan(
        scope(
            "models",
            files=["src/models.py"],
            splits=[
                {"id": "models-a", "spans": ["src/models.py:1-3000"]},
                {"id": "models-b", "spans": ["src/models.py:3001-6000"]},
            ],
        )
    )
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.warnings_block() == ["None"]
    assert repo.run("check").returncode == 0


# --------------------------------------------------------------------------
# cross-platform hardening: exact path case, symlinks, Windows separators
# --------------------------------------------------------------------------


def test_path_case_is_verified_on_every_segment(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/core/a.py", 40)

    # Probe the host filesystem instead of assuming one: on a case-insensitive
    # volume the case variant resolves to the real file, on ext4 it does not.
    with open(repo.root / "probe.txt", "w", encoding="utf-8", newline="") as handle:
        handle.write("x\n")
    case_insensitive = os.path.exists(repo.root / "PROBE.TXT")
    variant_resolves = os.path.exists(repo.root / "src" / "CORE" / "a.py")
    assert variant_resolves == case_insensitive  # the probe describes this host

    # a correctly-cased path resolves on either kind of filesystem
    repo.write_plan(scope("core", files=["src/core/a.py"]))
    exact = repo.run("resolve")
    assert exact.returncode == 0, exact.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "40", "no split"]

    # A span is a direct path (no glob), so a wrong-case segment is exactly the
    # case the guard exists for. The guard compares readdir names itself and runs
    # before any existence check, so the diagnostic is identical on both kinds of
    # filesystem -- on a case-sensitive host "not a regular file" cannot appear,
    # because the segment list is already rejected as a case mismatch.
    repo.write_plan(scope("core", files=["src/core/a.py"], spans=["src/Core/a.py:1-2"]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "path case mismatch: src/Core/a.py" in result.stderr
    assert "on disk: src/core/a.py" in result.stderr

    # The glob form must never silently resolve to the differently-cased file;
    # whether the matcher or the case guard rejects it, the path is named.
    repo.write_plan(scope("core", files=["src/Core/a.py"]))
    glob_result = repo.run("resolve")
    assert glob_result.returncode == 2
    assert "src/Core/a.py" in glob_result.stderr


@pytest.mark.skipif(
    os.name == "nt",
    reason="os.symlink needs privilege or developer mode on Windows",
)
def test_internal_file_symlink_is_counted(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/real.py", 100)
    os.symlink("real.py", repo.root / "src" / "link.py")
    repo.write_plan(scope("core", files=["src/link.py"]))
    result = repo.run("resolve")
    assert result.returncode == 0, result.stderr
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "100", "no split"]
    assert repo.files_section() == ["- src/link.py \u2014 100 LOC"]
    assert repo.run("check").returncode == 0


@pytest.mark.skipif(
    os.name == "nt",
    reason="os.symlink needs privilege or developer mode on Windows",
)
def test_symlink_escaping_the_root_exits_2(tmp_path):
    outside = tmp_path / "outside.py"
    outside.write_text("x\n" * 5)
    repo = Repo(tmp_path / "repo")
    repo.file("src/a.py", 10)
    os.symlink(outside, repo.root / "src" / "out.py")
    repo.write_plan(scope("core", files=["src/out.py"]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "path escapes --root through a symlink: src/out.py (resolves to " in result.stderr
    assert "outside.py" in result.stderr


@pytest.mark.skipif(
    os.name == "nt",
    reason="os.symlink needs privilege or developer mode on Windows",
)
def test_directory_symlink_exits_2(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/core/a.py", 10)
    os.symlink("core", repo.root / "src" / "dirlink")
    repo.write_plan(scope("core", files=["src/dirlink"]))
    result = repo.run("resolve")
    assert result.returncode == 2
    assert "pattern matched a directory symlink, not a file: src/dirlink" in result.stderr


def test_backslash_paths_match_the_posix_form(tmp_path):
    repo = Repo(tmp_path)
    repo.file("src/pkg/a.py", 100)
    repo.file("src/pkg/skip.py", 500)
    repo.file("src/oracle/o.py", 40)

    repo.write_plan(
        scope(
            "core",
            files=["src\\pkg\\*.py"],
            exclude=["src\\pkg\\skip.py"],
            spans=["src\\pkg\\a.py:10-19"],
            reads=["src\\oracle\\*.py"],
        )
    )
    assert repo.run("resolve").returncode == 0
    windows_section = repo.section()

    repo.write_plan(
        scope(
            "core",
            files=["src/pkg/*.py"],
            exclude=["src/pkg/skip.py"],
            spans=["src/pkg/a.py:10-19"],
            reads=["src/oracle/*.py"],
        )
    )
    assert repo.run("resolve").returncode == 0
    posix_section = repo.section()

    assert windows_section == posix_section
    assert "\\" not in windows_section
    assert repo.rows()["core"] == ["core", "s2", "agent-core", "1", "110", "no split"]
    assert repo.reads_column("core") == 40
    assert repo.files_section() == [
        "- src/pkg/a.py \u2014 100 LOC",
        "- src/pkg/a.py:10-19 \u2014 10 LOC (span)",
        "- src/oracle/o.py \u2014 40 LOC (read-only)",
    ]
    assert repo.reads_bullets("core") == ["- src/oracle/o.py \u2014 40 LOC (read-only)"]
    assert repo.run("check").returncode == 0
