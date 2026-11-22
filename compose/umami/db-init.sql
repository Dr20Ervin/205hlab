-- Create a random password for the umami user: openssl rand -hex 16
CREATE USER umami_app WITH PASSWORD 'your_secure_password';
CREATE DATABASE umami OWNER umami_app;
GRANT ALL PRIVILEGES ON DATABASE umami TO umami_app;
