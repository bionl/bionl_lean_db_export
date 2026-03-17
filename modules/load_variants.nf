// ─────────────────────────────────────────────────────────────────────────────
//  modules/load_variants.nf
//  Process: LOAD_VARIANTS
//  Calls the vaic-service API to load extracted variants into BigQuery.
//  Input  : sample meta + variants TSV (from EXTRACT_VARIANTS)
//  Output : sample_id on success
// ─────────────────────────────────────────────────────────────────────────────

process LOAD_VARIANTS {

    tag "${meta.sample} | ${meta.assay}"
    label 'low_cpu'

    maxRetries 3
    errorStrategy { task.attempt <= 3 ? 'retry' : 'finish' }

    input:
    tuple val(meta), path(variants_tsv)

    output:
    val(meta), emit: loaded_sample

    script:
    def sampleId   = meta.sample
    def gcsPath    = "${params.outdir}/variants/${variants_tsv.name}"
    def serviceUrl = params.vaic_service_url
    def apiKey     = params.vaic_api_key
    """
    set -euo pipefail

    echo "curl -s -o response.json -w '%{http_code}' --retry 3 --retry-delay 5 --retry-connrefused --max-time 600 -X POST ${serviceUrl}/variants-db/load-variants -H 'Content-Type: application/json' -H 'x-api-key: ***' -d '{\"fileUrl\": \"${gcsPath}\", \"sample_id\": \"${sampleId}\"}'"

    HTTP_CODE=\$(curl -s -o response.json -w '%{http_code}' \
        --retry 3 --retry-delay 5 --retry-connrefused \
        --max-time 600 \
        -X POST "${serviceUrl}/variants-db/load-variants" \
        -H 'Content-Type: application/json' \
        -H "x-api-key: ${apiKey}" \
        -d '{"fileUrl": "${gcsPath}", "sample_id": "${sampleId}"}')

    if [ "\$HTTP_CODE" -lt 200 ] || [ "\$HTTP_CODE" -ge 300 ]; then
        echo "ERROR: vaic-service returned HTTP \$HTTP_CODE"
        cat response.json >&2
        exit 1
    fi

    echo "Variants loaded for ${sampleId}"
    """

    stub:
    """
    echo "stub: would load variants for ${meta.sample}"
    """
}
