#!/bin/bash

echo "Databasus Restore Verification Agent credentials are provisioned inside the Databasus UI:"
echo "  1. Open https://databasus.internal.205hlab.com"
echo "  2. Navigate to: Settings -> Verification agents -> Create verification agent"
echo "  3. Copy the one-time Agent ID and Agent Token into Dockhand's encrypted vault"
echo "     (or .env for manual CLI fallback):"
echo ""
echo "     DATABASUS_AGENT_ID=<agent-uuid-from-ui>"
echo "     DATABASUS_AGENT_TOKEN=<one-time-token-from-ui>"
