-- Create a random password for vikunja user: openssl rand -hex 16
CREATE USER vikunja_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE vikunja OWNER vikunja_app;
GRANT ALL PRIVILEGES ON DATABASE vikunja TO vikunja_app;
