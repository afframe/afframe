"""Laya vs Jev on a folder of invoices, run locally.

Extracts text from each PDF/TXT, asks the same typed questions (questions.json) to
Laya (local, open weights) and, if TYPESAFE_API_KEY is set, to TypeSafe's Jev API,
then writes per-answer results, a label sheet and a summary. Nothing but the
extracted text is sent to Jev; nothing is sent anywhere for Laya.

See README.md for usage.
"""
import argparse
import csv
import json
import os
import random
import re
import statistics
import sys
import time
from collections import Counter
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
JEV_URL = "https://api.typesafe.ai/v1/systemone"
JEV_USD_PER_MTOK = 0.042
DOC_EXT = {".pdf", ".txt"}
MIN_TEXT_CHARS = 50  # below this a PDF is treated as a scan without a text layer


def extract_text(path: Path) -> str:
    if path.suffix.lower() == ".txt":
        return path.read_text(errors="replace")
    from pypdf import PdfReader
    reader = PdfReader(str(path))
    return "\n".join((page.extract_text() or "") for page in reader.pages)


def clean(text: str, max_chars: int) -> str:
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n\s*\n+", "\n", text).strip()
    return text[:max_chars]


def load_questions(path: Path, company: str | None) -> dict:
    questions = json.loads(path.read_text())
    if company:
        questions["issued_by_company"] = {
            "type": "noul",
            "instructions": f"Is {company} the supplier who issued this document (not the customer who receives it)?",
        }
    return questions


def normalize(answer: dict | None) -> tuple[str, float | None]:
    """Map a typed answer to a comparable label and a confidence."""
    if not answer:
        return "", None
    kind = answer.get("type")
    if kind == "choice":
        return str(answer.get("choice", "")), answer.get("confidence")
    if kind == "noul":
        p = answer.get("noul")
        if p is None:
            return "", None
        return ("yes" if p >= 0.5 else "no"), round(abs(p - 0.5) * 2, 4)
    if kind == "score":
        s = answer.get("score")
        return ("" if s is None else str(round(s))), answer.get("confidence")
    return "", None


def call_jev(state: str, questions: dict, key: str, url: str, retries: int = 5) -> tuple[dict, float]:
    body = json.dumps({"state": state, "model": "jev-latest", "questions": questions}).encode()
    delay = 2.0
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, data=body, method="POST", headers={
            "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
        start = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.load(resp)
            return data, (time.perf_counter() - start) * 1000
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504, 529) and attempt < retries:
                time.sleep(delay)
                delay *= 2
                continue
            raise RuntimeError(f"Jev HTTP {e.code}: {e.read()[:300]!r}") from e
        except urllib.error.URLError:
            if attempt < retries:
                time.sleep(delay)
                delay *= 2
                continue
            raise
    raise RuntimeError("unreachable")


def load_labels(path: Path | None, questions: dict) -> dict:
    """Wide CSV: file, <question id>... ; blank cells are ignored."""
    if not path:
        return {}
    gold = {}
    with path.open(newline="") as f:
        for row in csv.DictReader(f):
            gold[row["file"]] = {q: row[q].strip() for q in questions if row.get(q, "").strip()}
    return gold


def pct(values: list[float], q: float) -> float:
    values = sorted(values)
    return values[min(len(values) - 1, int(q * len(values)))]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", type=Path, help="folder with invoices (searched recursively)")
    ap.add_argument("--out", type=Path, required=True, help="output folder (keep it outside the repo)")
    ap.add_argument("--limit", type=int, default=100, help="random sample size (0 = all)")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--company", help="our company's name, adds an issued/received question")
    ap.add_argument("--questions", type=Path, default=HERE / "questions.json")
    ap.add_argument("--labels", type=Path, help="filled label sheet to score accuracy")
    ap.add_argument("--no-jev", action="store_true", help="run Laya only even if TYPESAFE_API_KEY is set")
    ap.add_argument("--jev-url", default=JEV_URL)
    ap.add_argument("--jev-workers", type=int, default=4)
    ap.add_argument("--laya-model", default="english,multilingual,typed-decisions",
                    help="comma-separated Laya checkpoints to compare: english, multilingual, typed-decisions, auto")
    ap.add_argument("--max-len", type=int, default=4096, help="Laya token budget per document")
    ap.add_argument("--max-chars", type=int, default=12000, help="characters of text kept per document")
    args = ap.parse_args()

    questions = load_questions(args.questions, args.company)
    gold = load_labels(args.labels, questions)
    key = None if args.no_jev else os.environ.get("TYPESAFE_API_KEY")
    args.out.mkdir(parents=True, exist_ok=True)

    all_files = [p for p in args.folder.rglob("*") if p.is_file() and not p.name.startswith(".")]
    by_ext = Counter(p.suffix.lower() or "(none)" for p in all_files)
    files = sorted(p for p in all_files if p.suffix.lower() in DOC_EXT)
    if gold:
        files = [p for p in files if str(p.relative_to(args.folder)) in gold]
    elif args.limit and len(files) > args.limit:
        files = sorted(random.Random(args.seed).sample(files, args.limit))
    print(f"{len(files)} documents, Jev {'on' if key else 'off'}", file=sys.stderr)

    docs = []
    for p in files:
        rel = str(p.relative_to(args.folder))
        try:
            text = clean(extract_text(p), args.max_chars)
            status = "ok" if len(text) >= MIN_TEXT_CHARS else "no_text_layer"
        except Exception as e:  # noqa: BLE001 - a broken file must not stop the run
            text, status = "", f"read_error: {e}"[:120]
        docs.append({"file": rel, "text": text, "status": status})
    todo = [d for d in docs if d["status"] == "ok"]

    jev_futures = {}
    pool = ThreadPoolExecutor(max_workers=args.jev_workers) if key else None
    if pool:
        for d in todo:
            jev_futures[d["file"]] = pool.submit(call_jev, d["text"], questions, key, args.jev_url)

    from laya import Router
    router = Router()
    models = [m.strip() for m in args.laya_model.split(",") if m.strip()]
    systems = [f"laya:{m}" for m in models] + (["jev"] if key else [])
    for d in todo:
        d["answers"], d["ms"], d["errors"] = {}, {}, []
    for m in models:
        model = None if m == "auto" else m
        if todo:  # warm-up so the first document's latency excludes loading the weights
            router.predict(todo[0]["text"][:500], questions, model=model)
        for i, d in enumerate(todo, 1):
            start = time.perf_counter()
            try:
                d["answers"][f"laya:{m}"] = router.predict(d["text"], questions, model=model,
                                                           max_len=args.max_len)["answers"]
                d["ms"][f"laya:{m}"] = (time.perf_counter() - start) * 1000
            except Exception as e:  # noqa: BLE001
                d["errors"].append(f"laya:{m}: {e}"[:200])
            print(f"[laya:{m} {i}/{len(todo)}] {d['file']}", file=sys.stderr)
    if pool:
        for d in todo:
            try:
                resp, d["ms"]["jev"] = jev_futures[d["file"]].result()
                d["answers"]["jev"] = resp.get("answers", {})
                d["jev_tokens"] = resp.get("usage", {}).get("input_tokens", 0)
                d["jev_model"] = resp.get("model", "")
            except Exception as e:  # noqa: BLE001
                d["errors"].append(f"jev: {e}"[:200])
        pool.shutdown()

    # Per-answer results, one row per document, question and system
    rows = []
    for d in todo:
        for q in questions:
            g = gold.get(d["file"], {}).get(q, "")
            for sname in systems:
                a, c = normalize(d["answers"].get(sname, {}).get(q))
                rows.append({"file": d["file"], "question": q, "system": sname, "answer": a,
                             "confidence": c, "gold": g, "correct": (a == g) if g else ""})
    with (args.out / "results.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["file", "question", "system", "answer", "confidence", "gold", "correct"])
        w.writeheader()
        w.writerows(rows)

    with (args.out / "documents.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["file", "status", "chars"] + [f"{s}_ms" for s in systems] + ["jev_input_tokens", "errors"])
        for d in docs:
            w.writerow([d["file"], d["status"], len(d["text"])]
                       + [round(d.get("ms", {}).get(s, 0)) for s in systems]
                       + [d.get("jev_tokens", ""), " | ".join(d.get("errors", []))])

    # Label sheet: blank columns to fill, with every system's guess alongside;
    # documents where the systems disagree most come first.
    answer = {(r["file"], r["question"], r["system"]): r["answer"] for r in rows}

    def disagreement(fname):
        return sum(len({answer[(fname, q, s)] for s in systems}) > 1 for q in questions)

    with (args.out / "labels_template.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["file"] + list(questions) + [f"{q}__{s}" for s in systems for q in questions])
        for fname in sorted({d["file"] for d in todo}, key=disagreement, reverse=True):
            w.writerow([fname] + [""] * len(questions)
                       + [answer[(fname, q, s)] for s in systems for q in questions])

    # Summary
    lines = ["# Laya vs Jev", "",
             f"Documents found: {len(docs)}; with a text layer: {len(todo)}; "
             f"without (scans, need OCR): {sum(d['status'] == 'no_text_layer' for d in docs)}; "
             f"unreadable: {sum(d['status'].startswith('read_error') for d in docs)}.",
             "Files in folder by type (only .pdf and .txt are read): "
             + ", ".join(f"{e} {n}" for e, n in by_ext.most_common()) + ".",
             f"Laya max_len {args.max_len}. "
             f"Jev: {next((d['jev_model'] for d in todo if d.get('jev_model')), 'not run')}.", ""]

    def rate(vals):
        vals = [v for v in vals if v != ""]
        return f"{sum(vals) / len(vals):.2f} ({len(vals)})" if vals else "-"

    def mean(vals):
        vals = [v for v in vals if isinstance(v, (int, float))]
        return f"{statistics.mean(vals):.2f}" if vals else "-"

    lines += ["## Accuracy against labels (rate, count)", "",
              "| question | " + " | ".join(systems) + " |", "|---|" + "---|" * len(systems)]
    for q in questions:
        lines.append(f"| {q} | " + " | ".join(
            rate([r["correct"] for r in rows if r["question"] == q and r["system"] == s]) for s in systems) + " |")
    lines.append("| **all** | " + " | ".join(
        rate([r["correct"] for r in rows if r["system"] == s]) for s in systems) + " |")
    if "jev" in systems and len(systems) > 1:
        lines += ["", "## Agreement with Jev", "", "| question | " + " | ".join(systems[:-1]) + " |",
                  "|---|" + "---|" * (len(systems) - 1)]
        for q in questions:
            cells = []
            for s in systems[:-1]:
                pairs = [(answer[(d["file"], q, s)], answer[(d["file"], q, "jev")]) for d in todo]
                cells.append(rate([a == b for a, b in pairs if a and b]))
            lines.append(f"| {q} | " + " | ".join(cells) + " |")
    lines += ["", "## Mean confidence", "", "| question | " + " | ".join(systems) + " |",
              "|---|" + "---|" * len(systems)]
    for q in questions:
        lines.append(f"| {q} | " + " | ".join(
            mean([r["confidence"] for r in rows if r["question"] == q and r["system"] == s]) for s in systems) + " |")
    lines += ["", "## Speed and cost", ""]
    for s in systems:
        ms = [d["ms"][s] for d in todo if s in d["ms"]]
        if ms:
            lines.append(f"- {s}: p50 {pct(ms, .5):.0f} ms, p95 {pct(ms, .95):.0f} ms per document "
                         f"(all questions in one call), n={len(ms)}")
    tokens = sum(d.get("jev_tokens", 0) or 0 for d in todo)
    if tokens:
        lines.append(f"- Jev input tokens: {tokens:,}; cost ≈ ${tokens / 1e6 * JEV_USD_PER_MTOK:.4f} "
                     f"(${tokens / max(1, len(todo)) * 1000 / 1e6 * JEV_USD_PER_MTOK:.4f} per 1,000 documents)")
    errors = sum(1 for d in todo if d.get("errors"))
    if errors:
        lines.append(f"- Errors: {errors} documents, see documents.csv")
    lines += ["", "Accuracy needs a filled label sheet (--labels); without it only agreement, confidence and speed are real."]
    (args.out / "summary.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
