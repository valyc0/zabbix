# Zabbix 7.2 Installation Guide

## Server Installation

### Prerequisites
Create a Docker network:
```bash
docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 zabbix-net
```

### Database Setup
```bash
docker run --name mysql-server -t \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  --network=zabbix-net \
  --restart unless-stopped \
  -d mysql:8.0-oracle \
  --character-set-server=utf8 --collation-server=utf8_bin \
  --default-authentication-plugin=mysql_native_password
```

### Zabbix Server
```bash
docker run --name zabbix-server-mysql -t \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  -e ZBX_JAVAGATEWAY="zabbix-java-gateway" \
  --network=zabbix-net \
  -p 10051:10051 \
  --restart unless-stopped \
  -d zabbix/zabbix-server-mysql:alpine-7.2-latest
```

### Web Interface
```bash
docker run --name zabbix-web-nginx-mysql -t \
  -e ZBX_SERVER_HOST="zabbix-server-mysql" \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  --network=zabbix-net \
  -p 80:8080 \
  --restart unless-stopped \
  -d zabbix/zabbix-web-nginx-mysql:alpine-7.2-latest
```

Default credentials:
- Username: Admin
- Password: zabbix

## Client Installation (Ubuntu)

### Setup Script
Create installation script:
```bash
cat > install-zabbix.sh << EOF
#!/bin/bash

apt-get update
apt-get install -y wget gnupg2 vim

wget https://repo.zabbix.com/zabbix/7.2/stable/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.2.0-1%2Bubuntu22.04_amd64.deb
dpkg -i zabbix-agent2_7.2.0-1+ubuntu22.04_amd64.deb
apt-get install -f -y

echo "LogFile=/var/log/zabbix/zabbix_agentd.log" >> /etc/zabbix/zabbix_agent2.conf
echo "LogFileSize=0" >> /etc/zabbix/zabbix_agent2.conf
echo "Server=zabbix-server-mysql" >> /etc/zabbix/zabbix_agent2.conf
echo "ServerActive=zabbix-server-mysql" >> /etc/zabbix/zabbix_agent2.conf
echo "Hostname=\$(hostname)" >> /etc/zabbix/zabbix_agent2.conf

mkdir -p /run/zabbix/
touch /run/zabbix/zabbix_agent2.pid

zabbix_agent2
EOF

chmod +x install-zabbix.sh
```

### Deploy Client Container
```bash
docker run -d --name ubuntu-zabbix-agent2 \
  --network=zabbix-net \
  -v $(pwd)/install-zabbix.sh:/install-zabbix.sh \
  ubuntu:22.04 sleep infinity

docker exec -it ubuntu-zabbix-agent2 /install-zabbix.sh
```

## Host Configuration

1. Access Zabbix GUI at `http://<server-ip>`

2. Navigate to Configuration > Hosts > Create host

3. Configure host details:
   - Host name: container name (e.g., ubuntu-zabbix-agent2)
   - Visible name: descriptive name
   - Groups: select appropriate group

4. Add interface:
   - Type: Agent
   - DNS name: container name
   - Connect to: DNS
   - Port: 10050

5. Add templates:
   - Select Template OS Linux by Zabbix agent

6. Save configuration

## Discovery Configuration

### Create Discovery Rule

1. Navigate to Data Collection > Discovery

2. Create new rule:
   - Name: descriptive name
   - IP range: network range
   - Update interval: scan frequency
   - Add Zabbix agent check:
     - Type: Zabbix agent
     - Key: agent.ping
     - Port: 10050

### Create Action

1. Navigate to Alert > Actions > Discovery actions

2. Configure new action:
   - Name: descriptive name
   - Conditions: Discovery check = Zabbix agent
   - Operations: Add host
     - Assign template
     - Add to group

## Troubleshooting

Check container status:
```bash
docker ps -f name=ubuntu-zabbix-agent2
```

Verify container resolution using DNS within the Docker network.
