-- Create a random password for speedtest user: openssl rand -hex 16
CREATE USER speedtest_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE speedtest_tracker OWNER speedtest_app;
GRANT ALL PRIVILEGES ON DATABASE speedtest_tracker TO speedtest_app;
