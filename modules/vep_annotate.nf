// ─────────────────────────────────────────────────────────────────────────────
//  modules/vep_annotate.nf
//  Process: VEP_ANNOTATE
//  Input  : raw / consensus VCF (plain or .gz) + all annotation resources
//  Output : {sample}.vep.vcf  (uncompressed, for downstream EXTRACT_VARIANTS)
// ─────────────────────────────────────────────────────────────────────────────

process VEP_ANNOTATE {

    tag { "${meta.sample} (${meta.assay})" }
    label 'high_cpu'

    publishDir(
        path:    "${params.outdir}/${meta.sample}/vcf",
        mode:    'copy',
        pattern: '*.vep.vcf'
    )

    input:
    tuple val(meta), path(vcf)
    path vep_cache
    path vep_fasta
    path vep_fasta_fai
    path revel_vcf
    path revel_vcf_tbi
    path alpha_missense_vcf
    path alpha_missense_vcf_tbi
    path clinvar_vcf
    path clinvar_vcf_tbi
    path spliceai_snv_vcf
    path spliceai_snv_vcf_tbi
    path spliceai_indel_vcf
    path spliceai_indel_vcf_tbi
    path bayesdel_vcf
    path bayesdel_vcf_tbi
    path vep_plugins

    output:
    tuple val(meta), path("${meta.sample}.vep.vcf"), emit: vep_vcf

    script:
    def sample = meta.sample
    """
    set -euo pipefail

    # Accept both plain and gzipped VCF input
    if [[ "${vcf}" == *.vcf.gz ]]; then
        gunzip -c "${vcf}" > INPUT_FOR_VEP.vcf
    else
        cp "${vcf}" INPUT_FOR_VEP.vcf
    fi

    vep \\
        -i INPUT_FOR_VEP.vcf \\
        -o ${sample}.vep.vcf \\
        --fork           ${task.cpus} \\
        --offline --cache --dir_cache ${vep_cache} \\
        --dir_plugins    ${vep_plugins} \\
        --fasta          ${vep_fasta} \\
        --assembly GRCh38 --species homo_sapiens \\
        --hgvs --symbol --vcf --everything --canonical --merged\\
        --plugin REVEL,${revel_vcf} \\
        --plugin AlphaMissense,file=${alpha_missense_vcf},cols=am_pathogenicity:am_class \\
        --custom ${clinvar_vcf},ClinVar,vcf,exact,0,CLNSIG,CLNREVSTAT,ALLELEID \\
        --plugin SpliceAI,snv=${spliceai_snv_vcf},indel=${spliceai_indel_vcf} \\
        --plugin BayesDel,file=${bayesdel_vcf} \\
    """

    stub:
    """
    touch ${meta.sample}.vep.vcf
    """
}
