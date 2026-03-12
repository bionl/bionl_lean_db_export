#!/usr/bin/env python3
import argparse
import pandas as pd
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--per_base_bed", required=True)
    ap.add_argument("--sample",       required=True)
    ap.add_argument("--assay",        required=True)
    ap.add_argument("--outdir",       default=".")
    args = ap.parse_args()

    outfile = Path(args.outdir) / f"{args.sample}_{args.assay}_coverage.tsv"

    with open(outfile, "w") as f:
        f.write("chrom\tpos\tdepth\tover_10\tover_20\tover_30\tover_50\tover_100\tn_samples\n")

    total_rows = 0

    for chunk in pd.read_csv(
        args.per_base_bed,
        sep="\t", compression="gzip", comment="#", header=None,
        names=["chrom", "start", "end", "depth"],
        chunksize=500_000
    ):
        chunk["chrom"]     = chunk["chrom"].str.replace("chr", "", regex=False)
        chunk["pos"]       = chunk["start"]
        chunk["over_10"]   = (chunk["depth"] >= 10).astype(int)
        chunk["over_20"]   = (chunk["depth"] >= 20).astype(int)
        chunk["over_30"]   = (chunk["depth"] >= 30).astype(int)
        chunk["over_50"]   = (chunk["depth"] >= 50).astype(int)
        chunk["over_100"]  = (chunk["depth"] >= 100).astype(int)
        chunk["n_samples"] = 1

        chunk[["chrom", "pos", "depth", "over_10", "over_20", "over_30", "over_50", "over_100", "n_samples"]]\
            .to_csv(outfile, sep="\t", index=False, header=False, mode="a")

        total_rows += len(chunk)

    print(f"Written {total_rows} rows -> {outfile}")

if __name__ == "__main__":
    main()