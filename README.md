# TSO500 nextflow workflow

## Introduction :speech_balloon:

**inpred/tso500_nxf_workflow** is a bioinformatics analysis pipeline for processing TSO500 panel data.

## Dependencies :exclamation:

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A522.04.5-green?color=24ae64)](https://www.nextflow.io/)

[![Nf-core](https://img.shields.io/badge/nf--core-%E2%89%A52.7.2-green?color=24ab63)](https://www.nf-co.re/)

[![Docker](https://img.shields.io/badge/docker-%E2%89%A520.10.19-blue?logo=docker&color=0db7ed)](https://www.docker.com/)

## Usage :rocket:

### Input

#### Nxf samplesheet

### Run

```bash
$ nextflow run https://github.com/InPreD/tso500_nxf_workflow -r main -profile docker --input <nxf samplesheet> --outdir output --tso500_resource_folder <path to resources>
```

### Output
