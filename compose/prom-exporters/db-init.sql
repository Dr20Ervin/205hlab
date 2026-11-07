-- Create user for Prometheus Postgres Exporter
CREATE USER postgres_exporter WITH PASSWORD 'your_secure_password';
GRANT pg_monitor TO postgres_exporter;
