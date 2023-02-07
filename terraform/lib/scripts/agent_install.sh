#!/bin/bash
	
#######
## INIT
######

export ES_VERSION=${elastic_version}
export CLOUD_AUTH=${elasticsearch_username}:${elasticsearch_password}
export CLOUD_ID=${elastic_cloud_id}
export USERNAME=${elasticsearch_username}
export PASSWORD=${elasticsearch_password}
export KIBANA_URL=${kibana_endpoint}
export APM_SERVER_URL=${integration_server_endpoint}
integration_server_endpoint=${integration_server_endpoint}
export FLEET_URL=${fleet_server_endpoint}
export HOST_POLICY_ID=${policy_id}


echo "deb http://us.archive.ubuntu.com/ubuntu vivid main universe" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get --assume-yes install jq

#########
## install agent
#########

## get version
version=$(curl -XGET -u $CLOUD_AUTH "$${KIBANA_URL}/api/status" -H "kbn-xsrf: true" -H "Content-Type: application/json" | jq -r '.version.number')
echo ES_VERSION=$version >> /etc/.env
export ES_VERSION=$version

echo "Command: curl -XGET -u $CLOUD_AUTH \"$${KIBANA_URL}/api/fleet/enrollment_api_keys\""

response=$(curl -XGET -u $CLOUD_AUTH "$${KIBANA_URL}/api/fleet/enrollment_api_keys" -H "kbn-xsrf: true" -H "Content-Type: application/json") 
echo $response 

echo "using $${HOST_POLICY_ID}"

endpoint_enroll_key=$( jq -r --arg policy_id "$${HOST_POLICY_ID}" '.list[] | select(.policy_id == $policy_id) | .api_key' <<< "$${response}" )
export HOST_ENROLL_KEY=$endpoint_enroll_key
echo HOST_ENROLL_KEY=$endpoint_enroll_key >> /etc/.env

echo "Loading agent"
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$ES_VERSION-linux-x86_64.tar.gz
sleep 30

echo "Unpack agent"
tar xzvf elastic-agent-$ES_VERSION-linux-x86_64.tar.gz
cd elastic-agent-$ES_VERSION-linux-x86_64

echo "Install agent"
echo "Command: ./elastic-agent install --url=$FLEET_URL --enrollment-token=$HOST_ENROLL_KEY -f"
./elastic-agent install --url=$FLEET_URL --enrollment-token=$HOST_ENROLL_KEY -f
cd ..
rm elastic-agent-$ES_VERSION-linux-x86_64 -r
rm elastic-agent-$ES_VERSION-linux-x86_64.tar.gz

#########
## install workshop app
#########

sudo apt-get --assume-yes install npm
sudo apt-get --assume-yes install python3-pip

echo "Clone repo"
cd "/home/ubuntu"
git clone --recurse-submodules "https://github.com/LucaWintergerst/workshop-draft.git"

echo "Install lambda function"
cd "/home/ubuntu/workshop-draft/aws-lambda/lambda-application"
npm install -g n
npm install -g serverless
npm install --save-dev
n stable
hash -r

jq -n --arg aws-region "${aws_region}" --arg apm-server-url "${integration_server_endpoint}" --arg apm-server-token "${apm_secret_token}" '$ARGS.named' > ../env.json
serverless config credentials --profile pme --provider aws --key ${aws_access_key_id} --secret ${aws_secret_access_key}

serverless deploy --force --aws-profile pme > lambda-urls.txt
lambda_url=$(grep -Eo '://[^ >]+' lambda-urls.txt | head -1)

echo "Load lambda history"
cd "/home/ubuntu/workshop-draft/lambda-generator"
pip install -r requirements.txt
python3 generate.py &

echo "Install python app"
cd "/home/ubuntu/workshop-draft/python-app"

pip install boto3 flask python-dotenv ecs_logging structlog cachetools elastic-apm

echo aws_access_key_id=${aws_access_key_id} >> .env
echo aws_secret_access_key=${aws_secret_access_key} >> .env
echo SERVER_URL=${integration_server_endpoint} >> .env
echo SECRET_TOKEN=${apm_secret_token} >> .env
echo SERVICE_NAME="python-app" >> .env
echo aws_lambda_url="httpss$${lambda_url}"  >> .env

chown ubuntu /home/ubuntu/workshop-draft/* -R
chmod 777 /home/ubuntu/workshop-draft/python-app/fixPerformanceIssue.sh 

echo "Start workshop app"
python3 app1.py &
sleep 5
python3 loadgen.py &
