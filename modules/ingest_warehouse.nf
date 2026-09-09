// ─────────────────────────────────────────────────────────────────────────────
//  modules/ingest_warehouse.nf
//  Process: INGEST_WAREHOUSE
//  POSTs both coverage and variants GCS URIs to the variants-db ingestion API.
//  Both calls are made from one process so allele number (coverage) and allele
//  count (variants) always come from the same pipeline run.
//
//  API key: Nextflow secret VARIANTS_DB_API_KEY (never appears in logs/work dir)
//  Endpoint base: params.variants_db_url
// ─────────────────────────────────────────────────────────────────────────────

process INGEST_WAREHOUSE {

    tag "${sample} | ${assay}"

    secret 'VARIANTS_DB_API_KEY'

    errorStrategy 'retry'
    maxRetries 2

    input:
    tuple val(sample), val(assay), val(sex), val(coverage_uri), val(variants_uri)

    script:
    """
    ingest() {
        kind=\$1; uri=\$2
        body=\$(printf \
            '{"fileUrl":"%s","sample_id":"%s","assay_type":"%s","sex_karyotype":"%s","source_run_id":"%s"}' \\
            "\$uri" "${sample}" "${assay}" "${sex}" "${workflow.runName}")
        code=\$(curl -s -o "\$kind.json" -w '%{http_code}' -X POST \\
            "${params.variants_db_url}/variants-db/ingestion/\$kind" \\
            -H "x-api-key: \$VARIANTS_DB_API_KEY" \\
            -H 'content-type: application/json' \\
            -d "\$body")
        case "\$code" in
            202|409) echo "\$kind: accepted (\$code)";;
            *) echo "\$kind: HTTP \$code"; cat "\$kind.json"; exit 1;;
        esac
    }

    ingest coverage "${coverage_uri}"
    ingest variants "${variants_uri}"
    """

    stub:
    """
    echo "stub: would ingest coverage and variants for ${sample}"
    """
}
