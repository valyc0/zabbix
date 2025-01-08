installazione zabbix 7.2


##### SERVER ###########
# https://www.zabbix.com/documentation/7.2/en/manual/installation/containers

docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 zabbix-net

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



## user:Admin
## pass: zabbix




############## client ubuntu ###########

cat > install-zabbix.sh << EOF
#!/bin/bash

# Aggiorna il sistema
apt-get update

# Installa le dipendenze necessarie
apt-get install -y wget gnupg2 vim

# Scarica e installa Zabbix Agent 2
wget https://repo.zabbix.com/zabbix/7.2/stable/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.2.0-1%2Bubuntu22.04_amd64.deb
dpkg -i zabbix-agent2_7.2.0-1+ubuntu22.04_amd64.deb
apt-get install -f -y

# Configura Zabbix Agent 2
echo "LogFile=/var/log/zabbix/zabbix_agentd.log" >> /etc/zabbix/zabbix_agent2.conf
echo "LogFileSize=0" >> /etc/zabbix/zabbix_agent2.conf
echo "Server=zabbix-server-mysql" >> /etc/zabbix/zabbix_agent2.conf
echo "ServerActive=zabbix-server-mysql" >> /etc/zabbix/zabbix_agent2.conf
echo "Hostname=\$(hostname)" >> /etc/zabbix/zabbix_agent2.conf

# Crea la directory e il file PID necessari
mkdir -p /run/zabbix/
touch /run/zabbix/zabbix_agent2.pid

# Avvia Zabbix Agent 2
zabbix_agent2
EOF

chmod +x install-zabbix.sh

docker run -d --name ubuntu-zabbix-agent2 \
           --network=zabbix-net \
           -v $(pwd)/install-zabbix.sh:/install-zabbix.sh \
           ubuntu:22.04 sleep infinity
		   
docker exec -it ubuntu-zabbix-agent2 /install-zabbix.sh		   


################


# Configurare l'Host nella GUI di Zabbix utilizzando il DNS

Questa guida spiega come configurare un host nella GUI di Zabbix utilizzando il **DNS** (nome del container) invece dell'indirizzo IP. Questo approccio è particolarmente utile quando si utilizzano container Docker nella stessa rete.

---

## Passo 1: Accedi alla GUI di Zabbix
1. Apri il browser e vai all'indirizzo del tuo server Zabbix (es: `http://<indirizzo-ip-server-zabbix>`).
2. Effettua il login con le credenziali predefinite:
   - **Username:** `Admin`
   - **Password:** `zabbix`

---

## Passo 2: Aggiungi un Nuovo Host
1. Vai a **Configuration** > **Hosts**.
2. Clicca sul pulsante **Create host** in alto a destra.

---

## Passo 3: Configura i Dettagli dell'Host
1. **Host name:** Inserisci il nome del container che hai usato per il client Zabbix Agent (es: `ubuntu-zabbix-agent2`).
   - Questo nome deve corrispondere esattamente al nome del container Docker.
2. **Visible name:** (Opzionale) Puoi inserire un nome più descrittivo, ad esempio `Ubuntu Zabbix Agent 2`.
3. **Groups:** Seleziona un gruppo appropriato per l'host, ad esempio `Linux servers`.
   - Puoi anche creare un nuovo gruppo se necessario.

---

## Passo 4: Configura l'Interfaccia
1. Nella sezione **Interfaces**, clicca su **Add** per aggiungere una nuova interfaccia.
2. Seleziona il tipo di interfaccia **Agent**.
3. Compila i campi come segue:
   - **DNS name:** Inserisci il nome del container (es: `ubuntu-zabbix-agent2`).
   - **Connect to:** Seleziona **DNS** (questo indica a Zabbix di risolvere il nome del container tramite DNS).
   - **Port:** Lascia la porta predefinita `10050` (a meno che tu non abbia modificato la porta dell'agente).

---

## Passo 5: Collega i Template
1. Vai alla scheda **Templates**.
2. Clicca su **Select** e cerca il template appropriato per il tuo host, ad esempio `Template OS Linux by Zabbix agent`.
3. Seleziona il template e clicca su **Add** per collegarlo all'host.

---

## Passo 6: Salva la Configurazione
1. Verifica che tutti i campi siano corretti.
2. Clicca su **Add** in basso per salvare la configurazione del nuovo host.

---

## Passo 7: Verifica la Connessione
1. Torna alla schermata **Configuration** > **Hosts**.
2. Controlla la colonna **Availability** per verificare che l'host sia contrassegnato come **Available** (icona verde).
   - Se l'host è contrassegnato come **Unavailable** (icona rossa), verifica:
     - Che il container `ubuntu-zabbix-agent2` sia attivo e in esecuzione.
     - Che il nome del container sia corretto e risolvibile tramite DNS.
     - Che il Zabbix Agent sia configurato correttamente nel container.

---

## Perché usare il DNS?
- **Vantaggi:**
  - Non devi preoccuparti degli indirizzi IP, che potrebbero cambiare se i container vengono ricreati.
  - Utilizzare il nome del container è più intuitivo e facile da gestire.
- **Funziona perché:**
  - I container nella stessa rete Docker (in questo caso `zabbix-net`) possono risolversi a vicenda tramite i loro nomi.
  - Docker gestisce automaticamente la risoluzione DNS interna per i container nella stessa rete.

---

## Risoluzione dei Problemi
Se l'host non è raggiungibile:
1. Verifica che il container `ubuntu-zabbix-agent2` sia in esecuzione:
   ```bash
   docker ps -f name=ubuntu-zabbix-agent2
   
   
##########################################

# Creare un Discovery e una Rule in Zabbix

Questa guida spiega come configurare una **Discovery Rule** (regola di scoperta) e una **Action** (azione automatica) in Zabbix per rilevare automaticamente nuovi host e aggiungerli al monitoraggio.

---

## 1. Creare una Discovery Rule

La **Discovery Rule** definisce come Zabbix deve cercare nuovi host nella rete.

### Passo 1: Vai alla sezione Discovery
1. Accedi alla GUI di Zabbix.
2. Vai a **data collection** > **Discovery**.

### Passo 2: Crea una Nuova Regola di Discovery
1. Clicca su **Create discovery rule**.
2. Configura i seguenti campi:
   - **Name:** Assegna un nome alla regola (es: `Network Discovery`).
   - **IP range:** Specifica l'intervallo di IP da scansionare (es: `192.168.1.1-254`).
   - **Update interval:** Imposta la frequenza di scansione (es: `1h`).

### Passo 3: Aggiungi un Check per Zabbix Agent
1. Nella sezione **Checks**, clicca su **Add**.
2. Configura il check:
   - **Check type:** Seleziona **Zabbix agent**.
   - **Key:** Inserisci la key `agent.ping`.
     - La key `agent.ping` verifica se un Zabbix Agent è attivo e risponde.
   - **Port:** Lascia il valore predefinito `10050` (a meno che tu non abbia modificato la porta dell'agente).
   - **Device uniqueness criteria:** Seleziona come identificare un host univoco (es: `IP address`).

3. Salva la regola cliccando su **Add**.

---

## 2. Creare una Action (Azione Automatica)

Una **Action** definisce cosa fare quando un nuovo host viene rilevato dalla Discovery Rule.

### Passo 1: Vai alla sezione Actions
1. Vai a **Alert** > **Actions**.
2. Seleziona **Discovery actions** dal menu a tendina in alto.

### Passo 2: Crea una Nuova Azione
1. Clicca su **Create action**.
2. Configura i seguenti campi:
   - **Name:** Assegna un nome all'azione (es: `Auto Add Hosts`).
   - **Conditions:** Aggiungi una condizione per eseguire l'azione solo quando viene rilevato un nuovo host (es: `Discovery check = Zabbix agent`).
   - **Operations:** Aggiungi un'operazione per aggiungere l'host al monitoraggio:
     - Clicca su **Add** nella sezione **Operations**.
     - Seleziona **Add host**.
     - Assegna un template all'host (es: `Template OS Linux by Zabbix agent`).
     - Aggiungi l'host a un gruppo (es: `Discovered hosts`).

3. Salva l'azione cliccando su **Add**.
   
