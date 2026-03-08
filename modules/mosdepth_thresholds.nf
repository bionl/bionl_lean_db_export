// ─────────────────────────────────────────────────────────────────────────────
//  modules/mosdepth_thresholds.nf
//  Process: MOSDEPTH_THRESHOLDS
//  Input  : BAM + index, MANE bins BED file
//  Output : sample.regions.bed.gz (+ .tbi)
// ─────────────────────────────────────────────────────────────────────────────

process MOSDEPTH_THRESHOLDS {

    tag "${meta.sample} | ${meta.assay}"
    label 'high_cpu'


    input:
    tuple val(meta), path(bam), path(bam_index)
    path  bins_bed

    output:
    tuple val(meta), path("${meta.sample}.regions.bed.gz"),    emit: regions_bed
    tuple val(meta), path("${meta.sample}.regions.bed.gz.csi"),    emit: regions_index
    tuple val(meta), path("${meta.sample}.mosdepth.summary.txt"),     emit: summary

    script:
    def sample     = meta.sample
    def threads    = task.cpus
    """
    mosdepth \\
        --by         "${bins_bed}" \\
        --no-per-base \\
        --fast-mode \\
        --threads    "${threads}" \\
        "${sample}" \\
        "${bam}"
    """

    stub:
    """
    touch ${meta.sample}.regions.bed.gz
    touch ${meta.sample}.regions.bed.gz.csi
    touch ${meta.sample}.mosdepth.summary.txt
    """
}
