// ─────────────────────────────────────────────────────────────────────────────
//  modules/mosdepth_thresholds.nf
//  Process: MOSDEPTH_THRESHOLDS
//  Input  : BAM + index, MANE bins BED file
//  Output : sample.thresholds.bed.gz (+ .tbi)
// ─────────────────────────────────────────────────────────────────────────────

process MOSDEPTH_THRESHOLDS {

    tag "${meta.sample} | ${meta.assay}"
    label 'med_cpu'

    publishDir(
        path:    "${params.outdir}/mosdepth/${meta.sample}",
        mode:    'copy',
        pattern: '*.{gz,gz.csi,summary.txt}'
    )

    input:
    tuple val(meta), path(bam), path(bam_index)
    path  bins_bed

    output:
    tuple val(meta), path("${meta.sample}.thresholds.bed.gz"),        emit: thresholds_bed
    tuple val(meta), path("${meta.sample}.thresholds.bed.gz.csi"),    emit: thresholds_index  , optional: true
    tuple val(meta), path("${meta.sample}.mosdepth.summary.txt"),     emit: summary

    script:
    def sample     = meta.sample
    def thresholds = params.mosdepth_thresholds
    def threads    = task.cpus
    """
    mosdepth \\
        --by         "${bins_bed}" \\
        --thresholds "${thresholds}" \\
        --no-per-base \\
        --fast-mode \\
        --threads    "${threads}" \\
        "${sample}" \\
        "${bam}"
    """

    stub:
    """
    touch ${meta.sample}.thresholds.bed.gz
    touch ${meta.sample}.thresholds.bed.gz.csi
    touch ${meta.sample}.mosdepth.summary.txt
    """
}
