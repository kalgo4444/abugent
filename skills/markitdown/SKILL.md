---
name: markitdown
description: Convert an uploaded or attached file (PDF, Word .docx, PowerPoint .pptx, Excel .xlsx, CSV/TSV, JSON, XML, HTML, EPUB, images, ZIP, plain text) into a clean Markdown .md file the user can download, keeping headings, lists, tables and links. No Python or MarkItDown install needed. Use this whenever the user uploads or points to a document and wants it "as markdown", "in .md", "converted to md", "LLM-ready", "for RAG / ChatGPT / Claude / Obsidian / Notion", or wants a document's text extracted with its structure kept — even if they only say "convert this" or "give me the text of this file" and never say the word Markdown.
---

# File → Markdown

Turn the user's file into a faithful `.md` file, the way Microsoft's MarkItDown does, but using only Claude's own file reading plus `unzip`/`sed`/`awk`. The output is meant for LLMs and text tools: keep **structure and every bit of content**, not visual layout.

## Workflow

1. **Find the file.** Uploaded files usually sit in `/mnt/user-data/uploads/` (claude.ai) or are given as a path. If several files were uploaded and the user didn't say which, convert all of them, one `.md` each.
2. **Pick the method** from the table below by extension (run `file <path>` if the extension is missing or looks wrong).
3. **Write the Markdown** following the output rules.
4. **Save** as `<original-name>.md` (e.g. `report.pdf` → `report.md`) where the user asked; otherwise in `/mnt/user-data/outputs/` if that folder exists, otherwise next to the input file. For long documents, write the file in parts (first part with the Write tool, then append) rather than holding everything in one message.
5. **Deliver.** If a file-sharing tool exists (`present_files`, `SendUserFile`), send the `.md` with it. Reply with one or two lines: what was converted, and anything that could not be (scanned pages, charts, password protection). Don't paste the whole Markdown into the chat — the file is the deliverable.

## Method per format

`scripts/extract.sh` is in this skill's folder. Run it as `sh <skill-dir>/scripts/extract.sh <file>`; it prints Markdown-ish text you then clean up.

| Format | How |
|---|---|
| **PDF** | Read the file with the Read tool (use `pages`, at most 20 per call, for long PDFs). You see the real page, so rebuild headings, lists and tables from the layout. For scanned pages, transcribe the text you see (this is the OCR step). |
| **.docx** | `extract.sh`. Map `[style=Title]`/`[style=Heading1..6]` to `#`..`######`, `[list lvl=N]` to a list item indented 2 spaces per level (numbered if the original text looks numbered), `[link rIdN: text]` to `[text](url)` using the id list at the top, `[table]` rows to a GFM table with a `| --- |` separator after the first row. Footnotes/endnotes go at the end. |
| **.pptx** | `extract.sh`. Each `@@ slide N` becomes `<!-- Slide number: N -->`, the `[TITLE]` line becomes `# title`, `[lvl=N]` lines become nested bullets, `[image alt: …]` becomes `![…](image)`, `[notes]` become a `### Notes:` section under that slide. |
| **.xlsx** | `extract.sh` already prints a `## SheetName` + table per sheet; use it as is (an empty header cell just means that column has no title in the sheet). Numbers like `45291` in a date column are Excel dates (days since 1899-12-30) — convert them to `YYYY-MM-DD`. |
| **CSV / TSV** | Read it; turn it into one GFM table, first row as header. Respect quoted fields that contain commas. |
| **JSON / XML** | Keep it verbatim in a fenced block (```` ```json ```` / ```` ```xml ````) — reformatting risks changing data. |
| **HTML** | `extract.sh` (drops scripts, styles, nav). Then remove leftover boilerplate like cookie banners and footers, keep the main content. |
| **EPUB** | `extract.sh` prints title, author and chapters in reading order. Start the file with `# Title` and `*by Author*`, then shift every chapter heading down one level (`#` → `##`) so the book title stays the only `#`. |
| **Images** (png/jpg/gif/webp) | Read the image. Write `# <file name>`, then a `## Description` of what it shows, then `## Text` with all visible text transcribed exactly. If `exiftool` or `mdls` exists, add key metadata (date, camera, size) at the top. |
| **ZIP** | `unzip -o <file> -d <temp dir>`, convert every supported file inside with the methods above, and join them in one `.md`, each under `## File: <path inside zip>`. Shift each inner file's headings down two levels (`#` → `###`) so they nest under their `## File:` heading. |
| **.txt / .md** | Copy the text; only add structure if it is clearly there (e.g. lines in ALL CAPS used as headings). |
| **.doc / .ppt / .xls (old binary)**, Outlook `.msg`, audio, video | No reliable no-Python path. If `soffice` is installed, `soffice --headless --convert-to docx|pptx|xlsx <file>` first, then use the row above. Otherwise tell the user and ask them to re-save as the modern format (or PDF). |

If `unzip` is missing, `bsdtar -xOf <file> <inner path>` prints a file from the archive the same way.

## Output rules

- **Faithful, not summarized.** Every sentence, number and table cell from the source should be in the output. Don't fix typos, translate, or "improve" wording — people use this to feed exact content to other tools.
- **Structure as Markdown:** `#` headings in the source's hierarchy (one `#` title at the top when the document has one), `-` / `1.` lists, GFM tables, `[text](url)` links, `**bold**` only where the source clearly emphasizes. Escape `|` inside table cells as `\|`.
- **Drop layout noise:** page numbers, repeated running headers/footers, hyphenation at line ends, hard line breaks in the middle of sentences.
- **Mark what you can't convert** with an HTML comment so nothing disappears silently, e.g. `<!-- chart: bar chart of revenue by quarter, values not readable -->` or `<!-- page 7: blank -->`.
- **Page/slide markers** as comments (`<!-- page 3 -->`, `<!-- Slide number: 3 -->`) only for PDFs and decks, where position matters for citing back.
- No commentary inside the file ("Here is your document…"). The file starts with the document itself.

## Example

Input `plan.docx`, `extract.sh` prints:

```
@@ hyperlink ids (rId -> url)
rId5 -> https://example.com/docs
@@ document
[style=Title] Project Plan
[style=Heading1] Goals
See the [link rId5: docs site] for details.
[style=ListParagraph] [list lvl=0] Ship v1
[style=ListParagraph] [list lvl=1] Beta in March
[table]
| Item | Cost |
| Servers | $500 |
[/table]
```

Output `plan.md`:

```markdown
# Project Plan

## Goals

See the [docs site](https://example.com/docs) for details.

- Ship v1
  - Beta in March

| Item | Cost |
| --- | --- |
| Servers | $500 |
```

(The Title style becomes `#`, so `Heading1` shifts down to `##`.)
