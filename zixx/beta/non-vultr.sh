
#!/bin/bash

VERSION="1.1.53"
PROJECT="Zixx"
PROJECT_FOLDER="$HOME/zixx"
DAEMON_BINARY="zixxd"
CLI_BINARY="zixx-cli"
  
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'

function checks() 
{
  if [[ ($(lsb_release -d) != *16.04*) ]] && [[ ($(lsb_release -d) != *17.04*) ]]; then
      echo -e "${RED}You are not running Ubuntu 16.04, 17.04 or 18.04. Installation is cancelled.${NC}"
      exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}$0 must be run as root.${NC}"
     exit 1
  fi
  
  if [ -f /root/zixx/zixx-cli ]; then
    IS_INSTALLED=true
    echo -e "${YELLOW}$PROJECT Client found! ${BLUE}Checking version...${NC}"
    INSTALLED_VERSION=$(/root/zixx/zixx-cli --version | tr - ' ' | awk {'print $5'})
    LATEST_D=$(wget -qO- wget -qO- https://api.zixx.org/download/linux/zixx-cli)
    CURRENT_VERSION="$(echo $LATEST_D | tr / ' ' | awk {'print $7'})"
    if [ "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" == "$CURRENT_VERSION" ]; then
      echo -e "${BLUE}Current version up to date. Using existing.${NC}"
      IS_CURRENT=True
    fi
  fi
}

function check_existing()
{
  echo
  echo -e "${BLUE}Checking for existing nodes and available IPs...${NC}"
  echo
  #Get list and count of IPs
  IP_LIST=$(ifconfig | grep "inet " | awk {'print $2'} | grep -vE '127.0.0|192.168|172.16|10.0.0' | tr -d 'inet addr:')
  IP_NUM=$(echo "$IP_LIST" | wc -l)

  #Get number of existing Zixx masternode directories
  DIR_COUNT=$(ls -la /root/ | grep "\.zixx" | grep -c '^')
  
  #Check if there are more IPs than existing nodes
  if [[ $DIR_COUNT -ge $IP_NUM ]]; then
    echo -e "${RED}Not enough available IP addresses to run another node! Please add other IPs to this VPS first.${NC}"
    exit 1
  fi

  echo -e "${YELLOW}Found ${BLUE} $DIR_COUNT ${YELLOW} $PROJECT Masternodes and ${BLUE} $IP_NUM ${YELLOW} IP addresses.${NC}"

  #Now confirm available IPs by removing those that are already bound to 44845
  IP_IN_USE=$(netstat -tulpn | grep :44845 | awk {'print $4'})
  
  echo -e "${RED}IMPORTANT - ${YELLOW} please make sure you don't select an IP that is already in use! ${RED}- IMPORTANT${NC}"
  echo -e "${BLUE}IP List using port 44845 (Active Zixx nodes):{NC}"
  echo $IP_IN_USE
  echo
  echo -e "${GREEN}List of all IPs on this machine${NC}"
  echo $IP_LIST
  echo
  read -e -p "$(echo -e ${BLUE}Please enter the IP address you wish to use: ${NC})" NEXT_AVAIL_IP
  echo
  echo -e "${YELLOW}Using ${BLUE} $NEXT_AVAIL_IP${NC}"
  echo
  read -e -p "Continue with installation? [Y/N] : " CHOICE
  if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
    exit 1;
  fi

  if [[ $DIR_COUNT -gt 0 ]]; then
    DIR_NUM=$((DIR_COUNT+1))
  fi
}

function set_environment()
{
  DATADIR="$HOME/.zixx$DIR_NUM"

  TMP_FOLDER=$(mktemp -d)
  RPC_USER="$PROJECT-Admin"
  MN_PORT=44845
  RPC_PORT=$((14647+DIR_NUM))

  DAEMON="$PROJECT_FOLDER/$DAEMON_BINARY"
  CONF_FILE="$DATADIR/zixx.conf"
  CLI="$PROJECT_FOLDER/$CLI_BINARY -conf=$CONF_FILE -datadir=$DATADIR"
  DAEMON_START="$DAEMON -datadir=$DATADIR -conf=$CONF_FILE -daemon"
  CRONTAB_LINE="@reboot $DAEMON_START"
}

function show_header()
{
  clear
  echo -e "${RED}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
  echo -e "${YELLOW}$PROJECT Masternode Installer v$VERSION - chris 2018"
  echo -e "${RED}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
  echo
  echo -e "${BLUE}This script will automate the installation of your ${YELLOW}$PROJECT ${BLUE}masternode along with the server configuration."
  echo -e "It will:"
  echo
  echo -e " ${YELLOW}■${NC} Create a swap file"
  echo -e " ${YELLOW}■${NC} Prepare your system with the required dependencies"
  echo -e " ${YELLOW}■${NC} Obtain the latest $PROJECT masternode files from the official $PROJECT repository"
  echo -e " ${YELLOW}■${NC} Automatically generate the Masternode Genkey (and display at the end)"
  echo -e " ${YELLOW}■${NC} Automatically generate the .conf file"
  echo -e " ${YELLOW}■${NC} Add Brute-Force protection using fail2ban"
  echo -e " ${YELLOW}■${NC} Update the system firewall to only allow SSH, the masternode ports and outgoing connections"
  echo -e " ${YELLOW}■${NC} Add a schedule entry for the service to restart automatically on power cycles/reboots."
  echo
  echo -e " ${RED}WARNING!!! ${BLUE}If you are already running one or more $PROJECT Masternode(s) on this machine, make sure they are running before executing this script!!! ${NC}"
  echo
}

function create_swap()
{
  echo
  echo -e "${BLUE}Creating Swap... (ignore errors, this might not be supported)${NC}"
  fallocate -l 3G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo
  echo -e "/swapfile none swap sw 0 0 \n" >> /etc/fstab
}

function install_prerequisites()
{
  if [ "$IS_INSTALLED" = true ]; then
      echo -e "${BLUE} Skipping pre-requisites..."
  else
    echo
    echo -e "${BLUE}Installing Pre-requisites${NC}"
    #addid this for libdbcxx
    sudo apt update
    sudo apt install -y pwgen build-essential libssl-dev libboost-all-dev libqrencode-dev libminiupnpc-dev libevent-2.0-5
    sudo add-apt-repository -y ppa:bitcoin/bitcoin
    sudo apt update
    sudo apt install -y jq libdb4.8-dev libdb4.8++-dev
    #end libdbcxx section
  
    sudo apt install -y build-essential htop libevent-2.0-5 libzmq5 libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-chrono1.58.0 libminiupnpc10 libevent-pthreads-2.0-5 unzip
    sudo wget http://download.oracle.com/berkeley-db/db-4.8.30.zip
    sudo unzip db-4.8.30.zip
    cd db-4.8.30
    cd build_unix/
    sudo ../dist/configure --prefix=/usr/ --enable-cxx
    sudo make
    sudo make install
  fi
}

function copy_binaries()
{
  #check if version is current before copying binaries
  if [ "$IS_CURRENT" = true ]; then
      echo -e "${BLUE} Skipping binaries..."
  else
  
    #deleting previous install folders in case of failed install attempts. Also ensures latest binaries are used
    rm -rf $PROJECT_FOLDER
    echo
    echo -e "${BLUE}Copying Binaries...${NC}"
    mkdir $PROJECT_FOLDER
    cd $PROJECT_FOLDER
  
    echo
    echo -e "${BLUE}Getting latest files...${NC}"
    LATEST_D=$(wget -qO- wget -qO- https://api.zixx.org/download/linux/zixxd)
    LATEST_CLI=$(wget -qO- wget -qO- https://api.zixx.org/download/linux/zixx-cli)
    wget $LATEST_D
    wget $LATEST_CLI
    chmod +x zixx{d,-cli}
    if [ ! -f '/usr/local/bin/z.sh' ]; then
      wget -O /usr/local/bin/z.sh https://raw.githubusercontent.com/zaemliss/installers/master/zixx/z.sh
      chmod +x /usr/local/bin/z.sh
      echo "alias z='/usr/local/bin/z.sh'" >> ~/.bashrc
    fi
  fi
  if [ -f $DAEMON ]; then
      mkdir $DATADIR
      echo -e "${BLUE}Starting daemon ...(30 seconds)${NC}"
      $DAEMON_START
      sleep 30
    else
      echo -e "${RED}Binary not found! Please scroll up to see errors above : $RETVAL ${NC}"
      exit 1;
  fi
  sleep 3
  . ~/.bashrc
}

function create_conf_file()
{
  echo
  PASSWORD=$(pwgen -s 64 1)
  GENKEY=$($CLI masternode genkey)
  echo
  echo -e "${BLUE}Creating conf file...${NC}"
  echo -e "${YELLOW}Ignore any errors you see below. (15 seconds)${NC}"
  sleep 15
  echo
  echo -e "${BLUE}Stopping the daemon and writing config (15 seconds)${NC}"
  $CLI stop
  sleep 16
  
cat <<EOF > $CONF_FILE
masternode=1
masternodeprivkey=$GENKEY
server=1
bind=$NEXT_AVAIL_IP
rpcport=$RPC_PORT
rpcuser=$RPC_USER
rpcpassword=$PASSWORD
EOF
}

function configure_firewall()
{
  echo
  echo -e "${BLUE}setting up firewall...${NC}"
  sudo apt-get install -y ufw
  sudo apt-get update -y
  
  #configure ufw firewall
  sudo ufw default allow outgoing
  sudo ufw default deny incoming
  sudo ufw allow ssh/tcp
  sudo ufw limit ssh/tcp
  sudo ufw allow $MN_PORT/tcp
  sudo ufw logging on
  echo "y" | sudo ufw enable
}

function add_cron()
{
(crontab -l; echo "$CRONTAB_LINE") | crontab -
}

function start_wallet()
{
  echo
  echo -e "${BLUE}Re-Starting the wallet...${NC}"
  if [ -f $DAEMON ]; then
    echo
    echo -e "${RED}Make ${YELLOW}SURE ${RED}you copy this Genkey for your QT wallet (Windows/Mac wallet) ${BLUE}$GENKEY${NC}"
    echo -e "${BLUE}If you are using Putty, just select the text. It will automatically go to your clipboard.${NC}"
    echo -e "${BLUE}If you are using SSH, use CTRL-INSERT / CTRL-V${NC}"
    echo -e "${YELLOW}Typing the key out incorrectly is 99% of all installation issues. ${NC}"
    echo
    echo -e "${BLUE}Now wait for a full synchro (can take 10-15 minutes)${NC}"
    echo -e "${BLUE}Once Synchronized, go back to your Windows/Mac wallet,${NC}"
    echo -e "${BLUE}go to your Masternodes tab, click on your masternode and press on ${YELLOW}Start Alias${NC}"
    echo
    read -n 1 -s -r -p "Press any key to continue to syncronisation steps"
    echo
    $DAEMON_START
    echo -e "${BLUE}Starting Synchronization...${NC}"
    sleep 10
    BLOCKS=$(curl -s https://api.zixx.org/extended/summary | jq .data.status.blockcount)
    CURBLOCK=$(z.sh zixx getinfo | grep "blocks" | awk {'print $2'} | tr -d ',')

    echo -ne "${YELLOW}Current Block: ${GREEN}$BLOCKS${NC}\n\n"
    while [[ $CURBLOCK -lt $BLOCKS ]]; do
      CURBLOCK=$(z.sh zixx getinfo | grep blocks | awk {'print $2'} | tr -d ',')
      echo -ne "${BLUE} syncing${YELLOW} $CURBLOCK ${BLUE}out of${YELLOW} $BLOCKS ${BLUE}...${NC} \r"
      sleep 2
    done

    watch -g $CLI mnsync status
    watch -g $CLI mnsync status
    watch -g $CLI mnsync status
    echo -e "${YELLOW}Please right click on your new node in your QT wallet and Start Alias.${NC}"
    echo -e "${YELLOW}The command prompt will return once your node is started. If the Status goes to Expired in your QT wallet, please start alias again.${NC}"
    read -n 1 -s -r -p "Press any key to continue"
    watch -g $CLI masternode status
    echo -e "${BLUE}Congratulations, you've set up your masternode!${NC}"
    echo
    echo -e "${BLUE}Type ${YELLOW}z <data directory> <command> ${BLUE} to interact with your server(s). ${NC}"
    echo -e "${BLUE}Ex: ${GREEN}z zixx2 masternode status ${NC}"
    
  else
    RETVAL=$?
    echo -e "${RED}Binary not found! Please scroll up to see errors above : $RETVAL ${NC}"
    exit 1
  fi
}

function cleanup()
{
  cd $HOME
  
  if [ "$IS_CURRENT" = true ] && [ "$IS_INSTALLED" = true ]; then
    echo -e "${BLUE} Finalizing..."
  else
    rm -R db-4.8*
  fi
}

function deploy()
{
  checks
  show_header
  check_existing
  set_environment
  create_swap
  install_prerequisites
  copy_binaries
  create_conf_file
  configure_firewall
  add_cron
  start_wallet
  cleanup
}

deploy
