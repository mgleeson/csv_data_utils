# csv_data_utils
CSV data utilities - Some simple tools useful for working with very large CSV files prior to database ingestion

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

