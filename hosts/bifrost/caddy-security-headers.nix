
# Shared Caddy security headers for public application vhosts.
# Keep service-specific policies in the respective vhost files.
{ preload ? true }:
''
  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains${if preload then "; preload" else ""}"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
    Referrer-Policy "strict-origin-when-cross-origin"
  }
''
