-- Create a random password for reactive-resume user: openssl rand -hex 16
CREATE USER "reactive-resume_app" WITH PASSWORD 'your_secure_password';
CREATE DATABASE "reactive-resume" OWNER "reactive-resume_app";
GRANT ALL PRIVILEGES ON DATABASE "reactive-resume" TO "reactive-resume_app";
