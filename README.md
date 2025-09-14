# csv_data_utils
CSV data utilities - Some simple tools useful for working with very large CSV files prior to database ingestion

------------------------------------------------------

## check_firstcol_int.sh

### 1) Just check, print offenders (lines whose first column is not digits)
`./check_firstcol_int.sh mydata.csv`

### 2) Same, but truncate long lines at 120 chars
`./check_firstcol_int.sh -t 120 mydata.csv`

### 3) Use semicolon delimiter
`./check_firstcol_int.sh -d ';' mydata.csv`

### 4) Write a cleaned copy (bad lines removed)
`./check_firstcol_int.sh --remove -o mydata.cleaned.csv mydata.csv`

### 5) Clean in-place (replace original file)
`./check_firstcol_int.sh --inplace mydata.csv`

------------------------------------------------------

## csv_enforce_column_count.sh

### 1) Auto-detect required count from first 3 non-empty lines, just report offenders
`./csv_enforce_column_count.sh data.csv`

### 2) Specify column count explicitly and clean in-place
`./csv_enforce_column_count.sh --cols 10 --inplace data.csv`

### 3) Detect, but write a cleaned copy (valid lines only)
`./csv_enforce_column_count.sh -o data.cleaned.csv data.csv`

### 4) Use semicolon delimiter
`./csv_enforce_column_count.sh -d ';' data.csv`

### 5) Keep truly blank lines (do not count them as offenders)
`./csv_enforce_column_count.sh --keep-blank data.csv`

### 6) TAB-delimited input (bash-escaped tab)
`./csv_enforce_column_count.sh -d $'\t' data.tsv`
