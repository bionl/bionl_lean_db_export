// ─────────────────────────────────────────────────────────────────────────────
//  modules/load_dense_depth.nf
//  Process: LOAD_DENSE_DEPTH
//  Calls the vaic-service API to load coverage data into BigQuery.
//  Input  : sample meta + coverage TSV.GZ (from CONVERT_THRESHOLDS)
//  Output : sample_id on success
// ─────────────────────────────────────────────────────────────────────────────

process LOAD_DENSE_DEPTH {

    tag "${meta.sample} | ${meta.assay}"
    label 'low_cpu'

    maxRetries 3
    errorStrategy { task.attempt <= 3 ? 'retry' : 'finish' }

    input:
    tuple val(meta), path(coverage_tsv)

    output:
    val(meta), emit: loaded_sample

    script:
    def sampleId   = meta.sample
    def gcsPath    = "${params.outdir}/coverage/${coverage_tsv.name}"
    """
    set -euo pipefail

    HTTP_CODE=\$(curl -s -o response.json -w '%{http_code}' \
        --retry 3 --retry-delay 5 --retry-connrefused \
        --max-time 600 \
        -X POST "${params.vaic_service_url}/variants-db/load-dense-depth" \
        -H 'Content-Type: application/json' \
        -H "x-api-key: ${params.vaic_api_key}" \
        -d '{"fileUrl": "${gcsPath}", "sample_id": "${sampleId}"}')

    if [ "\$HTTP_CODE" -lt 200 ] || [ "\$HTTP_CODE" -ge 300 ]; then
        echo "ERROR: vaic-service returned HTTP \$HTTP_CODE"
        cat response.json >&2
        exit 1
    fi

    echo "Dense depth loaded for ${sampleId}"
    """

    stub:
    """
    echo "stub: would load dense depth for ${meta.sample}"
    """
}
