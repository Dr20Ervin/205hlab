-- Create unprivileged user for Uptime Kuma healthcheck: openssl rand -hex 16
CREATE USER kuma_healthcheck WITH PASSWORD 'your_secure_password';
GRANT CONNECT ON DATABASE postgres_admin TO kuma_healthcheck;
REVOKE CREATE ON SCHEMA public FROM kuma_healthcheck;
