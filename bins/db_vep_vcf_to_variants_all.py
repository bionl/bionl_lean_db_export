#!/usr/bin/env python3
import argparse, gzip, sys
from typing import Dict, List, Optional, Tuple

def open_maybe_gz(path: str):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path, "rt")

def parse_info(info_str: str) -> Dict[str, str]:
    d = {}
    for item in info_str.split(";"):
        if not item:
            continue
        if "=" in item:
            k, v = item.split("=", 1)
            d[k] = v
        else:
            d[item] = "true"
    return d

def parse_csq_header(line: str) -> Optional[List[str]]:
    if "ID=CSQ" not in line or "Format:" not in line:
        return None
    fmt = line.split("Format:", 1)[1].strip()
    if fmt.endswith('">'):
        fmt = fmt[:-2]
    fmt = fmt.strip().strip('"')
    return [c.strip() for c in fmt.split("|")]

def gt_to_alt_count(gt: str) -> Tuple[Optional[int], int]:
    if gt in (".", "./.", ".|."):
        return None, 0
    sep = "|" if "|" in gt else "/"
    a = gt.split(sep)
    if any(x == "." for x in a):
        return None, 0
    alt_count = sum(1 for x in a if x != "0")
    is_hom_alt = 1 if len(a) == 2 and a[0] != "0" and a[0] == a[1] else 0
    return alt_count, is_hom_alt

PLOF = {"stop_gained","frameshift_variant","splice_acceptor_variant","splice_donor_variant","start_lost","stop_lost"}
MISSENSE = {"missense_variant","inframe_insertion","inframe_deletion","protein_altering_variant"}
SYN = {"synonymous_variant","stop_retained_variant","start_retained_variant"}

def consequence_to_impact(cons: str) -> str:
    terms = cons.split("&") if cons else []
    if any(t in PLOF for t in terms): return "pLoF"
    if any(t in MISSENSE for t in terms): return "missense"
    if any(t in SYN for t in terms): return "synonymous"
    return "other"

def score_transcript(m: Dict[str, str]) -> int:
    score = 0
    if m.get("CANONICAL","").upper() == "YES": score += 10
    if m.get("MANE_SELECT",""): score += 5
    if m.get("BIOTYPE","") == "protein_coding": score += 2
    if m.get("APPRIS","").startswith("principal"): score += 1
    return score

def safe_hgvsc(hgvsc_field: str) -> str:
    if not hgvsc_field:
        return ""
    return hgvsc_field.split(":", 1)[1] if ":" in hgvsc_field else hgvsc_field

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", required=True)
    ap.add_argument("--assay", required=True)
    ap.add_argument("--vcf", required=True)
    ap.add_argument("--out", required=False)
    args = ap.parse_args()

    # Auto-generate output filename if not provided
    if args.out:
        out_path = args.out
    else:
        out_path = f"{args.sample}_{args.assay}_variants.tsv"

    csq_cols: Optional[List[str]] = None
    csq_idx: Dict[str, int] = {}

    with open_maybe_gz(args.vcf) as fh, open(out_path, "w") as out:
        out.write(
            "sample_id\tassay_type\tgene_symbol\tmane_select\tchrom\tpos\tref\talt\tvariant_id\tgt\t"
            "alt_allele_count\tis_hom_alt\thgvsc\tvariant_impact\tclinvar_clnsig\tclinvar_alleleid\n"
        )

        for line in fh:
            if line.startswith("##"):
                if line.startswith("##INFO=<") and "ID=CSQ" in line and "Format:" in line:
                    csq_cols = parse_csq_header(line)
                    if csq_cols:
                        csq_idx = {name: i for i, name in enumerate(csq_cols)}
                continue

            if line.startswith("#CHROM"):
                if csq_cols is None:
                    print("ERROR: CSQ header not found", file=sys.stderr)
                    sys.exit(2)
                continue

            c = line.rstrip("\n").split("\t")
            if len(c) < 10:
                continue

            chrom, pos, _id, ref, alt_str, qual, flt, info, fmt = c[:9]
            sample_field = c[9]
            
            # Remove "chr" prefix from chromosome if present
            if chrom.startswith("chr"):
                chrom = chrom[3:]

            info_d = parse_info(info)
            csq_raw = info_d.get("CSQ")
            if not csq_raw:
                continue

            # GT
            fmt_keys = fmt.split(":")
            fmt_vals = sample_field.split(":")
            fmt_map = {k: (fmt_vals[i] if i < len(fmt_vals) else "") for i, k in enumerate(fmt_keys)}
            gt = fmt_map.get("GT", "./.")
            alt_count, is_hom_alt = gt_to_alt_count(gt)

            # Helpers to fetch CSQ columns
            def csq_get(fields: List[str], col: str) -> str:
                i = csq_idx.get(col, -1)
                return fields[i] if 0 <= i < len(fields) else ""

            # Split multi-ALT
            alts = alt_str.split(",")

            # Pre-split CSQ entries once
            csq_entries = [e.split("|") for e in csq_raw.split(",")]

            # If VEP provides "Allele" in CSQ, use it to bind to the correct ALT.
            has_allele = "Allele" in csq_idx

            for alt in alts:
                # Collect "best transcript per gene" for this specific ALT
                best_by_gene: Dict[str, Tuple[int, Dict[str, str]]] = {}

                for fields in csq_entries:
                    if has_allele:
                        allele = csq_get(fields, "Allele")
                        if allele and allele != alt:
                            continue

                    gene = csq_get(fields, "SYMBOL")
                    if not gene:
                        continue

                    m = {col: (fields[i] if i < len(fields) else "") for i, col in enumerate(csq_cols)}  # type: ignore
                    sc = score_transcript(m)

                    prev = best_by_gene.get(gene)
                    if prev is None or sc > prev[0]:
                        best_by_gene[gene] = (sc, m)

                if not best_by_gene:
                    continue

                variant_id = f"{chrom}-{pos}-{ref}-{alt}"

                for gene in sorted(best_by_gene.keys()):
                    m = best_by_gene[gene][1]
                    hgvsc = safe_hgvsc(m.get("HGVSc", ""))
                    mane_select = m.get("MANE_SELECT", "")
                    impact = consequence_to_impact(m.get("Consequence", ""))
                    clin_sig = m.get("ClinVar_CLNSIG", "") or "Not Provided"
                    allele_id = m.get("ClinVar_ALLELEID", "")

                    out.write(
                        f"{args.sample}\t{args.assay}\t{gene}\t{mane_select}\t{chrom}\t{pos}\t{ref}\t{alt}\t{variant_id}\t{gt}\t"
                        f"{'' if alt_count is None else alt_count}\t{is_hom_alt}\t{hgvsc}\t{impact}\t{clin_sig}\t{allele_id}\n"
                    )

if __name__ == "__main__":
    main()