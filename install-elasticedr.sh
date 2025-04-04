# Installer is for DEB/APT based systems
# Tested on Ubuntu 24.02

ELASTICADMINUSER=$1
ELASTICADMINUSERPASSWORD=$2
HOST_IP=$3

if [ -z $ELASTICADMINUSER ] || [ -z $ELASTICADMINUSERPASSWORD ] || [ -z $HOST_IP ]; then
        echo "Usage: install-elasticedr.sh <Elastic Admin User> <Elastic Admin User Password> <IP Address Of Current Machine>"
        exit 0
fi

pause() {
 read -s -n 1 -p "Press [Enter] key to continue . . ."
 echo ""
}

HOSTNAME=$(`which hostname`)

# Change the config files with the user-supplied information
# - Change the IP address & hostname
# -- Elasticsearch
sed -i "s/_HOST_IP_/$HOST_IP/g" elasticsearch.yml.config
sed -i "s/_HOSTNAME_/$HOSTNAME/g" elasticsearch.yml.config
# -- Kibana
sed -i "s/_HOST_IP_/$HOST_IP/g" kibana.yml.config

# - Change the username of elasticsearch and password
# -- Kibana
sed -i "s/_ELASTICUSER_USERNAME_/$ELASTICADMINUSER/g" kibana.yml.config
sed -i "s/_ELASTICUSER_PASSWORD_/$ELASTICADMINUSERPASSWORD/g" kibana.yml.config

# Install some packages

echo "[+] Running 'apt update' and installing some packages"
sudo apt update
sudo apt install -y git apt-transport-https fish unzip p7zip-full

# Add the GPG key for the elastic repository
echo "Adding elastic repository"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
echo "[+] Updating APT after elastic repository addition"
sudo apt update

# Install Elastic & Kibana
echo "[+] Installing Elastisearch and Kibana"
sudo apt install -y elasticsearch kibana

echo "[!] Make sure to copy the password from the installation output above"
pause

echo "[+] Backing up the original elasticsearch.yml file in /etc/elasticsearch/"
sudo mv /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak

echo "[+] Backing up the original kibana.yml file in /etc/kibana/"
sudo mv /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bak

echo "[+] Adding new user $ELASTICADMINUSER"
sudo /usr/share/elasticsearch/bin/elasticsearch-users useradd $ELASTICADMINUSER -p $ELASTICADMINUSERPASSWORD
sudo /usr/share/elasticsearch/bin/elasticsearch-users roles $ELASTICADMINUSER -a kibana_system,kibana_admin,superuser

echo "[+] Creating a new CA and certificates for Elasticsearch and Kibana"
echo "Follow the steps... !"
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil http # Elasticsearch and kibana

echo "[+] Adding the PKCS#12 password to the keystore of elasticsearch"
sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add "xpack.security.http.ssl.keystore.secure_password" # PKCS12 password

echo "[+] Generate a certificate for Kibana using the Elasticsearch CA"
sudo mkdir /etc/kibana/certs/
sudo unzip /usr/share/elasticsearch/elasticsearch-ssl-http.zip -d /etc/elasticsearch/certs/

# Replace -dns options to match your environment
echo "[+] Generating Kibana SSL certificate"
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert -pem -ca /etc/elasticsearch/certs/ca/ca.p12 -name kibana-server -dns kibana.qsec.local,kibana,10.10.10.26

sudo cp /etc/elasticsearch/certs/kibana/elasticsearch-ca.pem /etc/kibana/certs/elasticsearch-ca.pem

echo "Copying elasticsearch-ca certificate to /etc/kibana/"
sudo unzip /usr/share/elasticsearch/certificate-bundle.zip -d /etc/kibana/certs/

echo "Fixing permission of new kibana certs to 664"
sudo chmod 650 /etc/kibana/certs/kibana-server/
sudo chmod 640 /etc/kibana/certs/kibana-server/kibana-server.key
sudo chmod 640 /etc/kibana/certs/kibana-server/kibana-server.crt
sudo chown -R root:kibana /etc/kibana/certs/*

echo "[+] Adding the new configuration files for elasticsearch and kibana"
sudo cp elasticsearch.yml.config /etc/elasticsearch/elasticsearch.yml
sudo cp kibana.yml.config /etc/kibana/kibana.yml

# Generate encryption keys for kibana
echo "[+] Generating encryption keys for Kibana"
echo "\t==== Copy them to the kibana.yml file ===="
sudo /usr/share/kibana/bin/kibana-encryption-keys generate -f

echo "[+] Enable elasticsearch and kibana to start on boot"
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch
sudo systemctl enable kibana

echo "[+] Cleaning up certificate-bundle.zip"
sudo rm -rf /usr/share/elasticsearch/certificate-bundle.zip

echo "[+] Cleaning up elasticsearch-ssl-http.zip"
sudo rm -rf /usr/share/elasticsearch/elasticsearch-ssl-http.zip

echo "[+] Finished !"
echo "Make the changes to the configuration files and start the services"
echo "systemctl start elasticsearch"
echo "systemctl start kibana"

echo "[!] Do not forget to make the required changes to the config files to make it work"