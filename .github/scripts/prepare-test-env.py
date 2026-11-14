#!/usr/bin/env python3
"""
Prepares a temporary .env file for Docker Compose CI validation.
Fills blank placeholder variables from example.env with safe dummy values
so that Docker Compose parameter expansion (${VAR:?error}) succeeds during linting.
"""
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: prepare-test-env.py <example.env> <output.env.ci>")
        sys.exit(1)
    
    src = sys.argv[1]
    dst = sys.argv[2]
    
    with open(src, "r", encoding="utf-8") as f_in:
        lines = f_in.readlines()
        
    with open(dst, "w", encoding="utf-8") as f_out:
        for line in lines:
            s = line.strip()
            if s and not s.startswith("#") and "=" in s:
                k, v = s.split("=", 1)
                k, v = k.strip(), v.strip()
                if not v:
                    if "PORT" in k:
                        val = "5000"
                    elif "IP" in k:
                        val = "127.0.0.1"
                    elif "DIR" in k or "PATH" in k:
                        val = "/tmp/ci_test"
                    else:
                        val = "ci_test_dummy_value"
                    f_out.write(f"{k}={val}\n")
                else:
                    f_out.write(line)
            else:
                f_out.write(line)

if __name__ == "__main__":
    main()
