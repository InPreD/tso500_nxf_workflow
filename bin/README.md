# Script `generate_samplesheet.py`


The script generates sample sheet for TSO500 LocalApp analysis to the standard output.

## Dependencies

python3, pandas


## Description 

Suggestion for investigator name format: Name (InPreD_node)

### File format of `input_info_file`

The file is expected to be a table with columns separated by a `separator` (input parameter for `generate_samplesheet.py`).
The rows starting with character `#` are ignored (considered to be comments).
The first uncommented row is considered to be a header containing column names.

Required columns in the file are: `sample_id`, `molecule`, `run_id`, `barcode`, `index` (at least one of columns `barcode` and `index` has to be non-empty).

| column | description |
|---|---|
|`sample_id`| - sample_id|
|`molecule` | - DNA/RNA  | 
| `run_id`  | - id of sequencing run in which the sample was sequenced |
| `barcode` | - `Index_ID` from one of the `../data/TSO500*_dual_*.tsv` files or `I7_Index_ID` from the `../data/TSO500*simple*.tsv` file. The index id should correspond to the indexes used for sequencing this particular sample. | 
| `index`   | - sequence of the forward index. |


## Usage

### Template for nextseq, dual indexes, index_length 8 (Ahus, stOlav)

```
python3 generate_samplesheet.py \
	--run-id <run_id> \
	--index-type dual \
	--index-length 8 \
	--investigator-name <name_(inpred_node)> \
	--experiment-name "InPreD" \
	--input-info-file <input_info_file> \
	--separator <field_separator_in_info_file> \
	--read-length-1 101 \
	--read-length-2 101 \
	--adapter-read-1 "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA" \
	--adapter-read-2 "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT" \
	--adapter-behavior "trim" \
	--minimum-trimmed-read-length 35 \
	--mask-short-reads 35 \
	--override-cycles "U7N1Y93;I8;I8;U7N1Y93" \
	--samplesheet-version "v1"
```

### Template for novaseq, dual indexes, index_length 10 (OUS, HUS)

```
python3 generate_samplesheet.py \
	--run-id <run_id> \
	--index-type dual \
	--index-length 10 \
	--investigator-name <name_(inpred_node)> \
	--experiment-name "InPreD" \
	--input-info-file <input_info_file> \
	--separator <field_separator_in_info_file> \
	--read-length-1 101 \
	--read-length-2 101 \
	--adapter-read-1 "CTGTCTCTTATACACATCTCCGAGCCCACGAGAC" \
	--adapter-read-2 "CTGTCTCTTATACACATCTGACGCTGCCGACGA" \
	--adapter-behavior "trim" \
	--minimum-trimmed-read-length 35 \
	--mask-short-reads 35 \
	--override-cycles "U7N1Y93;I10;I10;U7N1Y93"
	--samplesheet-version "v1"
```

### Template for legacy nextseq, simple indexes, index_length 8 (OUS)

```
python3 generate_samplesheet.py \
	--run-id <run_id> \
	--index-type simple \
	--index-length 8 \
	--investigator-name "name_(inpred_node)" \
	--experiment-name "InPreD" \
	--input-info-file <input_info_file> \
	--separator <field_separator_in_info_file> \
	--read-length-1 101 \
	--read-length-2 101 \
	--adapter-read-1 "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA" \
	--adapter-read-2 "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT" \
	--adapter-behavior "trim" \
	--minimum-trimmed-read-length 35 \
	--mask-short-reads 22 \
	--override-cycles "U7N1Y93;I8;I8;U7N1Y93" \
	--samplesheet-version "v1"
```

### Real world example: OUS legacy nextseq, artificial samples (incl AcroMetrix)

```
python3 generate_samplesheet.py \
	--run-id <run_id> \
	--index-type simple \
	--index-length 8 \
	--investigator-name "" \
	--experiment-name "OUS pathology test run" \
	--input-info-file ../assets/infoFiles/test_info_file_<run_id>.csv \
	--separator ";" \
	--read-length-1 101 \
	--read-length-2 101 \
	--adapter-read-1 "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA" \
	--adapter-read-2 "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT" \
	--adapter-behavior "trim" \
	--minimum-trimmed-read-length 35 \
	--mask-short-reads 22 \
	--override-cycles "U7N1Y93;I8;I8;U7N1Y93" \
	--samplesheet-version "v1" \
	> ../assets/SampleSheet_<run_id>.csv
```
