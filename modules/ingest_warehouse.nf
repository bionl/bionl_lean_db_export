// ─────────────────────────────────────────────────────────────────────────────
//  modules/ingest_warehouse.nf
//  Process: INGEST_WAREHOUSE
//  POSTs both coverage and variants GCS URIs to the variants-db ingestion API.
//  Both calls are made from one process so allele number (coverage) and allele
//  count (variants) always come from the same pipeline run.
//
//  Endpoint base: params.variants_db_url (the bionl launcher sets it in the
//                 config it attaches to every run; leave the default at null)
//  Auth: a Google identity token the task VM mints for that URL through its
//        metadata server, sent in the X-Bionl-Identity header (not
//        Authorization: Cloud Run strips the signature there). Nothing is stored in
//        the work dir or logs. Nextflow's `secret` directive is NOT used: it
//        only works on local and grid executors, on Google Batch the task has
//        no access to the launcher's secret store and the variable is unbound.
// ─────────────────────────────────────────────────────────────────────────────

process INGEST_WAREHOUSE {

    tag "${sample} | ${assay}"

    errorStrategy 'retry'
    maxRetries 2

    input:
    tuple val(sample), val(assay), val(sex), val(coverage_uri), val(variants_uri)

    script:
    """
    base="${params.variants_db_url}"; base="\${base%/}"
    if [ -z "\$base" ] || [ "\$base" = "null" ]; then
        echo "params.variants_db_url is not set; the launcher config should provide it"; exit 1
    fi

    token=\$(curl -sf -H 'Metadata-Flavor: Google' \\
        "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/identity?audience=\$base&format=full")
    if [ -z "\$token" ]; then
        echo "could not obtain an identity token for \$base from the metadata server"; exit 1
    fi

    ingest() {
        kind=\$1; uri=\$2
        body=\$(printf \
            '{"fileUrl":"%s","sample_id":"%s","assay_type":"%s","sex_karyotype":"%s","source_run_id":"%s"}' \\
            "\$uri" "${sample}" "${assay}" "${sex}" "${workflow.runName}")
        code=\$(curl -s -o "\$kind.json" -w '%{http_code}' -X POST \\
            "\$base/variants-db/ingestion/\$kind" \\
            -H "X-Bionl-Identity: \$token" \\
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
