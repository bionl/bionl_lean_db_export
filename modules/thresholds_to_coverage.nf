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
    tuple val(meta), path(regions_bed)
    path coverage_script
    output:
    tuple val(meta), path("${meta.sample}_${meta.assay}_coverage.tsv"), emit: coverage_tsv

    script:
    def sample = meta.sample
    def assay  = meta.assay
    """
    python ${coverage_script} \\
        --regions_file "${regions_bed}" \\
        --sample  "${sample}" \\
        --assay   "${assay}"
    """

    stub:
    """
    touch ${meta.sample}_${meta.assay}_coverage.tsv
    """
}
