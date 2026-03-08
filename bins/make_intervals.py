#!/usr/bin/env python3
import argparse, gzip, math

def open_maybe_gz(path: str):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path, "rt")

def ensure_chr(c: str) -> str:
    return c if c.startswith("chr") else f"chr{c}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mane_tsv", required=True)
    ap.add_argument("--out_bed", required=True)
    ap.add_argument("--bin", type=int, default=200)
    ap.add_argument("--only_mane_select", action="store_true")
    args = ap.parse_args()

    with open_maybe_gz(args.mane_tsv) as fh:
        header = fh.readline().rstrip("\n").split("\t")
        col = {h: i for i, h in enumerate(header)}
        for req in ("chromosome", "start", "end"):
            if req not in col:
                raise SystemExit(f"ERROR: missing column {req} in MANE TSV")

        mane_idx = col.get("MANE_status")

        with open(args.out_bed, "w") as out:
            for line in fh:
                if not line.strip():
                    continue
                p = line.rstrip("\n").split("\t")

                if args.only_mane_select and mane_idx is not None:
                    if p[mane_idx].strip() != "MANE Select":
                        continue

                chrom = ensure_chr(p[col["chromosome"]].strip())
                start1 = int(p[col["start"]])
                end1   = int(p[col["end"]])
                if end1 < start1:
                    start1, end1 = end1, start1

                # 1-based inclusive -> convert to 0-based half-open region for binning
                start0 = start1 - 1
                end0   = end1      # inclusive end1 becomes exclusive end0

                # create contiguous bins
                b = args.bin
                first_bin_start = (start0 // b) * b
                last_bin_start  = ((end0 - 1) // b) * b

                s = first_bin_start
                while s <= last_bin_start:
                    e = s + b
                    # clamp to interval
                    cs = max(s, start0)
                    ce = min(e, end0)
                    if cs < ce:
                        out.write(f"{chrom}\t{cs}\t{ce}\n")
                    s += b

if __name__ == "__main__":
    main()