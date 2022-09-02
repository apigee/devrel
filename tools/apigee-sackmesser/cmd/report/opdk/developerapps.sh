# echo "<h3>Developer Apps</h3>" >> "$report_html"

# mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/developerapps"

# # sackmesser list "organizations/$organization/developers"| jq -r -c '.[]|.' | while read -r apiProductName; do
# #         sackmesser list "organizations/$organization/developerapps/$apiProductName" > "$export_folder/$organization/config/resources/edge/env/$environment/developerapps/$apiProductName".json
# #         elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/developerapps/$apiProductName".json)
# #     done

# sackmesser list "organizations/$organization/developers" | jq -r -c '.[]|.' | while read -r email; do
#     loginfo "download developer: $email"
#     sackmesser list "organizations/$organization/developers/$email" > "$export_folder/temp/developers/$email".json
#     mkdir -p "$export_folder/temp/developerApps/$email"
#     mkdir -p "$export_folder/temp/importKeys/$email"
#     sackmesser list "organizations/$organization/developers/$email/apps" | jq -r -c '.[]|.' | while read -r appId; do
#         loginfo "download developer app: $appId for developer: $email"
#         full_app=$(sackmesser list "organizations/$organization/developers/$email/apps/$(urlencode "$appId")")
#         echo "$full_app" | jq 'del(.credentials)' > "$export_folder/temp/developerApps/$email/$appId".json
#         echo "$full_app" | jq -r -c '.credentials[]' | while read -r credential; do
#             appkey=$(echo "$credential" | jq -r '.consumerKey')
#             echo "$credential" | jq  --arg APP_NAME "$appId" '. + { name: $APP_NAME } | . + { apiProducts: [.apiProducts[]?.apiproduct] }' > "$export_folder/$organization/config/resources/edge/env/$environment/developerapps/$appId".json
#         done
#     done

# if ls "$export_folder/$organization/config/resources/edge/env/$environment/developerapps"/*.json 1> /dev/null 2>&1; then
#     jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/developerapps"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/developerapps".json
# fi
