#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ─────────────────────────────────────────────
//  Parameter defaults
// ─────────────────────────────────────────────
params.samplesheet          = params.samplesheet ?: "${workflow.projectDir}/data/samplesheet.tsv"
params.outdir               = params.outdir ?: params.outdir
params.mosdepth_thresholds  = "10,20,30"
params.script_dir           = params.script_dir ?: "${workflow.projectDir}/bins"

// ── Shared reference / annotation resources ───────────────────────────────────
params.bins_bed             = params.bins_bed ?: "${workflow.projectDir}/data/MANE_bins_unique_exon.bed"

// ─────────────────────────────────────────────
//  Module imports
// ─────────────────────────────────────────────
include { EXTRACT_VARIANTS    } from './modules/extract_variants'
include { MOSDEPTH_THRESHOLDS } from './modules/mosdepth_thresholds'
include { CONVERT_THRESHOLDS  } from './modules/thresholds_to_coverage'

// ─────────────────────────────────────────────
//  Helper: assert a required param is set
// ─────────────────────────────────────────────
//def requireParam(String name) {
//    if (params[name] == null) {
//        error "Required parameter '--${name}' is not set. See README for usage."
//    }
//    return file(params[name], checkIfExists: true)
//}

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

    // ── Step 2: BAM coverage (runs in parallel with variant extraction) ──────
    ch_bam_input = ch_samples.map { meta, vcf, bam, bam_index -> [ meta, bam, bam_index ] }

    MOSDEPTH_THRESHOLDS(ch_bam_input, ch_bins_bed)

    // ── Step 4: Convert mosdepth thresholds to coverage TSV ──────────────────
    CONVERT_THRESHOLDS(MOSDEPTH_THRESHOLDS.out.per_base_bed)
}
