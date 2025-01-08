#!/bin/bash

# Create agent installation script
cat > install-zabbix-agent.sh << 'EOF'
#!/bin/bash

# Update system
apt-get update

# Install dependencies
apt-get install -y wget gnupg2 vim

# Download and install Zabbix Agent 2
wget https://repo.zabbix.com/zabbix/7.2/stable/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.2.0-1%2Bubuntu22.04_amd64.deb
dpkg -i zabbix-agent2_7.2.0-1+ubuntu22.04_amd64.deb
apt-get install -f -y

# Configure Agent
cat > /etc/zabbix/zabbix_agent2.conf << CONF
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=zabbix-server-mysql
ServerActive=zabbix-server-mysql
Hostname=$(hostname)
CONF

# Create necessary directories and files
mkdir -p /run/zabbix/
touch /run/zabbix/zabbix_agent2.pid

# Start agent
zabbix_agent2
EOF

chmod +x install-zabbix-agent.sh

# Create and start container
docker run -d --name ubuntu-zabbix-agent2 \
  --network=zabbix-net \
  -v $(pwd)/install-zabbix-agent.sh:/install-zabbix-agent.sh \
  ubuntu:22.04 sleep infinity

# Install agent in container
docker exec -it ubuntu-zabbix-agent2 /install-zabbix-agent.sh

echo "Client installation completed!"
echo "Container name: ubuntu-zabbix-agent2"
echo "Remember to add the host in Zabbix interface using DNS name: ubuntu-zabbix-agent2"