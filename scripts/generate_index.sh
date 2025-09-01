#!/bin/bash

# Configuration
# Path where the HTML file will be generated.
# Ensure this directory exists or will be created by the script.
OUTPUT_FILE="/var/www/html/index.html" # Assuming this is the correct target path for Apache
SERVER_TIMEZONE="America/Detroit" # Set your server's timezone for date output

# --- Collect System Information ---

# Date and Time for server-side generated timestamp
CURRENT_DATE=$(TZ="$SERVER_TIMEZONE" /usr/bin/date +"%A, %B %d %Y")
CURRENT_TIME=$(TZ="$SERVER_TIMEZONE" /usr/bin/date +"%H:%M:%S")

# Determine a short timezone abbreviation for display
SERVER_TIMEZONE_SHORT=$(TZ="$SERVER_TIMEZONE" /usr/bin/date +"%Z")

# 1. Disk Space (for /)
DF_OUTPUT_ROOT=$(/usr/bin/df -B1 / | /usr/bin/awk 'NR==2 {print $2, $3, $4, $5}')
TOTAL_BYTES=$(/usr/bin/echo "$DF_OUTPUT_ROOT" | /usr/bin/awk '{print $1}')
USED_BYTES=$(/usr/bin/echo "$DF_OUTPUT_ROOT" | /usr/bin/awk '{print $2}')
AVAILABLE_BYTES=$(/usr/bin/echo "$DF_OUTPUT_ROOT" | /usr/bin/awk '{print $3}')
USAGE_PERCENTAGE=$(/usr/bin/echo "$DF_OUTPUT_ROOT" | /usr/bin/awk '{print $4}' | /usr/bin/sed 's/%//')

TOTAL_SPACE_GB=$(/usr/bin/echo "scale=2; $TOTAL_BYTES / (1024*1024*1024)" | /usr/bin/bc)
USED_SPACE_GB=$(/usr/bin/echo "scale=2; $USED_BYTES / (1024*1024*1024)" | /usr/bin/bc)
AVAILABLE_SPACE_GB=$(/usr/bin/echo "scale=2; $AVAILABLE_BYTES / (1024*1024*1024)" | /usr/bin/bc)


# 2. Memory Information (from /proc/meminfo) - Specific request: Total, Available, Used
MEMTOTAL_KB=$(/usr/bin/grep MemTotal /proc/meminfo | /usr/bin/awk '{print $2}')
MEMAVAILABLE_KB=$(/usr/bin/grep MemAvailable /proc/meminfo | /usr/bin/awk '{print $2}')
MEMUSED_KB=$((MEMTOTAL_KB - MEMAVAILABLE_KB)) # Calculated used memory

# Convert to MB for display
MEMTOTAL_MB=$(/usr/bin/echo "scale=2; $MEMTOTAL_KB / 1024" | /usr/bin/bc)
MEMAVAILABLE_MB=$(/usr/bin/echo "scale=2; $MEMAVAILABLE_KB / 1024" | /usr/bin/bc)
MEMUSED_MB=$(/usr/bin/echo "scale=2; $MEMUSED_KB / 1024" | /usr/bin/bc)


# 3. CPU Information (from /proc/cpuinfo)
NUM_PROCESSORS=$(/usr/bin/grep -c ^processor /proc/cpuinfo | tr -d '\n\r ')
CPU_MHZ=$(/usr/bin/grep "cpu MHz" /proc/cpuinfo | /usr/bin/head -n 1 | /usr/bin/awk '{print int($4)}' | tr -d '\n\r ')


# 4. System Uptime and Load Averages
UPTIME_INFO=$(/usr/bin/uptime)
# Extract load averages from uptime info
LOAD_1=$(/usr/bin/echo "$UPTIME_INFO" | /usr/bin/awk -F'load average: ' '{print $2}' | /usr/bin/awk '{print $1}' | /usr/bin/sed 's/,//' | tr -d '\n\r ')
LOAD_5=$(/usr/bin/echo "$UPTIME_INFO" | /usr/bin/awk -F'load average: ' '{print $2}' | /usr/bin/awk '{print $2}' | /usr/bin/sed 's/,//' | tr -d '\n\r ')
LOAD_15=$(/usr/bin/echo "$UPTIME_INFO" | /usr/bin/awk -F'load average: ' '{print $2}' | /usr/bin/awk '{print $3}' | tr -d '\n\r ')


# 5. User Logins (Past 5 Days)
USER_LOGIN_DATA="No user logins recorded in the past 5 days, or 'last' command output not available."

if [ -x /usr/bin/last ]
then
    LOGIN_RAW=$(/usr/bin/last -F -s -5days | /usr/bin/grep -Ev "wtmp|reboot|shutdown|system boot" | /usr/bin/head -n 20) # Limit to 20 recent logins

    if [ -n "$LOGIN_RAW" ]; then
        USER_LOGIN_DATA="<table style=\"width:100%; border-collapse: collapse; table-layout: fixed;\">" # Added table-layout: fixed
        USER_LOGIN_DATA+="<thead><tr style=\"background-color:#444;\">"
        USER_LOGIN_DATA+="<th style=\"padding: 8px; border: 1px solid #555; text-align: left; width: 15%;\">User</th>"
        USER_LOGIN_DATA+="<th style=\"padding: 8px; border: 1px solid #555; text-align: left; width: 25%;\">From (IP/TTY)</th>"
        USER_LOGIN_DATA+="<th style=\"padding: 8px; border: 1px solid #555; text-align: left; width: 30%;\">Login Time</th>"
        USER_LOGIN_DATA+="<th style=\"padding: 8px; border: 1px solid #555; text-align: left; width: 30%;\">Logout Time / Duration</th>"
        USER_LOGIN_DATA+="</tr></thead><tbody>"

        while IFS= read -r line; do
            user=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $1}')
            tty=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $2}')
            # Logic to find the IP/Hostname
            from=$(/usr/bin/echo "$line" | /usr/bin/awk '{
                if ($3 ~ /\./ || $3 == ":0" || $3 == ":1") { print $3 }
                else if ($4 ~ /\./ || $4 == ":0" || $4 == ":1") { print $4 }
                else { print $3 } # Default to $3 if no clear IP
            }')
            display_from="${tty} (${from})"

            login_time_full=$(/usr/bin/echo "$line" | /usr/bin/awk '{
                for (i=5; i<=NF; i++) {
                    if ($i ~ /^[0-9]{4}$/) { # Found year
                        for (j=i-4; j<=i; j++) printf "%s ", $j;
                        exit;
                    }
                }
            }' | /usr/bin/xargs)

            logout_info=$(/usr/bin/echo "$line" | /usr/bin/awk '{
                logout_start_idx = 0;
                for (i=5; i<=NF; i++) {
                    if ($i ~ /^[0-9]{4}$/) { # Found year, next is logout info start
                        logout_start_idx = i + 1;
                        break;
                    }
                }
                if (logout_start_idx > 0) {
                    for (i=logout_start_idx; i<=NF; i++) printf "%s ", $i;
                } else {
                    print "N/A";
                }
            }' | /usr/bin/xargs)

            # Escape HTML special characters
            user=$(/usr/bin/echo "$user" | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            display_from=$(/usr/bin/echo "$display_from" | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            login_time_full=$(/usr/bin/echo "$login_time_full" | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            logout_info=$(/usr/bin/echo "$logout_info" | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

            USER_LOGIN_DATA+="<tr>"
            USER_LOGIN_DATA+="<td style=\"padding: 8px; border: 1px solid #555;\">${user}</td>"
            USER_LOGIN_DATA+="<td style=\"padding: 8px; border: 1px solid #555;\">${display_from}</td>"
            USER_LOGIN_DATA+="<td style=\"padding: 8px; border: 1px solid #555;\">${login_time_full}</td>"
            USER_LOGIN_DATA+="<td style=\"padding: 8px; border: 1px solid #555;\">${logout_info}</td>"
            USER_LOGIN_DATA+="</tr>"
        done <<< "$LOGIN_RAW"
        USER_LOGIN_DATA+="</tbody></table>"
    fi
else
    USER_LOGIN_DATA="<p>The 'last' command is not available to retrieve user login data.</p>"
fi


# 6. Active Disk Information - Mounted Filesystems (including swap)
ACTIVE_DISK_INFO_HTML="<p>No active disk information found or suitable devices.</p>"

DF_ALL_OUTPUT=$(/usr/bin/df -hT --output=source,used,pcent,fstype,target 2>/dev/null | /usr/bin/tail -n +2)

if [ -n "$DF_ALL_OUTPUT" ]; then
    ACTIVE_DISK_INFO_HTML="<table style=\"width:100%; border-collapse: collapse; table-layout: fixed;\">" # Added table-layout: fixed
    ACTIVE_DISK_INFO_HTML+="<thead><tr style=\"background-color:#444;\">"
    ACTIVE_DISK_INFO_HTML+="<th style=\"padding: 8px; border: 1px solid #555; text-align: left; width: 40%;\">Device (Mount Point)</th>"
    ACTIVE_DISK_INFO_HTML+="<th style=\"padding: 8px; border: 1px solid #555; text-align: right; width: 30%;\">Used Space</th>"
    ACTIVE_DISK_INFO_HTML+="<th style=\"padding: 8px; border: 1px solid #555; text-align: right; width: 30%;\">Usage %</th>"
    ACTIVE_DISK_INFO_HTML+="</tr></thead><tbody>"

    /usr/bin/echo "$DF_ALL_OUTPUT" | while IFS= read -r line; do
        DEVICE=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $1}')
        USED=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $3}')
        PERCENT=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $4}')
        FSTYPE=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $2}')
        MOUNT_POINT=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $5}')

        if [[ "$FSTYPE" != "tmpfs" && \
              "$FSTYPE" != "devtmpfs" && \
              "$FSTYPE" != "squashfs" && \
              "$FSTYPE" != "cgroup" && \
              "$FSTYPE" != "overlay" && \
              "$FSTYPE" != "fuse.portal" && \
              "$FSTYPE" != "efivarfs" && \
              "$DEVICE" != "udev" && \
              "$DEVICE" != "tmpfs" && \
              "$DEVICE" != "cgroup" && \
              "$MOUNT_POINT" != "/snap"* && \
              "$MOUNT_POINT" != "/var/lib/snapd/snap"* && \
              "$MOUNT_POINT" != "/run/user"* ]]; then
            ACTIVE_DISK_INFO_HTML+="<tr>"
            ACTIVE_DISK_INFO_HTML+="<td style=\"padding: 8px; border: 1px solid #555;\">${DEVICE} (${MOUNT_POINT})</td>"
            ACTIVE_DISK_INFO_HTML+="<td style=\"padding: 8px; border: 1px solid #555; text-align: right;\">${USED}</td>"
            ACTIVE_DISK_INFO_HTML+="<td style=\"padding: 8px; border: 1px solid #555; text-align: right;\">${PERCENT}</td>"
            ACTIVE_DISK_INFO_HTML+="</tr>"
        fi
    done

    # Add swap information
    # Note: swapon might be in /sbin or /usr/sbin. Adjust path if necessary.
    SWAP_INFO=$(/usr/sbin/swapon -s) # Common path for swapon on Ubuntu
    if [ -n "$SWAP_INFO" ]; then
        /usr/bin/echo "$SWAP_INFO" | /usr/bin/tail -n +2 | while IFS= read -r line; do
            SWAP_DEVICE=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $1}')
            SWAP_USED_KB=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $3}')
            SWAP_TOTAL_KB=$(/usr/bin/echo "$line" | /usr/bin/awk '{print $2}')

            if [ "$SWAP_TOTAL_KB" -gt 0 ]; then
                SWAP_PERCENT=$(/usr/bin/echo "scale=0; ($SWAP_USED_KB * 100) / $SWAP_TOTAL_KB" | /usr/bin/bc)
            else
                SWAP_PERCENT="0"
            fi

            ACTIVE_DISK_INFO_HTML+="<tr>"
            ACTIVE_DISK_INFO_HTML+="<td style=\"padding: 8px; border: 1px solid #555;\">${SWAP_DEVICE} (swap)</td>"
            ACTIVE_DISK_INFO_HTML+="<td style=\"padding: 8px; border: 1px solid #555; text-align: right;\">${SWAP_USED_KB}K</td>"
            ACTIVE_DISK_INFO_HTML+="<td style=\"padding: 8px; border: 1px solid #555; text-align: right;\">${SWAP_PERCENT}%</td>"
            ACTIVE_DISK_INFO_HTML+="</tr>"
        done
    fi

    ACTIVE_DISK_INFO_HTML+="</tbody></table>"
fi


# 7. Recent Apache Access Log Entries
LAST_ACCESS_LOGS=$(/usr/bin/tail -n 10 /var/log/apache2/access.log 2>/dev/null | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

if [ -z "$LAST_ACCESS_LOGS" ]; then
    LAST_ACCESS_LOGS="<p>No recent Apache access log entries found or log file is inaccessible.</p>"
fi


# Username of script runner (will be 'root' if run by cron as root)
RUN_BY_USER=$(/usr/bin/whoami)


# --- Generate HTML Output ---

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# IMPORTANT: The 'EOF' is NOT quoted to allow bash to interpret '$' inside the HTML/JS block.
# IMPORTANT: Backticks (`) and dollar signs ($) that are part of JavaScript template literal syntax
# must be escaped (e.g., \` and \${) to prevent bash from interpreting them.
/usr/bin/cat <<EOF > "$OUTPUT_FILE"
<!DOCTYPE html>
<html>
<head>
    <title>Server Status Report</title>
    <meta http-equiv="refresh" content="60">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@2.2.1"></script>
    <style>
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
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th, td {
            padding: 8px;
            border: 1px solid #555;
            text-align: left;
        }
        th {
            background-color: #444;
            color: #0f0;
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
        #live-clock { /* Style for the live clock */
            font-size: 1.1em;
            font-weight: bold;
            color: #0ff; /* Cyan color */
            display: inline-block; /* Allows text around it to flow */
            min-width: 90px; /* Prevent jumping if time changes width */
        }
    </style>
</head>
<body>

    <h1>Server Status - Generated Report</h1>
    <hr>

    <p class="section-title">Memory Information</p>
    <pre>
Total Memory        : ${MEMTOTAL_MB} MB
Available Memory    : ${MEMAVAILABLE_MB} MB
Used Memory         : ${MEMUSED_MB} MB
    </pre>
    <hr>

    <p class="section-title">Disk Space Information (Root Filesystem)</p>
    <div style="display: flex; flex-wrap: wrap; justify-content: space-around; align-items: center; margin-bottom: 20px">
        <div style="flex: 1; min-width: 300px; max-width: 400px; padding: 10px; box-sizing: border-box;">
            <canvas id="diskSpaceChart"
                    data-total="${TOTAL_SPACE_GB}"
                    data-used="${USED_SPACE_GB}"
                    data-available="${AVAILABLE_SPACE_GB}">
            </canvas>
        </div>
        <div style="flex: 1; min-width: 300px; padding: 10px; box-sizing: border-box;">
            <pre style="white-space: pre-wrap; word-wrap: break-word;">
      Used Space       : ${USED_BYTES} bytes (${USED_SPACE_GB} GB)
      Available Space  : ${AVAILABLE_BYTES} bytes (${AVAILABLE_SPACE_GB} GB)
      <span class="usage-percentage">Usage Percentage : ${USAGE_PERCENTAGE}%</span>
      Total disk space : ${TOTAL_BYTES} bytes (${TOTAL_SPACE_GB} GB)
            </pre>
        </div>
    </div>
    <hr>

    <p class="section-title">Active Disk Information (Mounted Filesystems and Swap)</p>
    ${ACTIVE_DISK_INFO_HTML}
    <hr>

    <p class="section-title">User Logins (Past 5 Days)</p>
    ${USER_LOGIN_DATA}
    <hr>

    <p class="section-title">CPU Information</p>
    <pre>
The system has ${NUM_PROCESSORS} Processors
The average CPU speed is ${CPU_MHZ} MHz
Load Average (1m, 5m, 15m): ${LOAD_1}, ${LOAD_5}, ${LOAD_15}
    </pre>
    <div style="display: flex; justify-content: center; margin-bottom: 20px;">
        <div style="width: 80%; max-width: 600px;">
            <canvas id="loadAverageChart"
                    data-load1="${LOAD_1}"
                    data-load5="${LOAD_5}"
                    data-load15="${LOAD_15}"
                    data-processors="${NUM_PROCESSORS}">
            </canvas>
        </div>
    </div>
    <hr>

    <p class="section-title">System Uptime and Load Average</p>
    <pre>
${UPTIME_INFO}
    </pre>
    <hr>

    <p class="section-title">Recent Apache Access Logs (Last 10 Entries)</p>
    <pre>
    ${LAST_ACCESS_LOGS}
    </pre>
    <hr>

    <p>Script last run by: ${RUN_BY_USER}</p>
    <p>Contact: <a href="mailto:lboudeguig@hawkmail.hfcc.edu" style="color: #0ff; text-decoration: none;">Lakhdar (lboudeguig@hawkmail.hfcc.edu)</a></p>
    <hr>

    <footer>
        <p>Page generated on server: ${CURRENT_DATE} - ${CURRENT_TIME} ${SERVER_TIMEZONE_SHORT}</p>
        <p>Current time (your browser): <span id="live-clock"></span></p>
    </footer>

    <script>
    // Disk Space Pie Chart
    document.addEventListener('DOMContentLoaded', function() {
        var ctx = document.getElementById('diskSpaceChart').getContext('2d');
        var canvasElement = document.getElementById('diskSpaceChart');

        // Retrieve data from data attributes
        var totalSpace = parseFloat(canvasElement.dataset.total);
        var usedSpace = parseFloat(canvasElement.dataset.used);
        var availableSpace = parseFloat(canvasElement.dataset.available);

        var diskSpaceChart = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: ['Used Space', 'Available Space'],
                datasets: [{
                    data: [usedSpace, availableSpace],
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.8)', // Red for Used
                        'rgba(75, 192, 192, 0.8)' // Green for Available
                    ],
                    borderColor: [
                        'rgba(255, 99, 132, 1)',
                        'rgba(75, 192, 192, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom', // Position legend below the chart
                        labels: {
                            color: '#eee' // Adjust legend label color for dark theme
                        }
                    },
                    title: {
                        display: true,
                        text: 'Root Filesystem Usage',
                        color: '#0f0' // Title color for dark theme
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                let label = context.label || '';
                                if (label) {
                                    label += ': ';
                                }
                                if (context.parsed !== null) {
                                    label += context.parsed.toFixed(2) + ' GB';
                                }
                                return label;
                            }
                        }
                    }
                }
            }
        });
    });
</script>

<script>
    // CPU Load Average Chart
    document.addEventListener('DOMContentLoaded', function() {
        var ctx = document.getElementById('loadAverageChart').getContext('2d');
        var canvasElement = document.getElementById('loadAverageChart');

        var load1 = parseFloat(canvasElement.dataset.load1);
        var load5 = parseFloat(canvasElement.dataset.load5);
        var load15 = parseFloat(canvasElement.dataset.load15);
        var numProcessors = parseInt(canvasElement.dataset.processors);

        // Define a suggestedMax to ensure the scale goes slightly above max load
        var suggestedMax = Math.max(load1, load5, load15, numProcessors * 1.2); // At least 20% above max cores or actual load

        var loadAverageChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['1 Min Load', '5 Min Load', '15 Min Load'],
                datasets: [{
                    label: 'Load Average',
                    data: [load1, load5, load15],
                    backgroundColor: [
                        'rgba(75, 192, 192, 0.8)', // Greenish for 1 min
                        'rgba(255, 206, 86, 0.8)',  // Yellowish for 5 min
                        'rgba(255, 99, 132, 0.8)'   // Reddish for 15 min
                    ],
                    borderColor: [
                        'rgba(75, 192, 192, 1)',
                        'rgba(255, 206, 86, 1)',
                        'rgba(255, 99, 132, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Load (relative to cores)',
                            color: '#eee'
                        },
                        ticks: {
                            color: '#eee' // Y-axis tick color
                        },
                        grid: {
                            color: 'rgba(255, 255, 255, 0.1)' // Grid lines color
                        },
                        suggestedMax: suggestedMax // Set a dynamic max for the Y-axis
                    },
                    x: {
                        ticks: {
                            color: '#eee' // X-axis tick color
                        },
                        grid: {
                            color: 'rgba(255, 255, 255, 0.1)' // Grid lines color
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false // Hide legend as there's only one dataset
                    },
                    title: {
                        display: true,
                        text: 'CPU Load Averages',
                        color: '#0f0' // Title color
                    },
                    // Annotation plugin for the cores line
                    annotation: {
                        annotations: {
                            line1: {
                                type: 'line',
                                yMin: numProcessors,
                                yMax: numProcessors,
                                borderColor: 'rgb(255, 255, 0)', // Yellow line
                                borderWidth: 2,
                                borderDash: [5, 5], // Dashed line
                                label: {
                                    display: true,
                                    content: 'Total Cores (' + numProcessors + ')',
                                    position: 'end',
                                    color: 'rgb(255, 255, 0)',
                                    backgroundColor: 'rgba(0,0,0,0.5)',
                                    font: {
                                        size: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });
    });
</script>

<script>
    // JavaScript to update a live clock in the browser
    function updateClock() {
        var now = new Date();
        var hours = String(now.getHours()).padStart(2, '0');
        var minutes = String(now.getMinutes()).padStart(2, '0');
        var seconds = String(now.getSeconds()).padStart(2, '0');
        var timeString = hours + ':' + minutes + ':' + seconds;

        var timezoneAbbr = '';
        try {
            var timezoneName = Intl.DateTimeFormat().resolvedOptions().timeZone;
            const commonAbbr = {
                "America/New_York": "EDT", "America/Detroit": "EDT", "America/Chicago": "CDT",
                "America/Los_Angeles": "PDT", "Europe/London": "BST", "Europe/Berlin": "CEST"
            };
            if (commonAbbr[timezoneName]) {
                timezoneAbbr = commonAbbr[timezoneName];
            } else {
                 // Fallback to a simpler extraction or just the full name if not in commonAbbr
                 var parts = timezoneName.split('/');
                 if (parts.length > 1) {
                     timezoneAbbr = parts[parts.length - 1].replace(/_/g, ' ');
                 } else {
                     timezoneAbbr = timezoneName;
                 }
            }
        } catch (e) {
            console.error("Could not get client timezone:", e);
        }

        document.getElementById('live-clock').textContent = timeString + (timezoneAbbr ? ' ' + timezoneAbbr : '');
    }

    setInterval(updateClock, 1000);
    updateClock();
</script>

</body>
</html>
EOF

# Set proper permissions for the generated HTML file

# Set ownership to the Apache user (www-data on Ubuntu)


/usr/bin/echo "Generated '$OUTPUT_FILE' successfully."
