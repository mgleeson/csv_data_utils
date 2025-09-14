#!/usr/bin/env bash
#######################################################################################
# check_firstcol_int.sh
# @author: Matt Gleeson <m@mattgleeson.net.au>
# @version: 20250829
# @description: A small, fast Bash script (awk-based) that scans a CSV and reports any
#   line whose first column isn’t strictly digits (0–9). It can also write a cleaned 
#   copy with the bad lines removed (or replace the file in-place)
#   Checks that the first column of every CSV row is an integer (digits only).
#   Report offending lines with line numbers (truncated if long),
#   and optionally remove them (write a cleaned file or do in-place replacement).
#######################################################################################

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_firstcol_int.sh [-d DELIM] [-t MAXLEN] [--remove] [-o OUTFILE] [--inplace] FILE.csv

Options:
  -d DELIM     Field delimiter (default: ",")
  -t MAXLEN    Truncate reported lines to this many characters (default: 200)
  --remove     Also write a "cleaned" file containing only valid rows
  -o OUTFILE   Path for cleaned file (implies --remove)
  --inplace    Replace the input file with the cleaned content (implies --remove)
  -h|--help    Show this help

Notes:
  * Lines are validated if the first field (trimmed) matches: ^[0-9]+$
  * Offending lines are printed to STDOUT as: "LINE <n>: <content>"
  * If --remove is set and no -o/--inplace given, writes "<input>.cleaned.csv"
  * This is a simple CSV splitter (no RFC-4180 quoting). See Python alternative below for strict CSV parsing.
USAGE
}

DELIM=","
MAXLEN=200
REMOVE=0
OUTFILE=""
INPLACE=0

# Basic long-option parsing
ARGS=()
while (( "$#" )); do
  case "${1:-}" in
    -d) DELIM="${2:-}"; shift 2 ;;
    -t) MAXLEN="${2:-}"; shift 2 ;;
    --remove) REMOVE=1; shift ;;
    -o) OUTFILE="${2:-}"; REMOVE=1; shift 2 ;;
    --inplace) INPLACE=1; REMOVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      ARGS+=("$1"); shift ;;
  esac
done

if [ "${#ARGS[@]}" -ne 1 ]; then
  echo "Error: exactly one input FILE is required." >&2
  usage
  exit 2
fi

FILE="${ARGS[0]}"
if [ ! -f "$FILE" ]; then
  echo "Error: file not found: $FILE" >&2
  exit 2
fi

# Determine output path if cleaning is requested
TMP_OUT=""
if [ "$REMOVE" -eq 1 ]; then
  if [ -n "$OUTFILE" ] && [ "$INPLACE" -eq 1 ]; then
    echo "Error: cannot use both -o OUTFILE and --inplace." >&2
    exit 2
  fi
  if [ "$INPLACE" -eq 1 ]; then
    # write to a temp neighbor, then mv over original
    TMP_OUT="${FILE}.tmp.cleaned.$$"
  else
    OUTFILE="${OUTFILE:-${FILE%.csv}.cleaned.csv}"
    TMP_OUT="$OUTFILE"
  fi
  # Ensure we can create the output file
  : > "$TMP_OUT"
fi

# LC_ALL=C for consistent regex/byte handling on huge files
LC_ALL=C awk -v FS="$DELIM" \
  -v maxlen="$MAXLEN" \
  -v do_remove="$REMOVE" \
  -v outpath="${TMP_OUT:-}" '
  function ltrim(s){ sub(/^[ \t\r\n]+/, "", s); return s }
  function rtrim(s){ sub(/[ \t\r\n]+$/, "", s); return s }
  function trim(s){ return rtrim(ltrim(s)) }
  function truncated(s, n){
    if (length(s) <= n) return s
    return substr(s, 1, n) "... [truncated]"
  }
  {
    raw = $0
    f1 = trim($1)
    if (f1 ~ /^[0-9]+$/) {
      if (do_remove) print raw >> outpath
      next
    } else {
      # Report to STDOUT with line number
      print "LINE " NR ": " truncated(raw, maxlen)
      if (do_remove) { /* do not write bad line to cleaned output */ }
    }
  }
' "$FILE"

# If in-place, atomically move the tmp over original
if [ "$REMOVE" -eq 1 ] && [ "$INPLACE" -eq 1 ]; then
  mv -- "$TMP_OUT" "$FILE"
fi
