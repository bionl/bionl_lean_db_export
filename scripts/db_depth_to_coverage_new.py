#!/usr/bin/env python3
import argparse
import pandas as pd
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--infile", required=True, help="mosdepth thresholds .bed.gz file")
    ap.add_argument("--sample", required=True, help="Sample name")
    ap.add_argument("--assay", required=True, help="Assay type (WES/WGS/etc)")
    ap.add_argument("--outdir", default=".", help="Output directory (default: current)")
    args = ap.parse_args()

    # Read gzipped file directly
    df = pd.read_csv(
        args.infile,
        sep="\t",
        compression="gzip",
        comment="#",
        header=None
    )

    # Expect: chrom start end region 10X 20X 30X
    df = df.iloc[:, [0,1,2,5]]
    df.columns = ["chrom", "start", "end", "bases_20x"]

    # Compute bin size
    df["bin_size"] = df["end"] - df["start"]

    # Covered = 1 if all bases in bin >=20x
    df["covered_20x"] = (df["bases_20x"] == df["bin_size"]).astype(int)

    # Keep minimal required columns
    df = df[["chrom", "start", "end", "covered_20x"]]

    # Create output filename automatically
    outfile = Path(args.outdir) / f"{args.sample}_{args.assay}_coverage.tsv"

    df.to_csv(outfile, sep="\t", index=False)

    print(f"Output written to: {outfile}")

if __name__ == "__main__":
    main()