#!/bin/bash

# Update the system
apt-get update 

# Install necessary packages
apt-get install wget nano -y

# Install net-tools
apt-get install net-tools -y

# Detect user and set the directory path
if [ "$EUID" -eq 0 ]; then
    user_directory="/root/hy"
else
    user_directory="/home/$USER/hy"
fi

# Check if Hysteria directory exists
if [ -d "$user_directory" ]; then
    clear
    echo "--------------------------------------------------------------------------------"
    echo -e "\e[1;33mHysteria directory already exists. Checking for latest version..\e[0m"
    echo "--------------------------------------------------------------------------------"
    sleep 2
    # Check if the config.json file exists
    if [ -f "$user_directory/config.json" ]; then
        # Read the port and obfuscation password from config.json
        port=$(jq -r '.listen' "$user_directory/config.json" | cut -c 2-)
        password=$(jq -r '.obfs' "$user_directory/config.json")
    else
        echo "Error: config.json file not found in Hysteria directory."
        return
    fi
else
    # Prompt user for port and password
    read -p "Enter the listening port: " port
    read -p "Enter the obfuscation password: " password

    # Create the directory
    mkdir -p "$user_directory"

    # Create the hysteria configuration file
    cat << EOF > config.json
    {
    "listen": ":$port",
    "cert": "$user_directory/ca.crt",
    "key": "$user_directory/ca.key",
    "obfs": "$password",
    "recv_window_conn": 3407872,
    "recv_window": 13631488,
    "disable_mtu_discovery": true,
    "resolver": "https://223.5.5.5/dns-query"
    }
EOF
fi

# Detect the latest version of the GitHub repository
# latest_version=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
latest_version="v1.3.5"
echo -e "\e[1;33m---> Installing hysteria ver $latest_version\e[0m"
echo "--------------------------------------------------------------------------------"
sleep 2

# Detect architecture and download the appropriate file
architecture=$(uname -m)
if [ "$architecture" = "x86_64" ]; then
    wget "https://github.com/apernet/hysteria/releases/download/$latest_version/hysteria-linux-amd64"
else
    wget "https://github.com/apernet/hysteria/releases/download/$latest_version/hysteria-linux-arm"
    mv hysteria-linux-arm hysteria-linux-amd64
fi

# Provide execute permissions to the downloaded file
chmod 755 hysteria-linux-amd64

# Generate encryption keys if they don't exist
if [ ! -f "$user_directory/ca.key" ] || [ ! -f "$user_directory/ca.crt" ]; then
    openssl ecparam -genkey -name prime256v1 -out "$user_directory/ca.key"
    openssl req -new -x509 -days 36500 -key "$user_directory/ca.key" -out "$user_directory/ca.crt" -subj "/CN=bing.com"
fi

# Create a systemd service for hysteria if it doesn't exist
if [ ! -f "/etc/systemd/system/hy.service" ]; then
    cat << EOF > /etc/systemd/system/hy.service
    [Unit]
    After=network.target nss-lookup.target

    [Service]
    User=root
    WorkingDirectory=$user_directory
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
    AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
    ExecStart=$user_directory/hysteria-linux-amd64 -c $user_directory/config.json server
    ExecReload=/bin/kill -HUP $MAINPID
    Restart=always
    RestartSec=5
    LimitNOFILE=infinity

    [Install]
    WantedBy=multi-user.target
EOF

    # Reload systemd and enable the service
    systemctl daemon-reload
    systemctl enable hy
fi


# Restart the hysteria service and display its status
systemctl restart hy

# Get public IPs
IPV4=$(curl -s https://v4.ident.me)
if [ $? -ne 0 ]; then
    echo "Error: Failed to get IPv4 address"
    return
fi

IPV6=$(curl -s https://v6.ident.me)
if [ $? -ne 0 ]; then
    echo "Error: Failed to get IPv6 address" 
    return
fi

# Create URLs
IPV4_URL="hysteria://$IPV4:$port?protocol=udp&insecure=1&upmbps=100&downmbps=100&obfs=xplus&obfsParam=$password#hysteria"
IPV6_URL="hysteria://[$IPV6]:$port?protocol=udp&insecure=1&upmbps=100&downmbps=100&obfs=xplus&obfsParam=$password#hysteria"

# Print URLs
echo "----------------config info-----------------"
echo -e "\e[1;33mPassword: $password\e[0m"
echo "--------------------------------------------"
echo
echo "----------------IP and Port-----------------"
echo -e "\e[1;33mPort: $port\e[0m"
echo -e "\e[1;33mIPv4: $IPV4\e[0m"
echo -e "\e[1;33mIPv6: $IPV6\e[0m"
echo "--------------------------------------------"
echo
echo "----------------Hysteria Config IPv4-----------------"
echo -e "\e[1;33m$IPV4_URL\e[0m"
qrencode -t ANSIUTF8 "$IPV4_URL"
echo "--------------------------------------------"
echo
echo "-----------------Hysteria Config IPv6----------------"
echo -e "\e[1;33m$IPV6_URL\e[0m"
qrencode -t ANSIUTF8 "$IPV6_URL"
echo "--------------------------------------------"
