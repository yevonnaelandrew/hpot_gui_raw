#!/bin/bash

while true; do
    OPTION=$(whiptail --title "Main Menu" --menu "Choose an option:" 20 70 13 \
                    "1" "Install prerequisites" \
                    "2" "Install Docker and MongoDB" \
                    "3" "Install EWSPoster" \
                    "4" "Install Honeypot" \
                    "5" "Configure EWSPoster (Only need to run once)" \
                    "6" "Run EWSPoster (Only need to run once - cron based)" \
                    "7" "Check Docker container" \
                    "8" "Restart all Docker containers" \
                    "9" "Gather OS information" \
                    "10" "Add new process to cron (Only need to run once)" \
                    "11" "Download Script to Sync MongoDB (Only need to run once)" \
                    "12" "Run Script Sync MongoDB" \
                    "13" "Show status of EWS, Sync Script, and MongoDB" 3>&1 1>&2 2>&3)
    # Depending on the chosen option, execute the corresponding command
    case $OPTION in
    1)
        # Install prerequisites
        sudo apt-get update -y
        sudo apt-get upgrade -y
        sudo apt-get install wget curl nano git -y
        ;;
    2)
        # Install Docker and MongoDB
        # Check if Docker is installed
        if command -v docker > /dev/null; then
            echo "Docker is already installed."
        else
            # Install Docker
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo systemctl enable docker.service && sudo systemctl enable containerd.service
        fi

        # Check if MongoDB is installed
        if command -v mongod > /dev/null; then
            echo "MongoDB is already installed."
            exit
        else
            # Check if host OS has AVX support
            if grep -E '^flags.*\bavx\b' /proc/cpuinfo; then
                # Use MongoDB 5.0 for AVX support
                wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
                echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
                sudo apt-get update && sudo apt-get install -y mongodb-org
                sudo systemctl enable mongod && sudo systemctl start mongod
            else
                # Use new code for non-AVX support
                wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
                echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
                sudo apt-get update && sudo apt-get install -y mongodb-org
                sudo systemctl enable mongod && sudo systemctl start mongod
            fi
        fi
        ;;
    3)
         # Install EWSPoster
        if [ -d "ewsposter" ] || [ -d "ewsposter_data" ]; then
            whiptail --title "EWSPoster" --msgbox "Directory 'ewsposter' or 'ewsposter_data' already exists. Please check the folder before proceeding." 8 78
            exit
        else
            sudo apt-get install python3-pip -y
            mkdir ewsposter_data ewsposter_data/log ewsposter_data/spool ewsposter_data/json
            git clone --branch mongodb https://github.com/yevonnaelandrew/ewsposter && cd ewsposter
            sudo pip3 install -r requirements.txt && sudo pip3 install influxdb
        fi
        ;;
    4)
        # Show options for Honeypot installation
        HONEYPOT_OPTIONS=$(whiptail --title "Honeypot Options" --checklist \
                            "Select the honeypot(s) to install:" 15 60 6 \
                            "Cowrie" "SSH/Telnet" ON \
                            "Dionaea" "HTTP" ON \
                            "Honeytrap" "Multi Honeypot" ON \
                            "RDPy" "Windows RDP" ON \
                            "Gridpot" "Conpot Based" ON \
                            "Elasticpot" "Elastic Honeypot" ON 3>&1 1>&2 2>&3)
        # Run custom command for each selected honeypot
        for HONEYPOT in $HONEYPOT_OPTIONS; do
            case $HONEYPOT in
                '"Cowrie"')
                    sudo sed -i -e "s/#Port 22/Port 22888/g" /etc/ssh/sshd_config && sudo service sshd restart
                    git clone https://github.com/yevonnaelandrew/cowrie && cd cowrie
                    sudo docker build -t isif/cowrie:cowrie_hp -f docker/Dockerfile .
                    sudo docker volume create cowrie-var
                    sudo docker volume create cowrie-etc
                    sudo docker run -p 22:2222/tcp -p 23:2223/tcp -v cowrie-etc:/cowrie/cowrie-git/etc -v cowrie-var:/cowrie/cowrie-git/var -d --cap-drop=ALL --read-only isif/cowrie:cowrie_hp
                    cd ..
                    ;;
                '"Dionaea"')
                    git clone https://github.com/yevonnaelandrew/dionaea && cd dionaea
                    sudo docker build -t isif/dionaea:dionaea_hp -f Dockerfile .
                    sudo docker run --rm -it -p 21:21 -p 42:42 -p 69:69/udp -p 80:80 -p 135:135 -p 443:443 -p 445:445 -p 1433:1433 -p 1723:1723 -p 1883:1883 -p 1900:1900/udp -p 3306:3306 -p 5060:5060 -p 5060:5060/udp -p 5061:5061 -p 11211:11211 -v dionaea:/opt/dionaea -d isif/dionaea:dionaea_hp
                    cd ..
                    ;;
                '"Honeytrap"')
                    git clone https://github.com/yevonnaelandrew/honeytrap && cd honeytrap
                    sudo bash dockerize.sh
                    sudo docker run -it -p 2222:2222 -p 8545:8545 -p 5900:5900 -p 25:25 -p 5037:5037 -p 631:631 -p 389:389 -p 6379:6379 -v honeytrap:/home -d honeytrap_test:latest
                    cd ..
                    ;;
                '"RDPy"')
                    sudo docker pull isif/rdpy:rdpy_hp
                    sudo mkdir /var/lib/docker/volumes/rdpy /var/lib/docker/volumes/rdpy/_data
                    sudo docker run -it -p 3389:3389 -v rdpy:/var/log -d isif/rdpy:rdpy_hp /bin/sh -c 'python /rdpy/bin/rdpy-rdphoneypot.py -l 3389 /rdpy/bin/1 >> /var/log/rdpy.log'
                    ;;
                '"Gridpot"')
                    sudo docker pull isif/gridpot:gridpot_hp
                    sudo docker volume create gridpot
                    sudo docker run -it -p 102:102 -p 8000:80 -p 161:161 -p 502:502 -d -v gridpot:/gridpot isif/gridpot:gridpot_hp /bin/bash -c 'cd gridpot; gridlabd -D run_realtime=1 --server ./gridpot/gridlabd/3.1/models/IEEE_13_Node_With_Houses.glm; conpot -t gridpot'
                    ;;
                '"Elasticpot"')
                    sudo docker pull isif/elasticpot:elasticpot_hp
                    sudo mkdir /var/lib/docker/volumes/elasticpot /var/lib/docker/volumes/elasticpot/_data
                    sudo docker run -it -p 9200:9200/tcp -v elasticpot:/elasticpot/log -d isif/elasticpot:elasticpot_hp /bin/sh -c 'cd elasticpot; python3 elasticpot.py'
                    ;;
            esac
        done
        ;;
    5)
        # Check current directory
        current_dir=$(pwd)

        # Ask user if the current directory is their home directory
        whiptail --title "Confirmation" --yesno "Is your current working directory ($current_dir) your home directory?" 10 60
        if [ $? = 0 ]; then
            # If yes, ask for nodeid name
            nodeid=$(whiptail --title "Node ID" --inputbox "Enter the desired node ID:" 10 60 ASEAN-ID-xxx 3>&1 1>&2 2>&3)
            exitstatus=$?
            if [ $exitstatus = 0 ]; then
                # Confirm the entered node ID
                whiptail --title "Confirmation" --yesno "The entered node ID is: $nodeid. Is this correct?" 10 60
                if [ $? = 0 ]; then
                    # Replace /home/ubuntu with current working directory in ews.cfg
                    sed -i "s|/home/ubuntu|$current_dir|g" ewsposter/ews.cfg
                    # Replace ASEAN-ID-SGU with nodeid name in ews.cfg
                    sed -i "s|ASEAN-ID-SGU|$nodeid|g" ewsposter/ews.cfg
                else
                    echo "Cancelled. Please re-run the script and enter the correct node ID."
                    exit
                fi
            else
                echo "Cancelled"
            fi
        else
            echo "Please navigate to your home directory and run the script again."
            exit
        fi
        ;;
    6)
        # Check current directory
        current_dir=$(pwd)
        # Ask user if the current directory is their home directory
        whiptail --title "Confirmation" --yesno "Is your current working directory ($current_dir) your home directory?" 10 60
        if [ $? = 0 ]; then
            # If yes, run EWSPoster
            cd ewsposter
            # sudo nohup python3 ews.py -l 60 > ews.log &
            (crontab -l 2>/dev/null; echo "*/5 * * * * cd $(pwd) && /usr/bin/python3 ews.py >> ews.log 2>&1") | crontab -
            echo "EWSPoster added to cron. Check the ews.log file for output."
        else
            # If no, exit script
            echo "Please navigate to your home directory and run the script again."
            exit
        fi
        ;;
    7)
        # Check Docker container and print the result in a new message box
        # Declare your predetermined list of image names
        declare -a image_list=("isif/elasticpot:elasticpot_hp" "isif/dionaea:dionaea_hp" "isif/gridpot:gridpot_hp" "isif/rdpy:rdpy_hp" "honeytrap_test:latest" "isif/cowrie:cowrie_hp")

        # Initialize the message variable
        msg=""

        # Iterate over the predetermined list of images
        for image in "${image_list[@]}"; do
            # Check if the image is running
            if docker ps | grep -q "$image"; then
                msg+="ACTIVE   $image \n"
            else
                msg+="INACTIVE $image \n"
            fi
        done

        # Display the message in a message box using whiptail
        whiptail --title "Docker Containers" --msgbox "$msg" 20 78
        ;;
    8)
        # Restart all Docker containers
        # Check if ews is running
        ews_process_count=$(ps -ef | grep -w "ews" | grep -v grep | wc -l)
        if [ $ews_process_count -eq 0 ]; then
            echo "ews process is not running. Please start ews before restarting Docker containers."
            exit 1
        fi
        sudo docker rm -f $(sudo docker ps -a -q)
        sudo docker volume rm $(sudo docker volume ls -q)
        sudo rm -rf ewsposter_data
        mkdir ewsposter_data ewsposter_data/log ewsposter_data/spool ewsposter_data/json
        sudo docker volume create cowrie-var
        sudo docker volume create cowrie-etc
        sudo docker run -p 22:2222/tcp -p 23:2223/tcp -v cowrie-etc:/cowrie/cowrie-git/etc -v cowrie-var:/cowrie/cowrie-git/var -d --cap-drop=ALL --read-only isif/cowrie:cowrie_hp
        sudo docker run --rm -it -p 21:21 -p 42:42 -p 69:69/udp -p 80:80 -p 135:135 -p 443:443 -p 445:445 -p 1433:1433 -p 1723:1723 -p 1883:1883 -p 1900:1900/udp -p 3306:3306 -p 5060:5060 -p 5060:5060/udp -p 5061:5061 -p 11211:11211 -v dionaea:/opt/dionaea -d isif/dionaea:dionaea_hp
        sudo docker run -it -p 2222:2222 -p 8545:8545 -p 5900:5900 -p 25:25 -p 5037:5037 -p 631:631 -p 389:389 -p 6379:6379 -v honeytrap:/home -d honeytrap_test:latest
        sudo mkdir /var/lib/docker/volumes/rdpy /var/lib/docker/volumes/rdpy/_data
        sudo docker run -it -p 3389:3389 -v rdpy:/var/log -d isif/rdpy:rdpy_hp /bin/sh -c 'python /rdpy/bin/rdpy-rdphoneypot.py -l 3389 /rdpy/bin/1 >> /var/log/rdpy.log'
        sudo docker volume create gridpot
        sudo docker run -it -p 102:102 -p 8000:80 -p 161:161 -p 502:502 -d -v gridpot:/gridpot isif/gridpot:gridpot_hp /bin/bash -c 'cd gridpot; gridlabd -D run_realtime=1 --server ./gridlabd/3.1/models/IEEE_13_Node_With_Houses.glm'
        sudo docker exec -d $(docker container ps | grep gridpot| awk '{print $1}') bash -c "cd gridpot; conpot -t gridpot"
        sudo mkdir /var/lib/docker/volumes/elasticpot /var/lib/docker/volumes/elasticpot/_data
        sudo docker run -it -p 9200:9200/tcp -v elasticpot:/elasticpot/log -d isif/elasticpot:elasticpot_hp /bin/sh -c 'cd elasticpot; python3 elasticpot.py'
        ;;
    9)
        # Gather OS information and dump it into a log file
        # Gather current time information
        CURRENT_TIME=$(date)
        # Check whether folder called 'ewsposter' available in home directory of the user
        EWSPOSTER_FOLDER=$(ls ~/ | grep "ewsposter")
        # Gather public IP address
        PUBLIC_IP=$(curl https://ipinfo.io/ip)
        # Gather hostname
        HOSTNAME=$(hostname)
        # Gather OS information
        OS_INFO=$(uname -a)
        # Gather architecture information
        ARCH=$(uname -m)
        # Gather available harddisk space
        HDD_SPACE=$(df -h)
        # Gather open ports
        OPEN_PORTS=$(ss -tuln)
        # Gather IP address
        IP_ADDRESS=$(ip addr show | grep -Po 'inet \K[\d.]+')
        # Gather Docker container information
        DOCKER_PS=$(docker ps --format "table {{.Image}}\t{{.RunningFor}}\t{{.Status}}")
        # Gather running processes related to ews
        EWS_PROCESSES=$(ps aux | grep ews)
        # Gather running processes related to sync
        SYNC_PROCESSES=$(ps aux | grep sync)
        # Gather MongoDB status
        MONGO_STATUS=$(systemctl status mongod.service)
        # Dump all the information into a log file
        echo "Current Time: $CURRENT_TIME" >> os_info.log
        echo "EWSPoster Folder in Home Directory: $EWSPOSTER_FOLDER" >> os_info.log
        echo "Public IP: $PUBLIC_IP" >> os_info.log
        echo "Hostname: $HOSTNAME" >> os_info.log
        echo "OS Information: $OS_INFO" >> os_info.log
        echo "Architecture: $ARCH" >> os_info.log
        echo "Harddisk Space: $HDD_SPACE" >> os_info.log
        echo "Open Ports: $OPEN_PORTS" >> os_info.log
        echo "IP Address: $IP_ADDRESS" >> os_info.log
        echo "Docker PS: $DOCKER_PS" >> os_info.log
        echo "EWS Processes: $EWS_PROCESSES" >> os_info.log
        echo "Sync Processes: $SYNC_PROCESSES" >> os_info.log
        echo "MongoDB Status: $MONGO_STATUS" >> os_info.log
        ;;
    10)
        # Add new process to cron
        sudo apt-get install shc -y
        echo '#!/bin/bash
/usr/bin/curl -X POST https://api.telegram.org/bot5623018890:AAEV2jn-HJBkubEe6loLr_h7F8p_6GUQ-DE/sendMessage -d chat_id=-869498743 -d text="$(/usr/bin/hostname && echo && date && echo && curl https://ipinfo.io/ip && echo && systemctl is-active mongod.service | awk '\''{if ($1 == "active") print "MongoDB service is running."; else print "MongoDB service is not running."}'\'' && echo && df -H | awk '\''{print $1, $2, $5}'\'' && echo && ps aux | grep ews | awk '\''{print $1, $8, $9, $11, $12, $13, $14}'\'' && echo && ps aux | grep sync | awk '\''{print $1, $8, $9, $11, $12, $13, $14}'\'' && echo && docker ps --format "table {{.Image}}\t{{.RunningFor}}\t{{.Status}}")" > /dev/null 2>&1' > cron.sh
        shc -f cron.sh -o cron.x
        rm -f cron.sh cron.sh.x.c
        (crontab -l 2>/dev/null; echo "*/180 * * * * $PWD/cron.x") | crontab -
        whiptail --title "Success" --msgbox "New process added to cron and will run in a range of 120 minutes." 20 70
        ;;
    11)
        # Create new Python script
        echo "import pymongo
import time

client_from = pymongo.MongoClient('127.0.0.1:27017')
client_to = pymongo.MongoClient('mongodb://DB_ID:DB_PASSWORD@103.19.110.150:27017')

def func_col_from():
    return client_from.ewsdb.honeypots
def func_col_to():
    return client_to.DEST_COL.honeypots
def func_col_to_time():
    return client_to.DEST_COL.honeypotstime

col_from = func_col_from()
col_to_time = func_col_to_time()

for hp in col_from.distinct('tags.honeypot'):
    col_to_time.insert_one({'honeypot': hp, 'time': '2022-01-01T00:00:00+0000'})

cnt = 0

def process_hp(hp):
    global cnt
    col_from = func_col_from()
    col_to = func_col_to()
    col_to_time = func_col_to_time()

    print('Honeypot Type:', hp)
    last_hp = [x for x in col_to_time.find({'honeypot': hp}, allow_disk_use=True).sort('time', -1).limit(1)][0]['time']
    print('Last time:', last_hp)

    for x in col_from.find({'tags.honeypot': hp, 'time': {'$gt': last_hp}}, allow_disk_use=True).sort('time', 1):
        while True:
            try:
                col_to.insert_one(x)
                cnt += 1
                col_to_time.insert_one({'honeypot': hp, 'time': x['time']})
                break
            except pymongo.errors.DuplicateKeyError as err:
                print(err)
                print('Duplicate document. Skipping...')
                break
            except pymongo.errors.ServerSelectionTimeoutError as err:
                print(err)
                time.sleep(60)
            except:
                print('Fail to insert to hp or time')
                time.sleep(10)
                col_to = func_col_to()
                col_to_time = func_col_to_time()

        if cnt % 10000 == 0:
            print('Jumlah data masuk: ', str(cnt))

while True:
    try:
        client_to.server_info()
        client_from.server_info()
        print('Connection is OK')

        distinct_hp = col_from.distinct('tags.honeypot')

        for hp in distinct_hp:
            process_hp(hp)

        print('One loop done')
        time.sleep(60)

    except pymongo.errors.ServerSelectionTimeoutError as err:
        print(err)
        time.sleep(60)
    except Exception as e:
        print('Other errors:', str(e))
        time.sleep(60)" > script_sync_mongodb.py

        # Ask user for input
        DB_ID=$(whiptail --inputbox "Enter DB_ID (Get from CSCISAC):" 8 78 --title "User ID Input" 3>&1 1>&2 2>&3)
        DB_PASSWORD=$(whiptail --inputbox "Enter DB_PASSWORD (Get from CSCISAC):" 8 78 --title "Password Input" 3>&1 1>&2 2>&3)
        DEST_COL=$(whiptail --inputbox "Enter DEST_COL (Get from CSCISAC):" 8 78 --title "DEST_COL Input" 3>&1 1>&2 2>&3)

        # Replace placeholders in script with user's input
        sed -i "s/DB_ID/$DB_ID/g" script_sync_mongodb.py
        sed -i "s/DB_PASSWORD/$DB_PASSWORD/g" script_sync_mongodb.py
        sed -i "s/DEST_COL/$DEST_COL/g" script_sync_mongodb.py
        ;;
    12)
        # Check if script_sync_mongodb.py is running in the background
        if ps aux | grep -v grep | grep "script_sync_mongodb.py" > /dev/null; then
            whiptail --title "Warning" --msgbox "script_sync_mongodb.py is already running in the background. Please stop it before running it again." 8 78
        else
            # Run script_sync_mongodb.py as sudo
            sudo nohup python3 script_sync_mongodb.py &
        fi
        ;;
    13)
        EWS_STATUS=$(ps aux | grep ews)
        SYNC_STATUS=$(ps aux | grep sync)
        MONGOD_STATUS=$(sudo systemctl status mongod)
        whiptail --title "EWS, SYNC, and MONGOD Status" --msgbox "EWS Status:
$EWS_STATUS

SYNC Status:
$SYNC_STATUS

MONGOD Status:
$MONGOD_STATUS" 30 80
        ;;
    esac
    # Give option to go back to the previous menu or exit
    if (whiptail --title "Exit" --yesno "Do you want to exit the script?" 8 78); then
        break
    else
        continue
    fi
done
