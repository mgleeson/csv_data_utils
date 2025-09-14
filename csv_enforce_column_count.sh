#!/usr/bin/env bash
#######################################################################################
# csv_enforce_column_count.sh`
# @author: Matt Gleeson <m@mattgleeson.net.au>
# @version: 20250829
# @description: Validate and clean a CSV by enforcing a fixed number of columns.
# @usage:
#     - If --cols N not provided, detect column count by checking the first
#       three non-empty lines; they must all have the same count.
#     - Print offending lines with line numbers (truncated if long).
#     - Optionally write a cleaned output (or replace in-place).
#     
#     Delimiter default: "," (pass -d ';' or -d $'\t' for TAB, etc.)
#######################################################################################

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  csv_enforce_column_count.sh [options] FILE.csv

Options:
  -d DELIM       Column delimiter (default: ",")
  -t MAXLEN      Truncate printed lines to this many chars (default: 200)
  --cols N       Required column count; overrides auto-detection
  --inplace      Replace the input file with cleaned content
  -o OUTFILE     Write cleaned output to OUTFILE (implies cleaning)
  --keep-blank   Keep completely blank lines (do not count toward detection;
                 retained during cleaning)
  -h|--help      Show this help

Behavior:
  * If --cols is not provided, the script inspects the first three NON-EMPTY lines.
    If all three have the same NF (column count), that count is used.
    If they differ, the script aborts and asks you to specify --cols N.
  * All lines whose column count != required count are printed to STDOUT as:
       LINE <n>: <content...possibly truncated>
  * If -o/--inplace is given, only valid rows are written to the output/target.

Exit code:
  0 if no offenders found
  1 if offenders were found
  2 on usage/config errors

Examples:
  # Just check (comma-delimited), auto-detect count from first 3 non-empty lines
  csv_enforce_column_count.sh data.csv

  # Use semicolon delimiter
  csv_enforce_column_count.sh -d ';' data.csv

  # Require exactly 12 columns and clean in-place
  csv_enforce_column_count.sh --cols 12 --inplace data.csv

  # Detect, then write cleaned copy
  csv_enforce_column_count.sh -o data.cleaned.csv data.csv

  # TAB-delimited (note: bash $'\t' quoting)
  csv_enforce_column_count.sh -d $'\t' file.tsv
USAGE
}

DELIM=","
MAXLEN=200
REQUIRED_COLS=""
OUTFILE=""
INPLACE=0
KEEP_BLANK=0

ARGS=()
while (( "$#" )); do
  case "${1:-}" in
    -d) DELIM="${2:-}"; shift 2 ;;
    -t) MAXLEN="${2:-}"; shift 2 ;;
    --cols) REQUIRED_COLS="${2:-}"; shift 2 ;;
    --inplace) INPLACE=1; shift ;;
    -o) OUTFILE="${2:-}"; shift 2 ;;
    --keep-blank) KEEP_BLANK=1; shift ;;
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

if [ -n "$OUTFILE" ] && [ "$INPLACE" -eq 1 ]; then
  echo "Error: cannot use both -o OUTFILE and --inplace." >&2
  exit 2
fi

# If not specified, determine REQUIRED_COLS from the first three NON-EMPTY lines
if [ -z "$REQUIRED_COLS" ]; then
  # Collect up to 3 NF values from non-empty lines
  mapfile -t COUNTS < <(
    LC_ALL=C awk -v FS="$DELIM" '
      NF>0 { print NF; c++; if (c==3) exit }
    ' "$FILE"
  )
  if ((${#COUNTS[@]}==0)); then
    echo "Error: could not detect column count (file has no non-empty lines). Specify --cols N." >&2
    exit 2
  fi
  # Check if all collected counts equal
  DET="${COUNTS[0]}"
  equal=1
  for v in "${COUNTS[@]}"; do
    if [ "$v" != "$DET" ]; then equal=0; break; fi
  done
  if [ $equal -eq 0 ]; then
    echo "Error: first three non-empty lines have unequal column counts: ${COUNTS[*]}" >&2
    echo "Please specify the required column count via --cols N." >&2
    exit 2
  fi
  REQUIRED_COLS="$DET"
fi

# If cleaning, decide output path
TMP_OUT=""
DO_CLEAN=0
if [ -n "$OUTFILE" ] || [ "$INPLACE" -eq 1 ]; then
  DO_CLEAN=1
  if [ "$INPLACE" -eq 1 ]; then
    TMP_OUT="${FILE}.tmp.cleaned.$$"
  else
    TMP_OUT="$OUTFILE"
  fi
  : > "$TMP_OUT"
fi

# Main pass: report offenders; optionally write only valid lines to output
LC_ALL=C awk -v FS="$DELIM" \
  -v req="$REQUIRED_COLS" \
  -v maxlen="$MAXLEN" \
  -v do_clean="$DO_CLEAN" \
  -v keep_blank="$KEEP_BLANK" \
  -v outpath="${TMP_OUT:-}" '
  function truncated(s, n){
    if (length(s) <= n) return s
    return substr(s, 1, n) "... [truncated]"
  }
  {
    raw=$0
    # Blank line handling
    if (NF==0) {
      if (keep_blank) {
        if (do_clean) print raw >> outpath
        next
      } else {
        # Treat as offender
        print "LINE " NR ": " truncated(raw, maxlen)
        next
      }
    }

    if (NF == req) {
      if (do_clean) print raw >> outpath
    } else {
      print "LINE " NR ": " truncated(raw, maxlen)
    }
  }
' "$FILE"

# If in-place cleaning requested, move temp over original
if [ "$DO_CLEAN" -eq 1 ] && [ "$INPLACE" -eq 1 ]; then
  mv -- "$TMP_OUT" "$FILE"
fi

# Exit with 1 if any offenders printed
# We can detect offenders by a re-run small check for speed-safety (or compute inside).
# Cheap re-check:
if ! LC_ALL=C awk -v FS="$DELIM" -v req="$REQUIRED_COLS" -v keep_blank="$KEEP_BLANK" '
  NF==0 { if (keep_blank) next; else { bad=1; next } }
  NF!=req { bad=1 }
  END { exit(bad?1:0) }
' "$FILE"
then
  exit 1
fi

exit 0
