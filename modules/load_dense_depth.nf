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
    def serviceUrl = params.vaic_service_url
    def apiKey     = params.vaic_api_key
    log.info "[LOAD_DENSE_DEPTH] ${sampleId} -> POST ${serviceUrl}/variants-db/load-dense-depth  fileUrl=${gcsPath}"
    """
    pip install -q requests

    python3 << 'PYEOF'
import requests, sys

resp = requests.post(
    "${serviceUrl}/variants-db/load-dense-depth",
    json={"fileUrl": "${gcsPath}", "sample_id": "${sampleId}"},
    headers={"x-api-key": "${apiKey}"},
    timeout=600,
)
print(f"Status: {resp.status_code}")
print(resp.text)
resp.raise_for_status()
print("Dense depth loaded for ${sampleId}")
PYEOF
    """

    stub:
    """
    echo "stub: would load dense depth for ${meta.sample}"
    """
}
