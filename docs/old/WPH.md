# WPH.md — WordPress Incident: Impact, Mitigation, and File-Tooling

> Account root: `/home2/wkarshat`  
> Compromised web tree (hidden): `/home2/wkarshat/public_html0`  
> System-recreated web tree (empty/fresh): `/home2/wkarshat/public_html`

## 1) Executive Summary

Multiple WordPress sites hosted under a single VPS account were compromised. Attackers deployed:
- **Malicious `.htaccess` variants** above and within site trees to selectively allow backdoors while blocking other PHP.
- **Obfuscated PHP loaders/redirectors**, replacing core entry points (e.g., `index.php`) and adding many webshell-like files.
- Widespread **file proliferation** and **permission drift**.

Immediate containment renamed the active webroot from `public_html` to `public_html0`, removing the sites from Apache’s path. The panel auto-recreated `public_html`, `mail`, `perl5`, and `tmp` under the account root—these are **not** the original content.

## 2) Symptoms & Customer Impact

- Sites returned **403**, 302/redirect loops, or hung.
- Admin access unreliable; security/backup plugins frequently disabled or bypassed.
- Thousands of unexpected `.php` files and non-standard `.htaccess` appeared, including **above** site roots.

## 3) Indicators of Compromise (IOCs)

### 3.1 Malicious filenames (non-core)
Examples observed and curated (subset):
- `termps.php`, `thoms.php`, `lock360.php`, `simpleshell.php`, `simpleshellusingbase64.php`, `r00t.php`, `gifclass*.php`, `bless*.php`, `wp-l0gin.php`, `wp-l0g1n.php`, `wp-sigunq.php`, `wp-theme.php`, `wp-scripts.php`, `wp-editor.php`, `inputs.php`, `hplfuns.php`, `memberfuns.php`, `moddofuns.php`, `onclickfuns.php`, `jmfi2.php`, `find_dm.php`, `bb3.php`, `qa.php`, `320653_new_file_G1.php`.

### 3.2 Malicious `.htaccess` pattern (deny-all → allowlist backdoors)
- `FilesMatch ".(py|exe|php)$"  → Deny from all`
- Followed by a second `FilesMatch` **allow-listing** attacker-chosen PHP names (including backdoors and select WP core admin files to keep the UI “working”).  
- Optionally appended with a standard-looking WordPress rewrite block to look legitimate.

### 3.3 Malicious code markers (content)
Common strings/techniques:
- `base64_decode(`, `gzinflate(`, `str_rot13(`, `eval(`, `assert(`, `preg_replace(.* /e`, `create_function(`  
- Process/OS command invocations: `shell_exec(`, backticks `` `...` ``, `passthru(`, `popen(`, `proc_open(`, `system(`  
- Network fetch: `curl_init(`, `curl_exec(`, `fsockopen(`, remote URL patterns (e.g., `raw.githubusercontent.com/.../simplecmdandbackdoor`)  
- Cloaking/user-agent checks and conditional redirects.

## 4) Root Cause (probable vectors)

- Outdated core, themes, or plugins with known RCE/LFI/Upload bugs.
- Weak file perms and ownership allowing webserver/other users to write into site trees.
- Admin panel/plugin endpoints left reachable post-auth or with weak credentials.
- Reuse of credentials or exposed `wp-config.php` leaking DB/API secrets.

## 5) Containment & Mitigation Actions (performed)

1. **Isolation:** rename `public_html` → `public_html0` to stop serving compromised code.
2. **Permissions reset:** remove executables; set files `664`, dirs `775`; correct ownership to `myuser:myuser`.
3. **Quarantine:** move suspicious `.htaccess*` and non-core PHP to a safe area for forensics.
4. **Baseline & scan:**
   - Generate per-domain baselines (`fixed-<domain>.csv`) from known-good or vendor packages.
   - Filename scan with curated lists (hacker / var).
   - Content scan for malicious patterns (PHP default).
5. **Restore:** only after scans pass, re-seed core WordPress files, then redeploy to `/home2/wkarshat/public_html`.

## 6) Operational Notes (paths & focus)

- **Scan the account root** `/home2/wkarshat` (malicious `.htaccess` exists **above** site roots).
- Treat `/home2/wkarshat/public_html0` as the live target for cleaning.  
- The newly recreated `/home2/wkarshat/public_html` is empty/fresh; do not treat it as “clean content.”

---

## 7) Recovery Playbook (high-level, deterministic)

1. **Disable serving**: keep using `public_html0` as the hidden tree until clean.
2. **Normalize `.htaccess`**:
   - Find and quarantine non-standard `.htaccess*` anywhere under `/home2/wkarshat`.
   - Restore canonical WordPress `.htaccess` **only in WP roots**.
3. **Filename scan** (account-wide):
   - Flag **non-core** (hacker list) and **ambiguous** (var list) files.
4. **Content scan** (PHP default):
   - Use a strong patterns list; escalate to `--all` only for targeted sweeps.
5. **Integrity check against baselines**:
   - `fixed-<domain>.csv` generated from clean sources or known-good trees.
6. **Re-seed core** files, verify `wp-config.php`, salts, and keys; force re-auth logins.
7. **Rotate secrets**: DB user/pass, salts, app keys; invalidate active sessions.

---

## 8) FindFiles Toolkit (Implementation & Usage)

> This section consolidates the former `FindFiles.md` documentation. The scripts live together and source `common.sh`.

### 8.1 Files
- `common.sh` — shared helpers (portable `sha256`, `stat`, list parsing, compound `find` expr).
- `find_scan.sh` — **filename** scanner using one or more `--list` files (one `find` per list/target).
- `scan_pat.sh` — **content** scanner (default PHP). Modes: `per-file` (compact) or `per-pattern` (triage).
- `make_fixed.sh` — build `fixed-<domain>.csv` with `filename,relative_path,size,sha256`.
- `check_fixed.sh` — verify a baseline CSV vs a target directory; outputs CSV status.
- `run_audit.sh` — orchestration wrapper (find → patterns → integrity) for one or many targets.

### 8.2 Quick start
```bash
cd /home2/wkarshat/tools

# filename scans
./find_scan.sh --list ./hacker /home2/wkarshat/public_html0
./find_scan.sh --list ./var    /home2/wkarshat/public_html0

# content scan (PHP only)
./scan_pat.sh --pat ./pat.txt --php /home2/wkarshat/public_html0

# per-domain baseline (example)
./make_fixed.sh --depth 1 --outdir ./fixed /home2/wkarshat/public_html0/daoside.com

# verify integrity against baseline
./check_fixed.sh --file ./fixed/fixed-daoside.com.csv --target /home2/wkarshat/public_html0/daoside.com

# one-shot audit
./run_audit.sh /home2/wkarshat/public_html0
```

### 8.3 Inputs (lists & patterns)
- **Filename lists:** `hacker` (non-core, high-confidence), `var` (ambiguous; review context).
- **Content patterns:** `pat.txt` (PCRE). Blank lines / `#` comments ignored. Newlines inside a pattern are rejected.

### 8.4 Output formats
- `find_scan.sh` — plain file paths (one per line).
- `scan_pat.sh --mode per-file` — `path  idx1 idx2 ...` (pattern indexes from `pat.txt`).
- `scan_pat.sh --mode per-pattern` — grouping by pattern: `Pattern N: <text>` then matching paths.
- `check_fixed.sh` — CSV: `status,relative_path,details` (`OK|MISSING|SIZE_MISMATCH|HASH_MISMATCH`).

---

## 9) Appendix A — Canonical WordPress `.htaccess`

Use only in site roots (not above the webroot):

```apache
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
```

---

## 10) Appendix B — Sample Malicious `.htaccess` Behavior (Observed)

Pattern used by attacker:
1) **Deny** most PHP execution:
```
<FilesMatch ".(py|exe|php)$">
  Order allow,deny
  Deny from all
</FilesMatch>
```
2) **Allowlist** specific PHP names (includes their backdoors and select WP admin files).
3) Append standard WP rewrites for camouflage.

**Action:** quarantine all non-canonical `.htaccess*`, then restore the canonical block per site root.

---

## 11) Appendix C — Example Content Patterns (`pat.txt` subset)

```
base64_decode(
gzinflate(
str_rot13(
eval\s*\(
assert\s*\(
preg_replace\s*\(.*/e
create_function\s*\(
shell_exec\s*\(
`[^`]*`
passthru\s*\(
popen\s*\(
proc_open\s*\(
system\s*\(
curl_exec\s*\(
curl_init\s*\(
fsockopen\s*\(
raw\.githubusercontent\.com/.*/simplecmdandbackdoor
@eval\(\$_SERVER\['HTTP_[A-Z0-9_]+'\]\)
```

---

## 12) Post-restoration Hardening (minimum)

- Keep all sites on **current WP** with automatic minor updates.
- Use **least-privilege** FS permissions (files 664, dirs 775) and correct ownership.
- Restrict admin access (IP allowlist or SSO), disable file editing in `wp-config.php`:
  ```php
  define('DISALLOW_FILE_EDIT', true);
  define('DISALLOW_FILE_MODS', true);
  ```
- Rotate DB creds and salts; remove leftover tools (`adminer.php`, `phpinfo.php`).
- WAF (even basic) and **off-site backups** tested for restore.

---

*This consolidated document replaces the previous `WPhack.md`, with the former `FindFiles.md` content embedded as Section 8.*
