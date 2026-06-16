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
include { VEP_ANNOTATE        } from './modules/vep_annotate'
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

    ch_bins_bed           = Channel.value(file(params.bins_bed,             checkIfExists: true))
    ch_vep_cache          = Channel.value(file(params.vep_cache,          checkIfExists: true))
    ch_vep_fasta          = Channel.value(file(params.vep_fasta,          checkIfExists: true))
    ch_vep_fasta_fai      = Channel.value(file(params.vep_fasta_fai,      checkIfExists: true))
    ch_vep_plugins        = Channel.value(file(params.vep_plugins))
    //ch_revel_vcf          = Channel.value(file(params.revel_vcf,          checkIfExists: true))
    //ch_revel_vcf_tbi      = Channel.value(file(params.revel_vcf_tbi,      checkIfExists: true))
    //ch_alpha_vcf          = Channel.value(file(params.alpha_missense_vcf, checkIfExists: true))
    //ch_alpha_vcf_tbi      = Channel.value(file(params.alpha_missense_vcf_tbi, checkIfExists: true))
    ch_clinvar_vcf        = Channel.value(file(params.clinvar_vcf,        checkIfExists: true))
    ch_clinvar_vcf_tbi    = Channel.value(file(params.clinvar_vcf_tbi,    checkIfExists: true))
    //ch_spliceai_snv       = Channel.value(file(params.spliceai_snv_vcf,   checkIfExists: true))
    //ch_spliceai_snv_tbi   = Channel.value(file(params.spliceai_snv_vcf_tbi, checkIfExists: true))
    //ch_spliceai_indel     = Channel.value(file(params.spliceai_indel_vcf, checkIfExists: true))
    //ch_spliceai_indel_tbi = Channel.value(file(params.spliceai_indel_vcf_tbi, checkIfExists: true))
    //ch_bayesdel_vcf       = Channel.value(file(params.bayesdel_vcf,       checkIfExists: true))
    //ch_bayesdel_vcf_tbi   = Channel.value(file(params.bayesdel_vcf_tbi,   checkIfExists: true))

    // ── Parse samplesheet ─────────────────────────────────────────────────────
    ch_samples = Channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            // Use 'sample' key to match VEP_ANNOTATE meta convention
            def meta      = [sample: row.sample, assay: row.assay]
            def vcf       = file(row.vcf,       checkIfExists: true)
            def bam       = file(row.bam,       checkIfExists: true)
            def bam_index = file(row.bam_index, checkIfExists: true)
            [ meta, vcf, bam, bam_index ]
        }

    // ── Step 1: VEP annotation ────────────────────────────────────────────────
    ch_vcf_only = ch_samples.map { meta, vcf, bam, bam_index -> [ meta, vcf ] }

    VEP_ANNOTATE(
        ch_vcf_only,
        ch_vep_cache,
        ch_vep_fasta,
        ch_vep_fasta_fai,
        //ch_revel_vcf,
        //ch_revel_vcf_tbi,
        //ch_alpha_vcf,
        //ch_alpha_vcf_tbi,
        ch_clinvar_vcf,
        ch_clinvar_vcf_tbi,
        //ch_spliceai_snv,
        //ch_spliceai_snv_tbi,
        //ch_spliceai_indel,
        //ch_spliceai_indel_tbi,
        //ch_bayesdel_vcf,
        //ch_bayesdel_vcf_tbi,
        ch_vep_plugins
    )
    // ── Step 2: Extract variants from VEP-annotated VCF ───────────────────────
    ch_variants_script = Channel.value(file("${params.script_dir}/db_vep_vcf_to_variants_all.py"))
    EXTRACT_VARIANTS(VEP_ANNOTATE.out.vep_vcf, ch_variants_script)

    // ── Step 3: BAM coverage (runs in parallel with VEP/extraction) ───────────
    ch_bam_input = ch_samples.map { meta, vcf, bam, bam_index -> [ meta, bam, bam_index ] }

    MOSDEPTH_THRESHOLDS(ch_bam_input, ch_bins_bed)

    // ── Step 4: Convert mosdepth thresholds to coverage TSV ──────────────────
    CONVERT_THRESHOLDS(MOSDEPTH_THRESHOLDS.out.per_base_bed, ch_bins_bed)
}
