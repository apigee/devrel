echo "<h3>Caches</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/cache"

sackmesser list "organizations/$organization/environments/$environment/caches"| jq -r -c '.[]|.' | while read -r cachename; do
        sackmesser list "organizations/$organization/environments/$environment/caches/$cachename" > "$export_folder/$organization/config/resources/edge/env/$environment/cache/$cachename".json
        elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/cache/$cachename".json)
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/cache"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/cache"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/caches".json
fi

echo "<div><table id=\"cache-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"distributed\">Distributed</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"persistent\">Persistent</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"timeout\">Timeout</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/caches".json | while read i; do 
    cacheName=$(echo "$i" | jq -r '.name')
    _isDistributed=$(echo "$i" | jq -r '.distributed')
    _isPersistent=$(echo "$i" | jq -r '.persistent')
    timeout=$(echo "$i" | jq -r '.expirySettings.timeoutInSec.value')

    if [ $_isDistributed = true ]
        then
            isDistributed="✅"
        else
            isDistributed="❌"
    fi

    if [ $_isPersistent = true ]
        then
            isPersistent="✅"
        else
            isPersistent="❌"
    fi

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<td>$cacheName</td>"  >> "$report_html"
    echo "<td>$isDistributed</td>" >> "$report_html"
    echo "<td>$isPersistent</td>" >> "$report_html"
    echo "<td>$timeout</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div>" >> "$report_html"