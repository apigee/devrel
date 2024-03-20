#!/bin/bash

JSON_FILE="./test/email-channel.json"
PROJECT_ID=$1

type=$(jq -r '.type' $JSON_FILE)
displayName=$(jq -r '.displayName' $JSON_FILE)
emailAddress=$(jq -r '.labels.email_address' $JSON_FILE)

list_response=$(gcloud alpha monitoring channels list --filter="type='$type' AND displayName=\"$displayName\" AND labels.email_address='$emailAddress'" --format=json --verbosity=none --project=$PROJECT_ID --format=json 2>&1)

if [[ $list_response == "[]" ]]; then

    # create if not existing
    create_response=$(gcloud beta monitoring channels create --channel-content-from-file="$JSON_FILE" --project="$PROJECT_ID" 2>&1)

    if [ $? -eq 0 ]; then
        channel_id=$(echo "$create_response" | grep -oE "projects/"$PROJECT_ID"/notificationChannels/[0-9]+" | awk -F'/' '{print $4}')
        echo "$channel_id"
    else
        echo
    fi
else
    comma_separated=$(echo "$list_response" | jq -r '.[].name' | awk -F'/' '{print $4}' | paste -sd "," -)
    echo "$comma_separated"
fi
