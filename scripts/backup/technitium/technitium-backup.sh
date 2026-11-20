#!/bin/bash

# Check input file  
if [ $# -eq 0 ]; then
  echo "Usage: $0 <dns.txt>" 
  exit 1
fi

# Configurable value for zip file suffix 
SUFFIX="daily"

# Get input file
DNS_FILE=$1

# Read lines
while read -r line; do
  HOSTNAME=$(echo $line | cut -d',' -f1)
  IP=$(echo $line | cut -d',' -f2)
  TOKEN=$(echo $line | cut -d',' -f3)
  
  # Construct API URL with IP and token, change any unwanted settings below to false as documented in https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#backup-settings
  URL="http://$IP:5380/api/settings/backup?token=$TOKEN&blockLists=true&logs=true&scopes=true&apps=true&stats=true&zones=true&allowedZones=true&blockedZones=true&dnsSettings=true&logSettings=true&authConfig=true"
  

  # Construct output file name 
  FILE_NAME=$HOSTNAME-$IP-$(date +%Y%m%d)-$SUFFIX.zip

  # Call API
  curl $URL -o $FILE_NAME  
done < $DNS_FILE