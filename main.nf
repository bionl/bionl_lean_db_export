#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ─────────────────────────────────────────────
//  Parameter defaults
// ─────────────────────────────────────────────
params.samplesheet          = "samplesheet.tsv"
params.outdir               = "results"
params.threads              = 4
params.mosdepth_thresholds  = "10,20,30"

// ── Shared reference / annotation resources ───────────────────────────────────
params.bins_bed             = "MANE_bins_unique.bed"

// ── VEP resources (all required) ─────────────────────────────────────────────
params.vep_cache            = /home/alkhatib/vep_data/cache   
params.vep_fasta            = /home/alkhatib/vep_data/Homo_sapiens.GRCh38.dna.toplevel.fa   
params.vep_fasta_fai        = /home/alkhatib/vep_data/Homo_sapiens.GRCh38.dna.toplevel.fa.fai  
params.vep_plugins          = /home/alkhatib/vep_plugins/

// ── VEP custom / plugin annotation files ─────────────────────────────────────
params.revel_vcf            = /home/alkhatib/vep_data/new_tabbed_revel_grch38.tsv.gz
params.revel_vcf_tbi        = /home/alkhatib/vep_data/new_tabbed_revel_grch38.tsv.gz.tbi
params.alpha_missense_vcf   = /home/alkhatib/vep_data/AlphaMissense_hg38.tsv.gz
params.alpha_missense_vcf_tbi = /home/alkhatib/vep_data/AlphaMissense_hg38.tsv.gz.tbi
params.clinvar_vcf          = /home/alkhatib/vep_data/ClinVar/clinvar.chr.vcf.gz
params.clinvar_vcf_tbi      = /home/alkhatib/vep_data/ClinVar/clinvar.chr.vcf.gz.tbi
//params.spliceai_snv_vcf     = /home/alkhatib/vep_data/SpliceAI_hg38.tsv.gz
//params.spliceai_snv_vcf_tbi = /home/alkhatib/vep_data/SpliceAI_hg38.tsv.gz.tbi
//params.spliceai_indel_vcf   = /home/alkhatib/vep_data/SpliceAI_hg38.tsv.gz
//params.spliceai_indel_vcf_tbi = /home/alkhatib/vep_data/SpliceAI_hg38.tsv.gz.tbi
//params.bayesdel_vcf         = /home/alkhatib/vep_data/BayesDel_hg38.tsv.gz
//params.bayesdel_vcf_tbi     = /home/alkhatib/vep_data/BayesDel_hg38.tsv.gz.tbi

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
def requireParam(String name) {
    if (params[name] == null) {
        error "Required parameter '--${name}' is not set. See README for usage."
    }
    return file(params[name], checkIfExists: true)
}

// ─────────────────────────────────────────────
//  Workflow
// ─────────────────────────────────────────────
workflow {

    // ── Validate core inputs ──────────────────────────────────────────────────
    if (!file(params.samplesheet).exists()) {
        error "Samplesheet not found: ${params.samplesheet}"
    }
    if (!file(params.bins_bed).exists()) {
        error "BED file not found: ${params.bins_bed}"
    }

    // ── Resolve shared reference / annotation files as value channels ─────────
    // Value channels broadcast to every sample without being consumed.
    ch_bins_bed           = Channel.value(file(params.bins_bed,             checkIfExists: true))
    ch_vep_cache          = Channel.value(requireParam('vep_cache'))
    ch_vep_fasta          = Channel.value(requireParam('vep_fasta'))
    ch_vep_fasta_fai      = Channel.value(requireParam('vep_fasta_fai'))
    ch_vep_plugins        = Channel.value(requireParam('vep_plugins'))
    ch_revel_vcf          = Channel.value(requireParam('revel_vcf'))
    ch_revel_vcf_tbi      = Channel.value(requireParam('revel_vcf_tbi'))
    ch_alpha_vcf          = Channel.value(requireParam('alpha_missense_vcf'))
    ch_alpha_vcf_tbi      = Channel.value(requireParam('alpha_missense_vcf_tbi'))
    ch_clinvar_vcf        = Channel.value(requireParam('clinvar_vcf'))
    ch_clinvar_vcf_tbi    = Channel.value(requireParam('clinvar_vcf_tbi'))
    //ch_spliceai_snv       = Channel.value(requireParam('spliceai_snv_vcf'))
    //ch_spliceai_snv_tbi   = Channel.value(requireParam('spliceai_snv_vcf_tbi'))
    //ch_spliceai_indel     = Channel.value(requireParam('spliceai_indel_vcf'))
    //ch_spliceai_indel_tbi = Channel.value(requireParam('spliceai_indel_vcf_tbi'))
    //ch_bayesdel_vcf       = Channel.value(requireParam('bayesdel_vcf'))
    //ch_bayesdel_vcf_tbi   = Channel.value(requireParam('bayesdel_vcf_tbi'))

    // ── Parse samplesheet ─────────────────────────────────────────────────────
    // Columns: sample, assay, vcf, bam, bam_index
    // The input VCF is the raw/consensus VCF — no pre-existing index needed.
    // VEP produces the annotated output consumed by EXTRACT_VARIANTS.
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
        ch_revel_vcf,
        ch_revel_vcf_tbi,
        ch_alpha_vcf,
        ch_alpha_vcf_tbi,
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
    EXTRACT_VARIANTS(VEP_ANNOTATE.out.vep_vcf)

    // ── Step 3: BAM coverage (runs in parallel with VEP/extraction) ───────────
    ch_bam_input = ch_samples.map { meta, vcf, bam, bam_index -> [ meta, bam, bam_index ] }

    MOSDEPTH_THRESHOLDS(ch_bam_input, ch_bins_bed)

    // ── Step 4: Convert mosdepth thresholds to coverage TSV ──────────────────
    CONVERT_THRESHOLDS(MOSDEPTH_THRESHOLDS.out.thresholds_bed)
}

// ─────────────────────────────────────────────
//  Completion summary
// ─────────────────────────────────────────────
workflow.onComplete {
    log.info """
    ╔══════════════════════════════════════════╗
    ║       Pipeline execution summary         ║
    ╠══════════════════════════════════════════╣
    ║ Status    : ${workflow.success ? 'SUCCESS ✔' : 'FAILED ✘'}
    ║ Duration  : ${workflow.duration}
    ║ Output    : ${params.outdir}
    ╚══════════════════════════════════════════╝
    """.stripIndent()
}
