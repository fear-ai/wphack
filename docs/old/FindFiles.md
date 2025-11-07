# FindFiles.md — WordPress incident tooling

Scripts live in the same directory and share `common.sh`.

## Scripts
- `common.sh` — shared helpers (portable `sha256`, `stat`, list readers).
- `find_scan.sh` — scan for filenames from one or more `--list` files.
- `scan_pat.sh` — content scanner (PHP default). Modes: `per-file` (default) or `per-pattern`.
- `make_fixed.sh` — create `fixed-<domain>.csv` baselines with size+sha256.
- `check_fixed.sh` — verify a baseline against a target directory.
- `run_audit.sh` — orchestrator (find → patterns → integrity).

## Quick start
```bash
cd /home2/wkarshat/tools
./find_scan.sh --list ./hacker /home2/wkarshat/public_html0
./scan_pat.sh  --pat ./pat.txt --php /home2/wkarshat/public_html0
./make_fixed.sh --depth 1 --outdir ./fixed /home2/wkarshat/public_html0/daoside.com
./check_fixed.sh --file ./fixed/fixed-daoside.com.csv --target /home2/wkarshat/public_html0/daoside.com
./run_audit.sh /home2/wkarshat/public_html0
```
