// ─────────────────────────────────────────────────────────────────────────────
//  modules/thresholds_to_coverage.nf
//  Process: CONVERT_THRESHOLDS
//  Input  : mosdepth thresholds BED (from MOSDEPTH_THRESHOLDS)
//  Output : {sample}_{assay}_coverage.tsv
// ─────────────────────────────────────────────────────────────────────────────

process CONVERT_THRESHOLDS {

    tag "${meta.sample} | ${meta.assay}"

    publishDir(
        path:    "${params.outdir}/coverage",
        mode:    'copy',
        pattern: '*.tsv.gz'
    )

    input:
    tuple val(meta), path(per_base_bed)

    output:
    tuple val(meta), path("${meta.sample}_${meta.assay}_coverage.tsv.gz"), emit: coverage_tsv

    script:
    def sample = meta.sample
    def assay  = meta.assay
    """
    { printf 'chrom\tpos\tdepth\\n'; \
      gzip -dc "${per_base_bed}" | \
      awk 'BEGIN{OFS="\\t"} {gsub("chr","",\$1); print \$1, \$2, \$4}'; } | \
      gzip > ${sample}_${assay}_coverage.tsv.gz
    """

    stub:
    """
    touch ${meta.sample}_${meta.assay}_coverage.tsv.gz
    """
}
