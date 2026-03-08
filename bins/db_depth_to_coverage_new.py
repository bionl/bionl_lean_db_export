#!/usr/bin/env python3
import argparse
import pandas as pd
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regions_file", required=True, help="mosdepth regions .bed.gz")
    ap.add_argument("--sample",       required=True)
    ap.add_argument("--assay",        required=True)
    ap.add_argument("--outdir",       default=".")
    args = ap.parse_args()

    df = pd.read_csv(
        args.regions_file,
        sep="\t", compression="gzip", comment="#", header=None,
        names=["chrom", "start", "end", "mean_depth"]
    )

    df = df[["chrom", "start", "end", "mean_depth"]]

    outfile = Path(args.outdir) / f"{args.sample}_{args.assay}_coverage.tsv"
    df.to_csv(outfile, sep="\t", index=False)
    print(f"Written: {outfile}")

if __name__ == "__main__":
    main()