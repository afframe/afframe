# Laya vs Jev benchmark

Runs the same typed questions (`questions.json`) over a folder of invoices with
[Laya](https://github.com/NandhaKishorM/laya) (open weights, runs locally) and, when a key is
set, TypeSafe's [Jev](https://docs.typesafe.ai) API, then reports accuracy, agreement,
confidence, speed and Jev cost. No LLM in the loop.

## Data handling

- Laya runs on this machine; nothing leaves it.
- Jev receives the extracted text of every document (TypeSafe, US). Leave `TYPESAFE_API_KEY`
  unset or pass `--no-jev` to keep a run local.
- Write `--out` outside the repo; outputs contain file names and answers.

## Run (macOS)

```bash
cd experiments/laya-vs-jev
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

1. First pass on a random sample of 100 documents (downloads ~1.5 GB of Laya weights once):

```bash
export TYPESAFE_API_KEY=$(secret get TYPESAFE_API_KEY)
.venv/bin/python bench.py <invoice-folder> \
  --out ~/Desktop/workspace/laya-vs-jev/run1 --company "<Your Company s.r.o.>" --limit 100
```

2. Fill the blank columns of `run1/labels_template.csv` with the correct answers (the models'
   guesses are alongside; documents where they disagree come first). Save it as `labels.csv`.
   Choice columns take an option name from `questions.json`; yes/no columns take `yes` or `no`.
   Leave a cell blank to skip it.

3. Score accuracy on the labelled documents:

```bash
.venv/bin/python bench.py <invoice-folder> \
  --out ~/Desktop/workspace/laya-vs-jev/run2 --company "<Your Company s.r.o.>" \
  --labels ~/Desktop/workspace/laya-vs-jev/run1/labels.csv
```

## Outputs

| file | content |
|---|---|
| `summary.md` | accuracy per question and system, agreement with Jev, confidence, latency, Jev cost |
| `results.csv` | one row per document, question and system |
| `documents.csv` | extraction status (scans without a text layer are skipped), latency, errors |
| `labels_template.csv` | label sheet to fill |

## Options

- `--laya-model`: checkpoints to compare, default `english,multilingual,typed-decisions`
  (the Router sends Czech to `multilingual`, but `english` scored higher on Czech invoices in a
  smoke test, so all three are compared).
- `--questions`: edit or copy `questions.json` to ask other questions.
- `--max-len` (default 4096) is applied to every checkpoint. Their trained limits are 512
  (`english`) and 1024 (the others), but a 4096 run gave no errors, and without it a VAT line at the
  end of a long invoice is cut off.
- `--no-jev`, `--limit`, `--seed`, `--max-len`, `--max-chars`, `--jev-workers`.

Only `.pdf` and `.txt` are read. The summary counts every file type in the folder, so you can see
what was left out (photos, ISDOC/XML). Scanned PDFs without a text layer are counted and skipped;
OCR is out of scope here.
