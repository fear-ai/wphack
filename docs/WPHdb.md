# WPHdatabase.md

## Purpose
Comprehensive database reference for investigating, sanitizing, exporting, importing, and restoring WordPress sites during or after a compromise.  
It provides rationale, ordered runbooks, SQL queries, WP-CLI commands, and safe operating procedures for DB-only recovery and for database workflows that support full restoration.

---

## 1. Introduction and Objectives
This document consolidates all guidance needed for WordPress database recovery during incident response:
- Create safe forensic snapshots.  
- Identify DB-resident persistence mechanisms.  
- Extract and sanitize data for clean imports.  
- Rotate credentials and verify integrity.  
- Support DB-only recovery when the file system is compromised.  

All commands assume a Linux shell and access to `mysql` or `wp-cli`.

---

## 2. Key Assumptions and Risks
- The database may contain PHP payloads or serialized malware.  
- Direct editing of serialized PHP data can corrupt it. Always unserialize → clean → reserialize.  
- Always work on a copy — never on production.  
- Restrict access and rotate credentials after every recovery.  

---

## 3. Safety First: Snapshots and Access Controls
Before any destructive operation, capture immutable snapshots.

**Filesystem snapshot**
```bash
tar -cjf /tmp/uploads-$(date +%F).tar.bz2 wp-content/uploads


Database snapshot

mysqldump --single-transaction --quick --skip-lock-tables -u DBUSER -p DBNAME > /tmp/DBNAME-$(date +%F).sql


Move these to secure storage and set chmod 600.

## 4. Ordered 8-Step Database Runbook
A repeatable high-level process:

1. **Snapshot** — dump DB and filesystem for forensics.  
2. **Provision staging** — clean WP install with new DB.  
3. **Export** — posts, users, settings, media.  
4. **Sanitize** — remove injections and serialized payloads.  
5. **Import** — to staging.  
6. **Verify** — check integrity, run pattern scans.  
7. **Promote** — rotate secrets, update DNS/SSL, go live.  
8. **Monitor** — 30-day heightened scanning.

---

## 5. Rotate Database User Password
### Safe rotation procedure
1. **Create new user**
```sql
CREATE USER 'wpuser_new'@'localhost' IDENTIFIED BY 'newpass';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
ON `DBNAME`.* TO 'wpuser_new'@'localhost';
FLUSH PRIVILEGES;


2. Update wp-config.php

wp config set DB_USER wpuser_new --type=constant
wp config set DB_PASSWORD newpass --type=constant


3. Verify

wp db check


Remove old user

DROP USER 'wpuser_old'@'localhost';
FLUSH PRIVILEGES;

6. Database Hygiene
6.1 Quick checks
SHOW TABLE STATUS FROM DBNAME;
SELECT option_name, LENGTH(option_value) AS len
FROM wp_options WHERE autoload='yes'
ORDER BY len DESC LIMIT 20;


Large autoload entries or any <?php tags are suspect.

6.2 Suspicious content searches
SELECT option_name FROM wp_options
 WHERE option_value LIKE '%<?php%' OR option_value LIKE '%eval(%';
SELECT post_id, meta_key FROM wp_postmeta
 WHERE meta_value LIKE '%base64_%';

6.3 User & role validation
SELECT ID,user_login,user_email FROM wp_users;
SELECT user_id,meta_key,meta_value FROM wp_usermeta
 WHERE meta_key='wp_capabilities';

6.4 Cron check
SELECT option_value FROM wp_options WHERE option_name='cron';


Inspect serialized callbacks.

7. Database-Only Recovery Route

Used when WP code is unrecoverable but DB remains.

Dump DB with mysqldump.

Create new clean DB and WP install.

Import or re-create content:

wp export → .xml → wp import

or SQL extraction for posts, users, postmeta.

Recreate settings manually.

Verify, then deploy.

Example

mysql -uroot -p -e "CREATE DATABASE cleanDB;"
wp config create --dbname=cleanDB --dbuser=newuser --dbpass=newpass
wp core install --url=staging.example.com --title="Recovered Site" \
  --admin_user=admin --admin_password=TempPass --admin_email=you@example.com
wp import /tmp/export.xml --authors=create

8. Finding Persistence and IOCs
SELECT option_name FROM wp_options
 WHERE option_value LIKE '%base64_%'
    OR option_value LIKE '%gzinflate(%'
    OR option_value LIKE '%eval(%';


Also inspect:

active_plugins

cron serialized field

wp_usermeta for hidden admin roles

9. Exporting and Importing Safely

Full snapshot

mysqldump -u DBUSER -p DBNAME > /secure/dbdump.sql


Selective export

wp export --post_type=page --dir=/tmp/export


Import

wp import /tmp/export/*.xml --authors=create


Verification

wp db check
wp option get siteurl

10. Handling Serialized Data

Never regex-edit serialized strings.

Safe PHP sanitizer
<?php
function clean($v){
  if(is_string($v) && preg_match('/<\\?php|eval\\(|base64_/i',$v))
    return '';
  if(is_array($v))
    foreach($v as $k=>$x) $v[$k]=clean($x);
  return $v;
}
$opt = unserialize($raw);
$opt = clean($opt);
$new = serialize($opt);
?>

11. Sanitization Techniques

Export suspicious options:

mysql -u DBUSER -p DBNAME -e "
  SELECT option_id, option_name FROM wp_options
   WHERE option_value LIKE '%eval(%' OR option_value LIKE '%<?php%';"


Use the PHP sanitizer above.

Review and re-import sanitized entries.

12. Mapping DB to Sites

Identify DB prefix and URL mappings.

grep table_prefix wp-config.php


For multisite:

SELECT blog_id,domain,path FROM wp_blogs;

13. Cron and Scheduled Events

List due cron tasks:

wp cron event list --due-now


Remove suspicious entries:

wp cron event delete <hook>

14. Automation Examples

Find suspicious options

mysql -uDBUSER -pDBPASS -N -e "
 SELECT option_name FROM wp_options
 WHERE option_value LIKE '%<?php%' OR option_value LIKE '%eval(%';" DBNAME


List plugin and site info

wp option get active_plugins --format=json
wp option get siteurl

15. Validation and Monitoring

After import and cleanup:

Pages load without errors.

scan_pat.sh shows no hits.

Autoload entries small and benign.

No unknown users or cron jobs.

Rotate DB and WP salts (wp config shuffle-salts).

Weekly integrity checks for a month.

16. References

WP-CLI Documentation

WordPress.org Editing wp-config

PHP Serialization Manual
## 16. References

- [WP-CLI Documentation](https://developer.wordpress.org/cli/)  
  Official command-line interface for WordPress. Includes reference for `wp db`, `wp config`, `wp export`, and `wp cron`.

- [WordPress.org: Editing wp-config.php](https://codex.wordpress.org/Editing_wp-config.php)  
  Canonical guidance on WordPress configuration constants, database credentials, and salts.

- [PHP Serialization Manual](https://www.php.net/manual/en/function.serialize.php)  
  Detailed explanation of PHP’s `serialize()` / `unserialize()` mechanisms — crucial for cleaning and validating database option values.

- [WordPress Database Description](https://developer.wordpress.org/reference/database-description/)  
  Schema reference for tables such as `wp_options`, `wp_postmeta`, and `wp_users`.

- [Hardening WordPress Guide](https://wordpress.org/support/article/hardening-wordpress/)  
  Security recommendations covering database access, file permissions, and cron tasks.

- [MySQL Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/)  
  Command syntax and best practices for SQL security, privileges, and backups.

- [WPScan Vulnerability Database](https://wpscan.com/)  
  Searchable database of WordPress-related vulnerabilities for plugins, themes, and core versions.

