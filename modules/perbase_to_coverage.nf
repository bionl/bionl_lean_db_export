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
//  Chromosome names are bare (1, X, MT), whatever the BAM used.
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
    # Both sides must use the same chromosome spelling or bedtools finds no
    # overlap at all ("inconsistent naming convention") and the output is an
    # empty file that ingests as zero coverage. mosdepth follows the BAM, which
    # is chr-prefixed on this reference; strip the prefix from both streams so
    # the output carries bare names, matching the variants table.
    sed 's/^chr//' "${bins_bed}" > bins_nochr.bed
    gzip -dc "${per_base_bed}" \\
      | sed 's/^chr//' \\
      | bedtools intersect -a - -b bins_nochr.bed \\
      | awk 'BEGIN{OFS="\\t"} {print \$1, \$2, \$4}' \\
      | gzip > ${sample}_${assay}_coverage.tsv.gz
    """

    stub:
    """
    touch ${meta.sample}_${meta.assay}_coverage.tsv.gz
    """
}
