#!/bin/bash
# wget https://github.com/zaemliss/installers/raw/master/atheneum/infopage.sh -O infopage.sh
# User Friendly Masternode infopage by @bitmonopoly 2018
ver="1.1.13"
project='Atheneum'
client=$(find ~/ -name "atheneum-cli" | head -n 1)

red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;36m'
clear='\033[0m'
erase='\033[K'

echo -e "${red} Checking Version ...${clear}"

getcurrent=$(curl -q https://raw.githubusercontent.com/zaemliss/installers/master/atheneum/versions | jq .infopage | tr -d '"') > /dev/null 2>&1
declare -a status
  status[0]="Initial Masternode Syncronization"
  status[1]="Syncing Masternode Sporks"
  status[2]="Syncing Masternode List"
  status[3]="Syncing Masternode Winners"
  status[4]="Syncing Budget"
  status[5]="Masternode Syncronization Timeout"
  status[10]="Syncing Masternode Budget Proposals"
  status[11]="Syncing Masternode Finalized Budgets"
  status[998]="Masternode Sync Failed"
  status[999]="Masternode Sync Successful"

if ! [[ $ver == $getcurrent ]]; then
  echo -e "${red} Version outdated! Downloading new version ...${clear}"
  wget https://github.com/zaemliss/installers/raw/master/atheneum/infopage.sh -O infopage.sh > /dev/null 2>&1
  sleep 2
  exec "./infopage.sh"
fi

clear
while [ 1 ]; do
  getinfo=$($client getinfo)
  gettxoutsetinfo=$($client gettxoutsetinfo)
  getwinner=$($client getpoolinfo)

  ismasternode=$(cat ~/.Atheneum/atheneum.conf | grep -c masternode)
  if ! [[ $ismasternode == "0" ]]; then
    mnstatus=$($client masternode debug)
  else
    mnstatus="This is not a masternode"  
  fi
  mnsync=$($client mnsync status)
  count=$($client masternode list | grep -c addr | awk '{print $0"                             "}')
  winner=$(echo $getwinner | jq .current_masternode | tr -d '"' | awk '{print $0"                             "}')

  version=$(echo $getinfo | jq .version | awk '{print $0"                             "}')
  protocol=$(echo $getinfo | jq .protocolversion | awk '{print $0"                             "}')
  blocks=$(echo $getinfo | jq .blocks | awk '{print $0"                             "}')
  connections=$(echo $getinfo | jq .connections | awk '{print $0"                             "}')
  supply=$(echo $gettxoutsetinfo | jq .total_amount | awk '{print $0"                             "}')
  transactions=$(echo $gettxoutsetinfo | jq .transactions | awk '{print $0"                             "}')

  blockchainsynced=$(echo $mnsync | jq .IsBlockchainSynced | awk '{print $0"                             "}')
  asset=$(echo $mnsync | jq .RequestedMasternodeAssets)
  attempt=$(echo $mnsync | jq .RequestedMasternodeAttempt)

  logresult=$(tail -n 11 ~/.Atheneum/debug.log | pr -T -o 2 | cut -c 1-80 | awk '{printf("%.80s \n", $0"                                                    ")}')

  #clear
  tput cup 0 0
  echo -e "${red}$project ${yellow}node information script version ${blue}$ver     ${clear}"
  echo
  echo -e "${erase}${blue} Protocol    : ${green}$protocol${clear}"
  echo -e "${erase}${blue} Version     : ${green}$version${clear}"
  echo -e "${erase}${blue} Connections : ${green}$connections${clear}"
  echo -e "${erase}${blue} Supply      : ${green}$supply${clear}"
  echo -e "${erase}${blue} Transactions: ${green}$transactions${clear}"
  echo -e "${erase}${blue} MN Count    : ${green}$count${clear}"
  echo -e "${erase}${blue} Last Winner : ${green}$winner${clear}"
  echo -e "${erase}${blue} blocks      : ${yellow}$blocks${clear}"
  echo
  echo -e "${erase}${blue} Sync Status : ${green}${status[$asset]} ${blue}attempt ${yellow}$attempt ${blue}of ${yellow}8                ${clear}"
  echo -e "${erase}${blue} MN Status   : ${green}$mnstatus${clear}"
  echo
  echo -e "${erase}${yellow} ==============================================================================="
  echo -e "${blue}$logresult${clear}"
  echo -e "${erase}${yellow} ===============================================================================${clear}"
  echo -e "${erase}${green} Press CTRL-C to exit. Updated every 2 seconds. ${blue} 2018               @bitmonopoly${clear}"

  sleep 2
done
