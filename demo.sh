#!/usr/bin/env bash

# Chat filter demo script to simulate user chat

# Requires: bash curl jq tmux wscat

set -e
set -o pipefail

test -n "$GRPC_SERVER_URL" || (echo "GRPC_SERVER_URL is not set"; exit 1)
test -n "$AB_CLIENT_ID" || (echo "AB_CLIENT_ID is not set"; exit 1)
test -n "$AB_CLIENT_SECRET" || (echo "AB_CLIENT_SECRET is not set"; exit 1)
test -n "$AB_NAMESPACE" || (echo "AB_NAMESPACE is not set"; exit 1)

DEMO_PREFIX='chatv2_grpc_demo'
NUMBER_OF_PLAYERS=2                                 # This script supports 2 players only
GRPC_SERVER_URL="$(echo "$GRPC_SERVER_URL" | sed 's@^.*/@@')"   # Remove leading tcp:// if any

get_code_verifier() 
{
  echo $RANDOM | sha256sum | cut -d ' ' -f 1   # For demo only: In reality, it needs to be secure random
}

get_code_challenge()
{
  echo -n "$1" | sha256sum | xxd -r -p | base64 -w 0 | sed -e 's/\+/-/g' -e 's/\//\_/g' -e 's/=//g'
}

clean_up()
{
  #echo Logging in client ...

  ACCESS_TOKEN="$(curl -s ${AB_BASE_URL}/iam/v3/oauth/token -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" -d "grant_type=client_credentials" | jq --raw-output .access_token)"

  for USER_ID in ${PLAYER_USER_IDS[@]}; do
    echo Deleting player $USER_ID ...
    curl -X DELETE "${AB_BASE_URL}/iam/v3/admin/namespaces/$AB_NAMESPACE/users/$USER_ID/information" -H "Authorization: Bearer $ACCESS_TOKEN"
  done

  echo Resetting chat filter ...

  curl -X PUT -s "${AB_BASE_URL}/chat/v1/admin/config/namespaces/$AB_NAMESPACE" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d "{\"filterParam\":\"\",\"filterType\":\"DEFAULT\",\"enableProfanityFilter\":false}" >/dev/null
}

PLAYER_USER_IDS=()

trap clean_up EXIT

echo Logging in client ...

ACCESS_TOKEN="$(curl -s ${AB_BASE_URL}/iam/v3/oauth/token -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" -d "grant_type=client_credentials" | jq --raw-output .access_token)"

echo Registering chat filter $GRPC_SERVER_URL ...

curl -X PUT -s "${AB_BASE_URL}/chat/v1/admin/config/namespaces/$AB_NAMESPACE" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d "{\"filterParam\":\"${GRPC_SERVER_URL}\",\"filterType\":\"GRPC\",\"enableProfanityFilter\":true}" >/dev/null

echo "Press ENTER to run the user chat simulation"
read

for PLAYER_NUMBER in $(seq $NUMBER_OF_PLAYERS); do
  echo Creating PLAYER $PLAYER_NUMBER ...

  USER_ID="$(curl -s "${AB_BASE_URL}/iam/v4/public/namespaces/$AB_NAMESPACE/users" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d "{\"authType\":\"EMAILPASSWD\",\"country\":\"ID\",\"dateOfBirth\":\"1995-01-10\",\"displayName\":\"Chatv2 gRPC Player\",\"emailAddress\":\"${DEMO_PREFIX}_player_$PLAYER_NUMBER@test.com\",\"password\":\"GFPPlmdb2-\",\"username\":\"${DEMO_PREFIX}_player_$PLAYER_NUMBER\"}" | jq --raw-output .userId)"

  if [ "$USER_ID" == "null" ]; then
    echo "Failed to create player with email ${DEMO_PREFIX}_player_$PLAYER_NUMBER@test.com, please delete existing first!"
    exit 1
  fi

  PLAYER_USER_IDS+=($USER_ID)
done

echo
echo "# KEEP THIS WINDOW OPEN WHILE FOLLOWING INSTRUCTIONS BELOW"
echo 

for i in ${!PLAYER_USER_IDS[@]}; do
  let "PLAYER_NUMBER = $i + 1"
  USER_ID=${PLAYER_USER_IDS[$i]}
  
  CODE_VERIFIER="$(get_code_verifier)" 

  REQUEST_ID="$(curl -s -D - "${AB_BASE_URL}/iam/v3/oauth/authorize?scope=commerce+account+social+publishing+analytics&response_type=code&code_challenge_method=S256&code_challenge=$(get_code_challenge "$CODE_VERIFIER")&client_id=$AB_CLIENT_ID" | grep -o 'request_id=[a-f0-9]\+' | cut -d= -f2)"

  CODE="$(curl -s -D - ${AB_BASE_URL}/iam/v3/authenticate -H 'Content-Type: application/x-www-form-urlencoded' -d "password=GFPPlmdb2-&user_name=${DEMO_PREFIX}_player_$PLAYER_NUMBER@test.com&request_id=$REQUEST_ID&client_id=$AB_CLIENT_ID" | grep -o 'code=[a-f0-9]\+' | cut -d= -f2)"

  PLAYER_TOKEN_RESPONSE="$(curl -s ${AB_BASE_URL}/iam/v3/oauth/token -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" -d "code=$CODE&grant_type=authorization_code&client_id=$AB_CLIENT_ID&code_verifier=$CODE_VERIFIER")"

  PLAYER_USER_ID="$(echo "$PLAYER_TOKEN_RESPONSE" | jq --raw-output .user_id)"
  PLAYER_ACCESS_TOKEN="$(echo "$PLAYER_TOKEN_RESPONSE" | jq --raw-output .access_token)"

  CMD_WSCAT="$(echo wscat -c \'$(echo "${AB_BASE_URL}/chat" | sed 's@^https://@wss://@')\' -H "'Authorization:Bearer $PLAYER_ACCESS_TOKEN'")"

  echo "# For PLAYER $PLAYER_NUMBER: Open a terminal and connect to chat service using wscat with the following command."
  echo 
  echo $CMD_WSCAT
  echo
done

TOPIC_ID=$(date | sha256sum | cut -d ' ' -f 1)

printf -v MEMBERS '"%s",' "${PLAYER_USER_IDS[@]}"

CMD_CREATE_TOPIC="{\"jsonrpc\":\"2.0\",\"method\":\"actionCreateTopic\",\"params\":{\"namespace\":\"${AB_NAMESPACE}\",\"topicId\":\"${TOPIC_ID}\",\"type\":\"GROUP\",\"name\":\"${DEMO_PREFIX}_group\",\"isJoinable\":true,\"members\":[${MEMBERS%,}],\"admins\":[\"${PLAYER_USER_IDS[0]}\"]},\"id\":\"0\"}"
CMD_SEND_CHAT="{\"jsonrpc\":\"2.0\",\"method\":\"sendChat\",\"params\":{\"message\":\"you are so bad\",\"topicId\":\"${TOPIC_ID}\"},\"id\":\"0\"}"

echo "# In PLAYER 1's wscat terminal, send the following JsonRPC to create a chat topic."
echo
echo "$CMD_CREATE_TOPIC"
echo
echo "# Still in PLAYER 1's wscat terminal, send the following JsonRPC to create send a chat to PLAYER 2."
echo
echo "$CMD_SEND_CHAT"
echo
echo "# You will see your chat in PLAYER 2's wscat terminal"
echo
echo "# When you are DONE, press ENTER 3 times to clean up"
read
read
read
