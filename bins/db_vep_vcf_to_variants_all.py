#!/usr/bin/env python3
import argparse, gzip, sys
from typing import Dict, Tuple, Optional

def open_maybe_gz(path: str):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path, "rt")

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

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", required=True)
    ap.add_argument("--assay",  required=True)
    ap.add_argument("--vcf",    required=True)
    ap.add_argument("--out",    required=False)
    args = ap.parse_args()

    out_path = args.out if args.out else f"{args.sample}_{args.assay}_variants.tsv"

    with open_maybe_gz(args.vcf) as fh, open(out_path, "w") as out:
        out.write(
            "sample_id\tassay_type\tchrom\tpos\tref\talt\tvariant_id\tgt\talt_allele_count\tis_hom_alt\n"
        )

        for line in fh:
            if line.startswith("#"):
                continue

            c = line.rstrip("\n").split("\t")
            if len(c) < 10:
                continue

            chrom, pos, _id, ref, alt_str, _qual, _flt, _info, fmt = c[:9]
            sample_field = c[9]

            if chrom.startswith("chr"):
                chrom = chrom[3:]

            fmt_keys = fmt.split(":")
            fmt_vals = sample_field.split(":")
            fmt_map  = {k: (fmt_vals[i] if i < len(fmt_vals) else "") for i, k in enumerate(fmt_keys)}
            gt = fmt_map.get("GT", "./.")
            alt_count, is_hom_alt = gt_to_alt_count(gt)

            for alt in alt_str.split(","):
                variant_id = f"{chrom}-{pos}-{ref}-{alt}"
                out.write(
                    f"{args.sample}\t{args.assay}\t{chrom}\t{pos}\t{ref}\t{alt}\t{variant_id}\t{gt}\t"
                    f"{'' if alt_count is None else alt_count}\t{is_hom_alt}\n"
                )

if __name__ == "__main__":
    main()
