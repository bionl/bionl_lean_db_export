// ─────────────────────────────────────────────────────────────────────────────
//  modules/extract_variants.nf
//  Process: EXTRACT_VARIANTS
//  Input  : VEP-annotated VCF + index
//  Output : {sample}_{assay}_variants.tsv
// ─────────────────────────────────────────────────────────────────────────────

process EXTRACT_VARIANTS {

    tag "${meta.sample} | ${meta.assay}"
    label 'low_cpu'

    publishDir(
        path:    "${params.outdir}/variants",
        mode:    'copy',
        pattern: '*.tsv'
    )

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(meta), path("${meta.sample}_${meta.assay}_variants.tsv"), emit: variants_tsv

    script:
    def sample = meta.sample
    def assay  = meta.assay
    """
    db_vep_vcf_to_variants_all.py \\
        --sample  "${sample}" \\
        --assay   "${assay}"  \\
        --vcf     "${vcf}"
    """

    stub:
    """
    touch ${meta.sample}_${meta.assay}_variants.tsv
    """
}
