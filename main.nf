#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ─────────────────────────────────────────────
//  Parameter defaults
// ─────────────────────────────────────────────
params.samplesheet = params.samplesheet ?: "${workflow.projectDir}/data/samplesheet.tsv"
params.outdir      = params.outdir      ?: "${workflow.projectDir}/results"
params.script_dir  = params.script_dir  ?: "${workflow.projectDir}/bins"

// Target regions BED (protein-coding gene bodies, 200 bp bins)
params.bins_bed    = params.bins_bed    ?: "${workflow.projectDir}/data/MANE_bins_unique_exon.bed"

// ─────────────────────────────────────────────
//  Module imports
// ─────────────────────────────────────────────
include { EXTRACT_VARIANTS   } from './modules/extract_variants'
include { MOSDEPTH_PERBASE   } from './modules/mosdepth_perbase'
include { PERBASE_TO_COVERAGE } from './modules/perbase_to_coverage'

// ─────────────────────────────────────────────
//  Workflow
// ─────────────────────────────────────────────
workflow {

    if (!file(params.samplesheet).exists()) {
        error "Samplesheet not found: ${params.samplesheet}"
    }
    if (!file(params.bins_bed).exists()) {
        error "BED file not found: ${params.bins_bed}"
    }

    ch_bins_bed = Channel.value(file(params.bins_bed, checkIfExists: true))

    // ── Parse samplesheet ─────────────────────────────────────────────────────
    ch_samples = Channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            def meta      = [sample: row.sample, assay: row.assay]
            def vcf       = file(row.vcf,       checkIfExists: true)
            def bam       = file(row.bam,       checkIfExists: true)
            def bam_index = file(row.bam_index, checkIfExists: true)
            [ meta, vcf, bam, bam_index ]
        }

    // ── Step 1: Extract variants from raw VCF ────────────────────────────────
    ch_vcf_only        = ch_samples.map { meta, vcf, bam, bam_index -> [ meta, vcf ] }
    ch_variants_script = Channel.value(file("${params.script_dir}/db_vep_vcf_to_variants_all.py"))
    EXTRACT_VARIANTS(ch_vcf_only, ch_variants_script)

    // ── Step 2: Per-base depth over target regions (parallel with step 1) ────
    ch_bam_input = ch_samples.map { meta, vcf, bam, bam_index -> [ meta, bam, bam_index ] }
    MOSDEPTH_PERBASE(ch_bam_input, ch_bins_bed)

    // ── Step 3: Intersect to BED intervals and format for BigQuery ───────────
    PERBASE_TO_COVERAGE(MOSDEPTH_PERBASE.out.per_base_bed, ch_bins_bed)
}
