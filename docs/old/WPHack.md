# WPHack.md — Incident, Mitigations, Action Plan

> Purpose: One-stop, execution-first guide to restore multiple compromised WordPress sites with no backups, prevent reinfection, and harden. Keeps precise steps, sequencing, tool usage, and data lists. Avoids losing any critical detail from earlier documents.

---

## Incident summary

- Account path: /home2/wkarshat
- Legacy compromised trees: public_html0/<domain> for each site
- New clean tree: public_html recreated by the panel
- Observed impact: malicious .htaccess under and above site roots, large scale PHP additions and replacements, crawler blocking, 403, stalls
- Immediate actions executed: isolate legacy tree by renaming, reset ownership and permissions, remove executable bits, quarantine .htaccess, begin filename and content scans, start building integrity baselines

Do not copy any PHP from legacy trees. Extract content and media only.

---

## Initial mitigations

1. Quarantine legacy paths so web server cannot execute them
2. Search and neutralize htaccess above site roots
   ```bash
   find /home2/wkarshat -type f -name '.htaccess*' -print
   grep -RInE 'FilesMatch|php_value|Deny from all' /home2/wkarshat | sed -n '1,200p'
   ```
   Replace malicious files. Keep canonical WordPress htaccess only in site roots.
3. Prepare clean targets per domain under public_html
4. Rotate shared secrets that apply account-wide

---

## Paths per domain

### Path A Clean rebuild to new target

Use this when a fresh environment per site is acceptable. This path gives the lowest reinfection risk and fastest reliable outcome.

**Sequence**
1. Prepare clean target
2. Baseline hardening
3. Sanity checks on legacy
4. Export content from legacy
5. Import content to target
6. Recover media and regenerate thumbnails
7. Restore identity and structure
8. Validate
9. Cut over and monitor
10. Rotate credentials
11. Clean up source

### Path B Clean in place

Use only when the site must remain in the same path. Expect higher diligence. Replace code in place from clean sources, then proceed as in Path A.

**Sequence**
1. Isolate the site from the web server
2. Replace core theme plugin code with clean copies
3. Baseline hardening
4. Sanity checks on legacy content and uploads
5. Validate structure and options
6. Re-enable site and monitor
7. Rotate credentials
8. Clean residual artifacts

---

## Action plan per domain

### Prepare clean target
```bash
mkdir -p /home2/wkarshat/public_html/<domain>
cd       /home2/wkarshat/public_html/<domain>
wp core download --locale=en_US
wp config create --dbname=DB --dbuser=USER --dbpass='PASS' --dbhost=localhost --skip-check
wp core install --url=https://stg.<domain> --title="<Domain>"   --admin_user=admin --admin_password='STRONG' --admin_email=you@example.com
wp theme install twentytwentyfive --activate
wp plugin install limit-login-attempts-reloaded --activate
wp plugin update --all
```

### Baseline hardening
```php
// wp-config.php
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
```
```bash
wp config shuffle-salts
wp option update home   'https://<domain>'
wp option update siteurl 'https://<domain>'
wp plugin auto-updates enable --all
wp theme  auto-updates enable --all
find . -type d -exec chmod 775 {} \;
find . -type f -exec chmod 664 {} \;
```

### Sanity checks on legacy
```bash
# filenames
./tools/find_scan.sh --quiet --list ./tools/hacker --list ./tools/var /home2/wkarshat/public_html0/<domain>
# content
./tools/scan_pat.sh --pat ./tools/pat.txt --php /home2/wkarshat/public_html0/<domain>
# canonical htaccess in new site root
cat > ./.htaccess <<'HT'
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
HT
```

### Export content
```bash
# if admin accessible on legacy
wp export --dir=/tmp/exports --skip_comments --max_file_size=100MB

# if admin blocked but WP-CLI works
wp user create tempadmin tempadmin@<domain> --role=administrator --user_pass='STRONG'
wp export --dir=/tmp/exports --skip_comments --max_file_size=100MB
```

### Import content
```bash
wp import /tmp/exports/*.xml --authors=create
wp term recount all
wp rewrite flush --hard
```

### Database only route
```bash
mysqldump -uUSER -pPASS DB   wp_posts wp_postmeta wp_terms wp_term_taxonomy wp_term_relationships > /tmp/posts.sql
wp db import /tmp/posts.sql
wp search-replace 'http://old.<domain>' 'https://<domain>' --all-tables
wp rewrite flush --hard
```

### Media recovery
```bash
scp -r user@old:/path/to/wp-content/uploads ./uploads-old
find ./uploads-old -type f ! -iregex '.*\.(jpg|jpeg|png|gif|webp|svg|pdf)$' -delete
rsync -a ./uploads-old/ ./wp-content/uploads/
find ./wp-content/uploads -type f -name '*.php' -delete
wp media regenerate --yes
```

### Restore identity and structure
```bash
# read from legacy when available
wp option get blogname
wp option get blogdescription
wp option get permalink_structure

# apply to target
wp option update blogname "<Site Title>"
wp option update blogdescription "<Tagline>"
wp rewrite structure '/%postname%/'
wp menu create "Main Menu"
wp menu item add-custom "Main Menu" "Home" https://<domain>/
```

### Validation
```bash
curl -I https://<domain>/
curl -I https://<domain>/wp-login.php
curl -sSL https://<domain>/sitemap.xml | head
```

### Cutover and monitor
- Lower DNS TTL and switch records
- Verify SSL and pages
- Enable uptime monitoring
```bash
url="https://<domain>"; code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
[ "$code" -eq 200 ] || mail -s "UPTIME ALERT $code $url" you@example.com <<< "Check $url"
```

### Rotate credentials
```bash
wp config shuffle-salts
wp user update admin --user_pass='NEW-STRONG-PASSWORD'
wp config set DB_PASSWORD 'NEW-DB-PASS' --raw
```

### Clean up source
- Archive legacy tree for a short evidence window
- Remove execute permissions and web access permanently

---

## Per-domain customization

- Legacy path
- Clean path
- Database changes
- Theme set to reinstall
- Plugin set to reinstall
- Users and roles to keep
- Special endpoints and webhooks
- Search and replace pairs
- Menu items to recreate
- DNS and SSL status
- Monitoring recipient list

---

## Tools

All scripts are expected under ./tools next to the lists hacker var pat.txt

### find_scan.sh
- Purpose: scan filenames using one or more lists
- Flags: --list FILE repeatable, --case sensitive|insensitive default sensitive, --quiet
- Examples:
```bash
./tools/find_scan.sh --quiet --list ./tools/hacker /home2/wkarshat/public_html0
./tools/find_scan.sh --list ./tools/var /home2/wkarshat/public_html0/<domain>
```

### scan_pat.sh
- Purpose: scan file contents for malware patterns
- Defaults: PHP only with --php, use --all for all text
- Modes: --mode per-file prints path and pattern indices, --mode per-pattern prints pattern then files
- Examples:
```bash
./tools/scan_pat.sh --pat ./tools/pat.txt --php /home2/wkarshat/public_html0
./tools/scan_pat.sh --pat ./tools/pat.txt --mode per-pattern /home2/wkarshat/public_html0/<domain>
```

### make_fixed.sh
- Purpose: build baseline CSV from clean site
- Output: filename,relative_path,size,sha256 with relative_path '.' for root
- Flags: --depth N with 0 meaning unlimited, --outdir DIR
- Example:
```bash
./tools/make_fixed.sh --depth 1 --outdir ./tools/fixed /home2/wkarshat/public_html/<domain>
```

### check_fixed.sh
- Purpose: verify target against baseline
- Output: status,relative_path,details
- Exit code nonzero on mismatch
- Example:
```bash
./tools/check_fixed.sh --file ./tools/fixed/fixed-<domain>.csv --target /home2/wkarshat/public_html/<domain>
```

### run_audit.sh
- Purpose: orchestrate filename, content, integrity checks
- Example:
```bash
./tools/run_audit.sh --hacker ./tools/hacker --var ./tools/var   --pat ./tools/pat.txt --fixdir ./tools/fixed   /home2/wkarshat/public_html0/<domain>
```

### Monitoring
- Options: UptimeRobot, BetterUptime, StatusCake
- Shell example shown under Cutover and monitor

---

## Data

### hacker
- Filenames that are treated as malicious and non-core
- One filename per line, exact matches, case rules from find_scan.sh

### var
- Filenames that are legitimate only in specific paths
- Use to catch out-of-place copies

### pat.txt
- One regex per line, blank lines and # comments ignored, no multiline patterns
- Pattern index equals line number after filtering
- Include error suppression, external fetch loaders, header sourced exec, exec on variable, obfuscation, gzinflate base64 chains

### fixed CSV
- Fields: filename,relative_path,size,sha256
- Generate from clean site with make_fixed.sh
- Verify with check_fixed.sh
- Store under tools/fixed and version-control

---

## Resources

- WP-CLI commands used throughout
- Optional tools such as WPScan, rclone, and hosted uptime monitors
- Use a WAF or CDN if available for perimeter rate limiting

---

## Canonical htaccess

```apache
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
```
