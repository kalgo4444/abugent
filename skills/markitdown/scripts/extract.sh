#!/bin/sh
# extract.sh FILE
# Dump the readable content of .docx / .pptx / .xlsx / .epub / .html files
# as Markdown-ish text, using only unzip, sed, awk, tr (no Python).
# Claude cleans this up into the final .md file.
set -eu

f=${1:?usage: extract.sh FILE}
[ -f "$f" ] || { echo "not a file: $f" >&2; exit 1; }

# --- helpers ---------------------------------------------------------------
flat()     { tr '\r\n' '  '; }                                  # one line, so regexes can't miss across newlines
nl()       { awk '{gsub(/@@NL@@/,"\n"); print}'; }              # turn placeholder into real newlines
ents()     { sed -E 's#&lt;#<#g; s#&gt;#>#g; s#&quot;#"#g; s#&apos;#'"'"'#g; s#&nbsp;# #g; s#&\#160;# #g; s#&amp;#\&#g'; }
nonblank() { grep -v '^[[:space:]]*$' || true; }
part()     { unzip -p "$f" "$1" 2>/dev/null || true; }          # print one file from the zip, or nothing
has()      { unzip -Z1 "$f" 2>/dev/null | grep -qx "$1"; }

# "Id -> Target" for every relationship in a .rels file (attribute order safe)
rels() {
  part "$1" | flat | sed -E 's#<Relationship #@@NL@@&#g' | nl | awk '
    match($0, / Id="[^"]*"/)    { id = substr($0, RSTART+5, RLENGTH-6)
      if (match($0, / Target="[^"]*"/)) print id " -> " substr($0, RSTART+9, RLENGTH-10) }'
}

# HTML/XHTML -> Markdown-ish text (used for .html and .epub chapters)
html_md() {
  flat | sed -E 's#<#@@NL@@<#g' | nl | awk '
    function out(s) { printf "%s", s }
    BEGIN { skip = 0; nhref = 0 }
    {
      line = $0
      if (line !~ /^</) { if (!skip) out(line); next }
      tag = line; sub(/>.*/, ">", tag); text = line; sub(/^[^>]*>/, "", text)
      name = tolower(tag); sub(/^<\/?/, "", name); sub(/[ >\/].*/, "", name)
      close_ = (tag ~ /^<\//)
      if (name ~ /^(script|style|head|nav|noscript|svg|template)$/) { skip += close_ ? -1 : 1; if (skip < 0) skip = 0; next }
      if (skip) next
      if (name ~ /^h[1-6]$/) { if (!close_) { out("\n\n"); for (i = 0; i < substr(name,2)+0; i++) out("#"); out(" ") } else out("\n\n") }
      else if (name == "table") { out("\n\n"); rows = 0 }
      else if (name ~ /^(p|div|section|article|header|footer|blockquote|dl)$/) out("\n\n")
      else if (name == "br") out("\n")
      else if (name == "tr" && !close_) { out("\n|"); cells = 0 }
      else if (name == "tr" && close_) { rows++; if (rows == 1) { out("\n|"); for (i = 0; i < cells; i++) out(" --- |") } }
      else if (name ~ /^(ul|ol)$/) { out("\n"); if (!close_) { kind[++depth] = name; num[depth] = 0 } else if (depth > 0) depth-- }
      else if (name == "li" && !close_) { out("\n"); for (i = 1; i < depth; i++) out("  ")
        if (kind[depth] == "ol") out(++num[depth] ". "); else out("- ") }
      else if (name ~ /^(td|th)$/) { if (!close_) { out(" "); cells++ } else out(" |") }
      else if (name ~ /^(strong|b)$/) out("**")
      else if (name ~ /^(em|i)$/) out("*")
      else if (name == "code") out("`")
      else if (name == "pre") out("\n```\n")
      else if (name == "a") {
        if (!close_) { h = ""; if (match(tag, /href="[^"]*"/)) h = substr(tag, RSTART+6, RLENGTH-7); href[++nhref] = h; out("[") }
        else if (nhref > 0) { out("](" href[nhref--] ")") }
      }
      else if (name == "img") { a = ""; s = ""
        if (match(tag, /alt="[^"]*"/)) a = substr(tag, RSTART+5, RLENGTH-6)
        if (match(tag, /src="[^"]*"/)) s = substr(tag, RSTART+5, RLENGTH-6)
        out("![" a "](" s ")") }
      out(text)
    }
    END { print "" }' | ents | sed -E 's/[[:space:]]+$//' | cat -s
}

# --- DOCX ------------------------------------------------------------------
docx() {
  echo "@@ hyperlink ids (rId -> url)"
  rels word/_rels/document.xml.rels | grep -E ' -> (https?|mailto):' || true
  for p in document footnotes endnotes; do
    has "word/$p.xml" || continue
    echo; echo "@@ $p"
    part "word/$p.xml" | flat | sed -E \
      -e 's#<w:pStyle w:val="([^"]*)"/>#[style=\1] #g' \
      -e 's#<w:ilvl w:val="([0-9]+)"/>#[list lvl=\1] #g' \
      -e 's#<w:hyperlink [^>]*r:id="([^"]*)"[^>]*>#[link \1: #g' -e 's#</w:hyperlink>#]#g' \
      -e 's#<wp:docPr [^>]*descr="([^"]*)"[^>]*>#[image alt: \1]#g' \
      -e 's#<w:tbl>#@@NL@@[table]#g' -e 's#</w:tbl>#@@NL@@[/table]@@NL@@#g' \
      -e 's#<w:tr( [^>]*)?>#@@NL@@| #g' -e 's#</w:p></w:tc># | #g' \
      -e 's#<w:tab/># #g' -e 's#<w:br/>#@@NL@@#g' -e 's#</w:p>#@@NL@@#g' \
      -e 's#<[^>]+>##g' | ents | nl | sed -E 's/[[:space:]]+$//' | nonblank
  done
}

# --- PPTX ------------------------------------------------------------------
pptx() {
  # slide order comes from presentation.xml; fall back to file-name order
  slides=""
  if has ppt/presentation.xml; then
    prels=$(rels ppt/_rels/presentation.xml.rels)
    for id in $(part ppt/presentation.xml | flat | grep -oE '<p:sldId [^>]*>' | grep -oE 'r:id="[^"]*"' | cut -d'"' -f2); do
      t=$(echo "$prels" | awk -v id="$id" '$1 == id { print $3 }')
      [ -n "$t" ] && slides="$slides ppt/${t#/ppt/}"
    done
  fi
  [ -n "$slides" ] || slides=$(unzip -Z1 "$f" | grep -E '^ppt/slides/slide[0-9]+\.xml$' | sort -V)
  n=0
  for s in $slides; do
    n=$((n + 1)); echo; echo "@@ slide $n"
    part "$s" | flat | sed -E \
      -e 's#<p:ph type="(ctrTitle|title)"[^>]*/>#[TITLE] #g' \
      -e 's#<a:pPr [^>]*lvl="([0-9])"[^>]*/?>#[lvl=\1] #g' \
      -e 's#<p:cNvPr [^>]*descr="([^"]*)"[^>]*>#[image alt: \1]@@NL@@#g' \
      -e 's#<a:tbl>#@@NL@@[table]#g' -e 's#</a:tbl>#@@NL@@[/table]@@NL@@#g' \
      -e 's#<a:tr( [^>]*)?>#@@NL@@| #g' -e 's#</a:p></a:txBody></a:tc># | #g' \
      -e 's#</a:p>#@@NL@@#g' -e 's#<a:br/>#@@NL@@#g' -e 's#<[^>]+>##g' | ents | nl | nonblank
    # speaker notes are linked from the slide's own .rels file
    sr="$(dirname "$s")/_rels/$(basename "$s").rels"
    note=$(rels "$sr" | awk '$3 ~ /notesSlide/ { print $3 }' | head -1)
    b=$(basename "$s"); guess="notesSlide${b#slide}"
    [ -n "$note" ] || { has "ppt/notesSlides/$guess" && note="$guess"; } || true
    if [ -n "$note" ]; then
      echo "[notes]"
      part "ppt/notesSlides/$(basename "$note")" | flat | sed -E 's#</a:p>#@@NL@@#g; s#<[^>]+>##g' | ents | nl | nonblank | grep -vxE '[0-9]+' || true
    fi
  done
}

# --- XLSX: prints a finished Markdown table per sheet ------------------------
xlsx() {
  tmp=$(mktemp)
  # shared strings, one per line (index = line number - 1); in-cell newlines become <br>
  part xl/sharedStrings.xml | tr '\r' ' ' | awk 'BEGIN{ORS="<br>"}{print}' | sed -E 's#(<br>)+$##; s#</si>#@@NL@@#g; s#<rPh.*</rPh>##g; s#<[^b][^>]*>##g; s#</[^b][^>]*>##g' | nl > "$tmp"
  wrels=$(rels xl/_rels/workbook.xml.rels)
  part xl/workbook.xml | flat | grep -oE '<sheet [^>]*>' | while read -r sh; do
    name=$(echo "$sh" | grep -oE 'name="[^"]*"' | cut -d'"' -f2 | ents)
    id=$(echo "$sh" | grep -oE 'r:id="[^"]*"' | cut -d'"' -f2)
    t=$(echo "$wrels" | awk -v id="$id" '$1 == id { print $3 }')
    case "$t" in /*) t=${t#/} ;; *) t="xl/$t" ;; esac
    echo; echo "## $name"; echo
    part "$t" | flat | sed -E 's#<c #@@NL@@<c #g; s#</row>#@@NL@@@@ROW@@@@NL@@#g; s#</sheetData>.*##' | nl | awk -v SST="$tmp" '
      BEGIN { n = 0; while ((getline l < SST) > 0) sst[n++] = l; r = 0; maxc = 0; seen = 0 }
      function col(ref,   i, ch, v) { v = 0
        for (i = 1; i <= length(ref); i++) { ch = substr(ref, i, 1); if (ch ~ /[A-Z]/) v = v * 26 + index("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ch); else break }
        return v }
      function attr(a) { return match($0, " " a "=\"[^\"]*\"") ? substr($0, RSTART + length(a) + 3, RLENGTH - length(a) - 4) : "" }
      /^@@ROW@@/ { if (seen) r++; seen = 0; next }
      /^<c / {
        t = attr("t"); v = ""
        if (match($0, /<v>[^<]*<\/v>/)) v = substr($0, RSTART + 3, RLENGTH - 7)
        if (t == "s") v = sst[v + 0]
        else if (t == "inlineStr") { v = $0; gsub(/<[^>]*>/, "", v) }
        else if (t == "b") v = (v == "1") ? "TRUE" : "FALSE"
        c = col(attr("r")); if (c == 0) next
        if (v != "") { cell[r, c] = v; seen = 1; if (c > maxc) maxc = c; last = r }
      }
      END {
        if (maxc == 0) { print "(empty sheet)"; exit }
        for (i = 0; i <= last; i++) {
          line = "|"
          for (j = 1; j <= maxc; j++) { v = cell[i, j]; gsub(/\|/, "\\|", v); line = line " " v " |" }
          print line
          if (i == 0) { sep = "|"; for (j = 1; j <= maxc; j++) sep = sep " --- |"; print sep }
        }
      }' | ents
  done
  rm -f "$tmp"
}

# --- EPUB ------------------------------------------------------------------
epub() {
  opf=$(part META-INF/container.xml | flat | grep -oE 'full-path="[^"]*"' | head -1 | cut -d'"' -f2)
  dir=$(dirname "$opf"); [ "$dir" = "." ] && dir="" || dir="$dir/"
  meta=$(part "$opf" | flat)
  echo "@@ title: $(echo "$meta" | grep -oE '<dc:title[^>]*>[^<]*' | head -1 | sed 's/.*>//' | ents)"
  echo "@@ author: $(echo "$meta" | grep -oE '<dc:creator[^>]*>[^<]*' | sed 's/.*>//' | ents | paste -sd ',' -)"
  for idref in $(echo "$meta" | grep -oE '<itemref [^>]*>' | grep -oE 'idref="[^"]*"' | cut -d'"' -f2); do
    href=$(echo "$meta" | grep -oE '<item [^>]*>' | grep "id=\"$idref\"" | grep -oE 'href="[^"]*"' | cut -d'"' -f2)
    [ -n "$href" ] || continue
    echo; echo "@@ chapter: $href"
    part "$dir$href" | html_md
  done
}

case "$(echo "$f" | tr 'A-Z' 'a-z')" in
  *.docx|*.docm)          docx ;;
  *.pptx|*.pptm)          pptx ;;
  *.xlsx|*.xlsm)          xlsx ;;
  *.epub)                 epub ;;
  *.html|*.htm|*.xhtml)   html_md < "$f" ;;
  *) echo "extract.sh: unsupported type: $f" >&2; exit 2 ;;
esac
