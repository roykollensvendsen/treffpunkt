# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Export the contributed training set from the linked Supabase project.

Downloads every image in the private `training-images` bucket and the matching
`training_samples` rows into ./data, via the `supabase` CLI (must be logged in
and linked). The dataset is private user data — ./data is git-ignored.

Output:
  data/images/<uid>__<id>.jpg   the re-encoded contributed photos
  data/labels.jsonl             one JSON row per sample (id, image_path,
                                program, label, image present?)
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
IMAGES = DATA / "images"
BUCKET = "training-images"
# Tables to exclude from the data-only dump so only training_samples is pulled.
_EXCLUDE = ",".join(
    f"public.{t}"
    for t in (
        "profiles",
        "sessions",
        "competitions",
        "competition_members",
        "competition_invitations",
        "competition_results",
        "competition_join_tokens",
    )
)


def _supabase(*args: str) -> str:
    """Run a supabase CLI command, returning stdout (raises on failure)."""
    result = subprocess.run(
        ["supabase", *args],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def _ls(prefix: str) -> list[str]:
    out = _supabase(
        "storage", "ls", f"ss:///{prefix}", "--linked", "--experimental"
    )
    entries = []
    for line in out.splitlines():
        line = line.strip()
        if not line or "Supabase CLI" in line or "recommend updating" in line:
            continue
        if line.startswith("Initialising"):
            continue
        entries.append(line)
    return entries


def download_images() -> int:
    IMAGES.mkdir(parents=True, exist_ok=True)
    count = 0
    for uid_dir in _ls(f"{BUCKET}/"):
        uid = uid_dir.rstrip("/")
        for name in _ls(f"{BUCKET}/{uid}/"):
            dest = IMAGES / f"{uid}__{name}"
            _supabase(
                "storage",
                "cp",
                f"ss:///{BUCKET}/{uid}/{name}",
                str(dest),
                "--linked",
                "--experimental",
            )
            count += 1
            print(f"  image {dest.name}")
    return count


def dump_labels() -> list[dict]:
    dump = DATA / "_dump.sql"
    _supabase(
        "db",
        "dump",
        "--data-only",
        "--linked",
        "--use-copy",
        "--schema",
        "public",
        "--exclude",
        _EXCLUDE,
        "-f",
        str(dump),
    )
    txt = dump.read_text()
    m = re.search(
        r'COPY "public"\."training_samples" \((.*?)\) FROM stdin;\n(.*?)\n\\\.',
        txt,
        re.S,
    )
    if not m:
        return []
    cols = [c.strip().strip('"') for c in m.group(1).split(",")]
    rows = []
    for line in m.group(2).splitlines():
        if not line.strip():
            continue
        rec = dict(zip(cols, line.split("\t")))
        label = json.loads(rec["label"].encode().decode("unicode_escape"))
        image_name = f"{rec['user_id']}__{Path(rec['image_path']).name}"
        rows.append(
            {
                "id": rec["id"],
                "image": image_name,
                "image_present": (IMAGES / image_name).exists(),
                "program": rec.get("program"),
                "created_at": rec.get("created_at"),
                "label": label,
            }
        )
    return rows


def main() -> int:
    DATA.mkdir(exist_ok=True)
    print("Downloading images …")
    n_images = download_images()
    print("Dumping labels …")
    rows = dump_labels()
    (DATA / "labels.jsonl").write_text(
        "".join(json.dumps(r) + "\n" for r in rows)
    )
    print(f"\n{n_images} images, {len(rows)} labelled samples -> {DATA}")
    # A quick by-program tally so we can eyeball the set.
    by_program: dict[str, int] = {}
    for r in rows:
        by_program[r["program"]] = by_program.get(r["program"], 0) + 1
    for program, count in sorted(by_program.items()):
        print(f"  {count:3d}  {program}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
