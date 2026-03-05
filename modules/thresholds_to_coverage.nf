// ─────────────────────────────────────────────────────────────────────────────
//  modules/thresholds_to_coverage.nf
//  Process: CONVERT_THRESHOLDS
//  Input  : mosdepth thresholds BED (from MOSDEPTH_THRESHOLDS)
//  Output : {sample}_{assay}_coverage.tsv
// ─────────────────────────────────────────────────────────────────────────────

process CONVERT_THRESHOLDS {

    tag "${meta.sample} | ${meta.assay}"
    label 'low_cpu'

    publishDir(
        path:    "${params.outdir}/coverage",
        mode:    'copy',
        pattern: '*.tsv'
    )

    input:
    tuple val(meta), path(thresholds_bed)

    output:
    tuple val(meta), path("${meta.sample}_${meta.assay}_coverage.tsv"), emit: coverage_tsv

    script:
    def sample = meta.sample
    def assay  = meta.assay
    """
    python ${projectDir}/bin/db_depth_to_coverage_new.py \\
        --infile  "${thresholds_bed}" \\
        --assay   "${assay}"          \\
        --sample  "${sample}"
    """

    stub:
    """
    touch ${meta.sample}_${meta.assay}_coverage.tsv
    """
}
