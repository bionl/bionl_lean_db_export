# bionl_leab_db_export

A Nextflow DSL2 pipeline that annotates consensus VCFs with VEP, then generates database-ready **variants** and **coverage** tables per sample.

---

## Overview

```
samplesheet.tsv
      │
      ├─► VEP_ANNOTATE          ──►  results/{sample}/vcf/{sample}.vep.vcf
      │       (raw VCF → VEP-annotated VCF)
      │         │
      │         └─► EXTRACT_VARIANTS  ──►  results/variants/{sample}_{assay}_variants.tsv
      │
      └─► MOSDEPTH_THRESHOLDS   ──►  CONVERT_THRESHOLDS
              (BAM → thresholds.bed.gz)        │
                                               └──►  results/coverage/{sample}_{assay}_coverage.tsv
```

The BAM coverage branch runs **in parallel** with the VEP/extraction branch.

---

## Requirements

| Tool       | Version  | Purpose                             |
|------------|----------|-------------------------------------|
| Nextflow   | ≥ 23.04  | Pipeline orchestration              |
| VEP        | ≥ 114    | Variant annotation                  |
| Python     | ≥ 3.11   | Variant + coverage scripts          |
| mosdepth   | ≥ 0.3.6  | Per-bin coverage thresholds         |

---

## Repository structure

```
repo/
├── main.nf                          # Pipeline entry point
├── nextflow.config                  # Parameters, profiles, resource labels
├── data/
│   ├── samplesheet.tsv              
│   ├── MANE_uniques_bins.bed              
├── modules/
│   ├── vep_annotate.nf              # VEP_ANNOTATE process
│   ├── extract_variants.nf          # EXTRACT_VARIANTS process
│   ├── mosdepth_thresholds.nf       # MOSDEPTH_THRESHOLDS process
│   └── thresholds_to_coverage.nf    # CONVERT_THRESHOLDS process
└── bins/
    ├── db_vep_vcf_to_variants_all.py    # VEP VCF → variants TSV
    └── db_depth_to_coverage_new.py  # mosdepth BED → coverage TSV
```

---

## Samplesheet format

Tab-separated, one row per sample. **No VCF index required** — VEP handles both `.vcf` and `.vcf.gz` input directly.

```tsv
sample    assay  vcf                                  bam                   bam_index
Patient_1 WES    /data/Patient_1/consensus.vcf.gz     /data/Patient_1/s.bam /data/Patient_1/s.bam.bai
```

| Column      | Description                                                     |
|-------------|-----------------------------------------------------------------|
| `sample`    | Unique sample identifier (used in output filenames)             |
| `assay`     | Assay type, e.g. `WES` or `WGS`                                |
| `vcf`       | Absolute path to input consensus VCF (`.vcf` or `.vcf.gz`)     |
| `bam`       | Absolute path to BAM file                                       |
| `bam_index` | Corresponding `.bai` index                                      |

---

## Parameters

### Core

| Parameter               | Default             | Description                           |
|-------------------------|---------------------|---------------------------------------|
| `--samplesheet`         | `samplesheet.tsv`   | Path to sample manifest               |
| `--outdir`              | `results`           | Output directory                      |
| `--threads`             | `4`                 | CPU threads (VEP `--fork`, mosdepth)  |
| `--mosdepth_thresholds` | `10,20,30`          | Coverage depth thresholds             |
| `--bins_bed`            | `MANE_bins_unique.bed` | MANE genomic bins BED              |

### VEP resources (all required)

| Parameter                   | Description                                      |
|-----------------------------|--------------------------------------------------|
| `--vep_cache`               | Path to VEP offline cache directory              |
| `--vep_fasta`               | GRCh38 reference FASTA                           |
| `--vep_fasta_fai`           | `.fai` index for reference FASTA                 |
| `--vep_plugins`             | Path to VEP plugins directory                    |
| `--revel_vcf`               | REVEL scores VCF                                 |
| `--revel_vcf_tbi`           | REVEL VCF index                                  |
| `--alpha_missense_vcf`      | AlphaMissense VCF                                |
| `--alpha_missense_vcf_tbi`  | AlphaMissense VCF index                          |
| `--clinvar_vcf`             | ClinVar VCF                                      |
| `--clinvar_vcf_tbi`         | ClinVar VCF index                                |
| `--spliceai_snv_vcf`        | SpliceAI SNV scores VCF                          |
| `--spliceai_snv_vcf_tbi`    | SpliceAI SNV VCF index                           |
| `--spliceai_indel_vcf`      | SpliceAI indel scores VCF                        |
| `--spliceai_indel_vcf_tbi`  | SpliceAI indel VCF index                         |
| `--bayesdel_vcf`            | BayesDel scores VCF                              |
| `--bayesdel_vcf_tbi`        | BayesDel VCF index                               |


---

## Usage

### Minimal run (local)

```bash
nextflow run main.nf \
  --samplesheet samplesheet.tsv \
  --bins_bed    /ref/MANE_bins_unique.bed \
  --vep_cache   /ref/vep_cache \
  --vep_fasta   gs:GRCh38.fa \
  --vep_fasta_fai /ref/GRCh38.fa.fai \
  --vep_plugins /ref/vep_plugins \
  --revel_vcf   /ref/revel_scores.vcf.gz \
  --revel_vcf_tbi /ref/revel_scores.vcf.gz.tbi \
  --alpha_missense_vcf /ref/AlphaMissense_hg38.vcf.gz \
  --alpha_missense_vcf_tbi /ref/AlphaMissense_hg38.vcf.gz.tbi \
  --clinvar_vcf /ref/clinvar.vcf.gz \
  --clinvar_vcf_tbi /ref/clinvar.vcf.gz.tbi \
  --spliceai_snv_vcf /ref/spliceai_scores.raw.snv.hg38.vcf.gz \
  --spliceai_snv_vcf_tbi /ref/spliceai_scores.raw.snv.hg38.vcf.gz.tbi \
  --spliceai_indel_vcf /ref/spliceai_scores.raw.indel.hg38.vcf.gz \
  --spliceai_indel_vcf_tbi /ref/spliceai_scores.raw.indel.hg38.vcf.gz.tbi \
  --bayesdel_vcf /ref/BayesDel_170824_addAF.vcf.gz \
  --bayesdel_vcf_tbi /ref/BayesDel_170824_addAF.vcf.gz.tbi \
  --outdir results
```

## Outputs

```
results/
├── {sample}/
│   └── vcf/
│       └── {sample}.vep.vcf                  ← VEP-annotated VCF
├── variants/
│   ├── Patient_1_WES_variants.tsv
│   └── Patient_2_WES_variants.tsv
├── coverage/
│   ├── Patient_1_WES_coverage.tsv
│   └── Patient_2_WES_coverage.tsv
├── mosdepth/
│   └── {sample}/
│       ├── {sample}.thresholds.bed.gz
│       └── {sample}.mosdepth.summary.txt
└── pipeline_info/
    ├── execution_report.html
    ├── execution_timeline.html
    ├── execution_trace.txt
    └── pipeline_dag.html
```

### Variants TSV columns

| Column             | Description                               |
|--------------------|-------------------------------------------|
| `sample_id`        | Sample identifier                         |
| `assay_type`       | Assay type                                |
| `gene_symbol`      | HGNC gene symbol (VEP CSQ)                |
| `mane_select`      | MANE SELECT transcript ID                 |
| `chrom`            | Chromosome                                |
| `pos`              | Position (1-based)                        |
| `ref`              | Reference allele                          |
| `alt`              | Alternate allele                          |
| `variant_id`       | `chrom:pos:ref:alt`                       |
| `gt`               | Genotype string (e.g. `0/1`)              |
| `alt_allele_count` | Number of alt allele copies               |
| `is_hom_alt`       | 1 if homozygous alt, 0 otherwise          |
| `hgvsc`            | HGVSc notation (VEP)                      |
| `variant_impact`   | VEP impact (HIGH / MODERATE / LOW / ...)  |
| `clinvar_clnsig`   | ClinVar clinical significance             |
| `clinvar_alleleid` | ClinVar allele ID                         |

### Coverage TSV columns

| Column        | Description                                      |
|---------------|--------------------------------------------------|
| `chrom`       | Chromosome                                       |
| `start`       | Bin start (0-based, BED convention)              |
| `end`         | Bin end                                          |
| `covered_20x` | Fraction of bases in bin covered at ≥ 20×        |

---

## Notes

- **`meta.sample`** is used as the consistent key across all four modules, matching VEP's original convention.
- All annotation reference files are passed as **`Channel.value()`** — they are broadcast to every sample without being staged redundantly or consumed.
- The BAM coverage branch (`MOSDEPTH_THRESHOLDS` → `CONVERT_THRESHOLDS`) runs **in parallel** with the VEP branch and does not wait for annotation to complete.
- Add container directives in `nextflow.config` under `withName: 'VEP_ANNOTATE'` etc. to enable Docker / Singularity execution.
- The pipeline is **resume-friendly** (`-resume`): cached task results are reused across runs as long as inputs and scripts are unchanged.
