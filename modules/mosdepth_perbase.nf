// ─────────────────────────────────────────────────────────────────────────────
//  modules/mosdepth_perbase.nf
//  Process: MOSDEPTH_PERBASE
//  Input  : BAM + index, target regions BED
//  Output : per-base depth restricted to BED intervals
// ─────────────────────────────────────────────────────────────────────────────

process MOSDEPTH_PERBASE {

    tag "${meta.sample} | ${meta.assay}"
    label 'high_cpu'

    publishDir(
        path:    "${params.outdir}/${meta.sample}/mosdepth",
        mode:    'copy',
        pattern: '*.{bed.gz,bed.gz.csi,summary.txt}'
    )

    input:
    tuple val(meta), path(bam), path(bam_index)
    path  bins_bed

    output:
    tuple val(meta), path("${meta.sample}.per-base.bed.gz"),      emit: per_base_bed
    tuple val(meta), path("${meta.sample}.per-base.bed.gz.csi"),  emit: per_base_bed_index
    tuple val(meta), path("${meta.sample}.mosdepth.summary.txt"), emit: mosdepth_summary

    script:
    def sample  = meta.sample
    def threads = task.cpus
    """
    mosdepth \\
        --by      "${bins_bed}" \\
        --mapq    20 \\
        --threads "${threads}" \\
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
