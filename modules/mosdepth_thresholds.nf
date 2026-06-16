// ─────────────────────────────────────────────────────────────────────────────
//  modules/mosdepth_thresholds.nf
//  Process: MOSDEPTH_THRESHOLDS
//  Input  : BAM + index, MANE bins BED file
//  Output : sample.regions.bed.gz (+ .tbi)
// ─────────────────────────────────────────────────────────────────────────────

process MOSDEPTH_THRESHOLDS {

    tag "${meta.sample} | ${meta.assay}"
    label 'high_cpu'
    
    publishDir(
        path:    "${params.outdir}/${meta.sample}/mosdepth",
        pattern: '*.{bed.gz,bed.gz.csi,summary.txt}'
    )

    input:
    tuple val(meta), path(bam), path(bam_index)
    path  bins_bed

    output:
    tuple val(meta), path("${meta.sample}.per-base.bed.gz"),     emit: per_base_bed
    tuple val(meta), path("${meta.sample}.per-base.bed.gz.csi"), emit: per_base_bed_index
    tuple val(meta), path("${meta.sample}.mosdepth.summary.txt"), emit: mosdepth_summary

    script:
    def sample     = meta.sample
    def threads    = task.cpus
    """
    mosdepth \\
        --by         "${bins_bed}" \\
        --threads    "${threads}" \\
        "${sample}" \\
        "${bam}"
    """

    stub:
    """
    touch ${meta.sample}.per-base.bed.gz
    touch ${meta.sample}.per-base.bed.gz.csi
    touch ${meta.sample}.mosdepth.summary.txt
    """
}
