# WordPress Fix and Hardening Plan

## 1. Incident Overview

Following discovery of multiple compromised WordPress instances, a coordinated cleanup and hardening effort is required.  
Primary symptoms included injected PHP loaders, obfuscated payloads, unexpected redirects, and foreign `.htaccess` entries.  
A structured, verifiable restoration and hardening process is essential to ensure future resilience.

---

## 2. Immediate Containment and Recovery Actions

### 2.1 Lockdown and Isolation
- Stop web traffic to infected sites temporarily (Apache `RedirectMatch`, maintenance mode, or firewall).
- Rename affected directories (e.g., `public_html → public_html0`) to prevent code execution.
- Change file ownership to the correct user and group:
  - Directories → `755`
  - Files → `644`
- Disable script execution outside controlled directories.

### 2.2 Manual File Cleanup (**authoritative**)
**This is the authoritative section for `.htaccess` cleanup and replacement. All later mentions reference this.**
- Delete all non-essential or foreign `.htaccess` files across the tree (root and subdirectories).
- Replace each **site root** `.htaccess` with the official WordPress default; then lock permissions:
  - `chmod 400 .htaccess` (root)
  - `chown <site-user>:<site-group> .htaccess`
- For **subdirectories** where PHP execution must be prohibited (e.g., `/wp-content/uploads/`, custom caches, exports):
  - Place a deny rule (see §3.3 for the directive and scope).  
- Retain only verified core files (validated by checksum or clean download).

### 2.3 Key and Secret Rotation
- Regenerate SSL private keys, salts, and application secrets.
- Replace `AUTH_KEY`, `SECURE_AUTH_KEY`, and other salts in `wp-config.php`:
  ```bash
  wp config shuffle-salts
  ```

---

## 3. Restoration and Preparation

### 3.1 New File Structure
Establish a clean directory structure:

```
~/public_html/
├── wp-admin/
├── wp-content/
└── wp-includes/
```

Copy back only verified content from previous installation (`wp-content/uploads`, sanitized themes, and plugins).

### 3.2 Core Installation
Reinstall WordPress core directly from source:

```bash
wp core download --force
```

Verify version integrity using official SHA1 checksums.

### 3.3 Permissions and Ownership (**authoritative**)
**This is the authoritative section for baseline permissions and the uploads PHP-execution block. Later mentions reference this.**
Apply principle of least privilege:

```bash
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
```

**Disallow PHP execution in `/wp-content/uploads/` and other user-writable paths** (e.g., `/wp-content/cache/`, `/wp-content/efl-exports/`) via `.htaccess`:

```apache
<FilesMatch "\.php$">
    deny from all
</FilesMatch>
```

- Place this file in each user-writable directory that must not execute PHP.
- If using **Nginx**, translate to equivalent location blocks (fastcgi_pass disabled for these paths).

---

## 4. Database Actions and Recovery

Database operations are critical to both containment and restoration.  
Full operational details and SQL procedures are documented separately in **`WPHdatabase.md`**.

### 4.1 Objectives
- Capture forensic snapshots before modifications.  
- Identify and remove injected payloads in options or meta tables.  
- Rebuild clean sites using sanitized exports.  
- Rotate credentials and enforce least privilege.

### 4.2 Key Practices
- Snapshot before change (`mysqldump` or `wp db export`).  
- Work from staging — never alter production directly.  
- Monitor autoloads for large or executable `wp_options` entries.  
- Audit users and roles to remove rogue admin accounts.  
- Restore only verified tables and data.

### 4.3 Database Integration
- Confirm that each site directory maps to the correct DB prefix.  
- Verify credentials in `wp-config.php` reference the cleaned DB copy.  
- Maintain mapping: **DB name → site path → credentials**.

### 4.4 Credential Rotation
After verification:
- Create a new DB user with minimal privileges.
- Update credentials in `wp-config.php` (`DB_USER`, `DB_PASSWORD`).
- Drop obsolete users once confirmed.

(See **`WPHdatabase.md §5`** for SQL examples.)

### 4.5 Database-Only Recovery
If code is lost but DB data is intact, follow the **Database-Only Route** in `WPHdatabase.md` for export/import and sanitization.

### 4.6 Post-Restoration Validation (**authoritative**)
**This is the authoritative section for validation/monitoring tasks. Later mentions reference this for details.**
- Run `scan_pat.sh` to detect injected code.
- Verify autoload size and content.
- Rotate salts, test admin login, and audit cron entries.
- Log every database change.
- Confirm scheduled tasks (WP-Cron and system cron) are correct and not spawning malicious jobs.
- Validate plugin/theme integrity against clean sources or checksums.

---

## 5. Filesystem Verification and Patterns

### 5.1 Pattern Detection Overview
All detection uses predefined pattern data and scanning scripts:

- `patshort.txt` — Minimal high-confidence indicators.  
- `patall.txt` — Comprehensive signatures (obfuscation, encoding, SEO redirects, etc.).

See **`Patterns.md`** for details and examples.

### 5.2 Running the Scans
```bash
./find_scan.sh --list hacker ~/public_html0/
./scan_pat.sh ~/public_html0/ > scan.log
```

Investigate flagged files manually; replace with verified copies from WordPress core.

---

## 6. Access and `.htaccess` Management

### 6.1 Root-Level `.htaccess` (see §2.2 for authority)
- **Reference:** Follow the cleanup, replacement, and permission-locking workflow defined in **§2.2**.  
- **Addition:** After restoration, re-check any **multisite** rewrites, custom caching layers, or reverse proxy headers that need to be reintroduced safely.

### 6.2 Upload Directory Protection (see §3.3 for authority)
- **Reference:** Apply the **uploads and other user-writable path** PHP-block rule from **§3.3**.  
- **Addition:** If running on **Nginx**, ensure equivalent rules are present in the server config and **not** overridden by higher-priority include files.

### 6.3 Optional Hardening Directives
```apache
Options -Indexes
Header set X-Content-Type-Options "nosniff"
Header set X-Frame-Options "SAMEORIGIN"
```

### 6.4 SSL and HTTPS Enforcement
Force secure connections site-wide:

```apache
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

---

## 7. Hardening

### 7.1 PHP and Server Configuration
- Disable dangerous PHP functions (`exec`, `shell_exec`, `passthru`, `system`).
- Limit upload size and execution time.
- Enable `open_basedir` restrictions.

### 7.2 WordPress Hardening
- Allow plugin installation only from vetted sources.
- Remove unused themes and plugins.
- Enforce automatic core and plugin updates.
- Install a file integrity monitor (Wordfence, MalCare, or custom diff scanner).

### 7.3 Permissions and Ownership Checks
- **Reference:** Baseline settings are defined in **§3.3**.  
- **Addition:** Run periodically to detect drift:
  ```bash
  find . -type d ! -perm 755 -print
  find . -type f ! -perm 644 -print
  ```

---

## 8. Monitoring and Maintenance (references §4.6)
- **Reference:** Follow validation/monitoring tasks in **§4.6**.  
- **Additions for ongoing ops:**  
  - Schedule weekly pattern scans for 30 days post-restoration, then monthly.  
  - Maintain audit logs of user logins, file changes, and cron events.  
  - Backup DB and site files regularly; test restore quarterly.

---

## 9. Tools

Scripts supporting this plan:

| Script | Purpose |
|--------|----------|
| `find_scan.sh` | Pattern-based file search |
| `scan_pat.sh` | Content pattern matching |
| `run_audit.sh` | Summarizes findings and status |
| `make_fixed.sh` | Rebuilds directory tree from verified sources |
| `check_fixed.sh` | Compares fixed vs. infected states |
| `common.sh`, `common_wph.sh` | Shared logic and environment setup |

Usage examples are documented in the **Tools Appendix**.

---

## 10. Per-Domain Recovery Plans

Each domain may require its own path based on:
- Database state (intact vs. corrupted)
- File backup availability
- Level of custom plugin/theme modification

**Typical routes:**
- **Path A**: DB intact, code compromised → clean reinstall + import.  
- **Path B**: DB compromised → rebuild from exports or partial content.  
- **Path C**: Full reinstallation with media reimport and reconfiguration.

---

## 11. Content and Media Migration

### 11.1 Export
If WP CLI is operational:

```bash
wp export --dir=/tmp/export
```

Otherwise, manually extract:
- `/uploads/` (media)
- `wp_posts`, `wp_postmeta` (content)
- Users and options tables

### 11.2 Transfer
Use `rsync`, `scp`, or `SFTP` for controlled migration.  
Verify transfers with checksums before re-enabling uploads.

### 11.3 Reintegration
Once destination site is operational:

```bash
wp media regenerate
wp search-replace 'oldsite.com' 'newsite.com'
```

---

## 12. Validation and Final Verification (references §4.6)
- **Reference:** Use the full validation/monitoring checklist in **§4.6**.  
- **Additions for go-live:**  
  - Verify all URLs, permalinks, and redirects from multiple browsers.  
  - Ensure HTTPS enforcement and valid certificates.  
  - Confirm cron and mail functionality.  
  - Archive logs of every recovery action.

---

## 13. Appendices

### Appendix A — Patterns Reference
See **`Patterns.md`** for detailed pattern types, rationale, and sample injections.

### Appendix B — Tools
Each script includes usage notes and expected output.  
When updating any script, ensure `common.sh` and `common_wph.sh` remain synchronized.

### Appendix C — Data Files
Explain and maintain:
- `hacker` — known compromised file names  
- `var` — ambiguous names appearing in both safe and infected contexts  
- `pat.txt`, `patshort.txt`, `patall.txt` — pattern data for scanners  
- `fixed-<domain>.csv` — baseline of verified clean files

### Appendix D — Future Enhancements
- Integrate checksum-based integrity validation  
- Automate WP core replacement and DB sanitation  
- Expand pattern libraries via external threat feeds  
- Centralize logs and generate compliance reports
