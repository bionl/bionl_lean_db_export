#!/usr/bin/env python3
import argparse
import pandas as pd
from pathlib import Path
import gzip

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--per_base_bed", required=True)
    ap.add_argument("--sample",       required=True)
    ap.add_argument("--assay",        required=True)
    ap.add_argument("--outdir",       default=".")
    args = ap.parse_args()

    outfile = Path(args.outdir) / f"{args.sample}_{args.assay}_coverage.tsv.gz"

    with gzip.open(outfile, "wt") as f:
        f.write("chrom\tpos\tdepth")

    total_rows = 0

    for chunk in pd.read_csv(
        args.per_base_bed,
        sep="\t", compression="gzip", comment="#", header=None,
        names=["chrom", "start", "end", "depth"],
        chunksize=500_000
    ):
        chunk["chrom"]     = chunk["chrom"].str.replace("chr", "", regex=False)
        chunk["pos"]       = chunk["start"]

        chunk[["chrom", "pos", "depth"]]\
            .to_csv(outfile, sep="\t", index=False, header=False, mode="a", compression="gzip")

        total_rows += len(chunk)

    print(f"Written {total_rows} rows -> {outfile}")

if __name__ == "__main__":
    main()