#!/bin/bash

# Configuration
OUTPUT_FILE="/var/www/html/index.html" # We'll name it index.html to be the default
SERVER_TIMEZONE="America/Detroit" # Set your timezone for date output

# --- Collect System Information ---

# Date and Time
CURRENT_DATE=$(TZ="$SERVER_TIMEZONE" date +"%A, %B %d %Y")
CURRENT_TIME=$(TZ="$SERVER_TIMEZONE" date +"%H:%M:%S") # Added seconds for more real-time feel

# Disk Space (for /)
# Using `df -B1` for bytes, and then parsing.
# For total, used, available, percentage on the root filesystem
DF_OUTPUT=$(df -B1 / | awk 'NR==2 {print $2, $3, $4, $5}')
TOTAL_BYTES=$(echo "$DF_OUTPUT" | awk '{print $1}')
USED_BYTES=$(echo "$DF_OUTPUT" | awk '{print $2}')
AVAILABLE_BYTES=$(echo "$DF_OUTPUT" | awk '{print $3}')
USAGE_PERCENTAGE=$(echo "$DF_OUTPUT" | awk '{print $4}' | sed 's/%//') # Remove % sign

# Convert bytes to a more readable format (MB, GB, etc.) - Bash doesn't do floats easily
TOTAL_SPACE_GB=$(echo "scale=2; $TOTAL_BYTES / (1024*1024*1024)" | bc)
USED_SPACE_GB=$(echo "scale=2; $USED_BYTES / (1024*1024*1024)" | bc)
AVAILABLE_SPACE_GB=$(echo "scale=2; $AVAILABLE_BYTES / (1024*1024*1024)" | bc)

# Memory Information (from /proc/meminfo)
MEMTOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMAVAILABLE_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

# CPU Information (from /proc/cpuinfo)
NUM_PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
CPU_MHZ=$(grep "cpu MHz" /proc/cpuinfo | head -n 1 | awk '{print int($4)}') # Get integer part

# System Uptime and Load Averages
UPTIME_INFO=$(uptime)

# Username of script runner (will be 'root' if run by cron as root, or 'www-data' if run via web)
RUN_BY_USER=$(whoami)

# --- Generate HTML Output ---
cat <<EOF > "$OUTPUT_FILE"
<!DOCTYPE html>
<html>
<head>
    <title>My System  Status Report</title>
    <meta http-equiv="refresh" content="60"> <style>
        body {
            font-family: monospace;
            background-color: #222;
            color: #eee;
            margin: 20px;
        }
        pre {
            background-color: #333;
            border: 1px solid #555;
            padding: 10px;
            overflow-x: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        hr {
            border: 0;
            height: 1px;
            background-image: linear-gradient(to right, rgba(0, 0, 0, 0), rgba(255, 255, 255, 0.75), rgba(0, 0, 0, 0));
            margin: 20px 0;
        }
        .section-title {
            font-size: 1.2em;
            font-weight: bold;
            color: #0f0;
            margin-bottom: 10px;
        }
        .usage-percentage {
            color: #ff0;
        }
        footer {
            margin-top: 30px;
            font-size: 0.8em;
            text-align: center;
            color: #aaa;
        }
    </style>
</head>
<body>

    <h1>My System Status - Generated Report</h1>
    <hr>

    <p class="section-title">Disk Space Information (Root Filesystem)</p>
    <pre>
      Used Space       : ${USED_BYTES} bytes (${USED_SPACE_GB} GB)
      Available Space  : ${AVAILABLE_BYTES} bytes (${AVAILABLE_SPACE_GB} GB)
      <span class="usage-percentage">Usage Percentage : ${USAGE_PERCENTAGE}%</span>
      Total disk space : ${TOTAL_BYTES} bytes (${TOTAL_SPACE_GB} GB)
    </pre>
    <hr>

    <p class="section-title">Memory Information</p>
    <pre>
The system has ${NUM_PROCESSORS} Processors
The average CPU speed is ${CPU_MHZ} MHz
The system has ${MEMTOTAL_KB} kB of total memory
The system has ${MEMAVAILABLE_KB} kB of available memory
    </pre>
    <hr>

    <p class="section-title">System Uptime and Load Average</p>
    <pre>
${UPTIME_INFO}
    </pre>
    <hr>

    <p>Run by: ${RUN_BY_USER}</p>
    <hr>

    <footer>
        <p>Page assembled ${CURRENT_DATE} - ${CURRENT_TIME} EDT</p>
    </footer>

</body>
</html>
EOF

# Set proper permissions for the generated HTML file
chmod 644 "$OUTPUT_FILE"
chown www-data:www-data "$OUTPUT_FILE" # Ensure Apache can read it

echo "Generated '$OUTPUT_FILE' successfully."
