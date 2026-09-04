// ─────────────────────────────────────────────────────────────────────────────
//  modules/perbase_to_coverage.nf
//  Process: PERBASE_TO_COVERAGE
//  Input  : mosdepth per-base BED + target regions BED
//  Output : {sample}_{assay}_coverage.tsv.gz
//
//  Output format — headerless TSV, four columns:
//    chrom   1-based start   1-based inclusive end   depth
//  Each row is a run of constant depth (run-length encoded).
//  Single-base runs have start == end.
//  Restricted to intervals in bins_bed; no alt/random/EBV contigs.
// ─────────────────────────────────────────────────────────────────────────────

process PERBASE_TO_COVERAGE {

    tag "${meta.sample} | ${meta.assay}"

    publishDir(
        path:    "${params.outdir}/coverage",
        mode:    'copy',
        pattern: '*.tsv.gz'
    )

    input:
    tuple val(meta), path(per_base_bed)
    path  bins_bed

    output:
    tuple val(meta), path("${meta.sample}_${meta.assay}_coverage.tsv.gz"), emit: coverage_tsv

    script:
    def sample = meta.sample
    def assay  = meta.assay
    """
    sed 's/^chr//' "${bins_bed}" > bins_nochr.bed
    gzip -dc "${per_base_bed}" \\
      | bedtools intersect -a - -b bins_nochr.bed \\
      | awk 'BEGIN{OFS="\\t"} {print \$1, \$2, \$4}' \\
      | gzip > ${sample}_${assay}_coverage.tsv.gz
    """

    stub:
    """
    touch ${meta.sample}_${meta.assay}_coverage.tsv.gz
    """
}
