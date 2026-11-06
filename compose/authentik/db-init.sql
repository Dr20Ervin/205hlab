-- Create a random password for the authentik user: openssl rand -hex 16
CREATE USER authentik WITH PASSWORD 'your_secure_password';
CREATE DATABASE authentik OWNER authentik;
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;