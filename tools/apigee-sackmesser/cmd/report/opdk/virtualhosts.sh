echo "<h3>Virtual Hosts</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/virtualhost"

sackmesser list "organizations/$organization/environments/$environment/virtualhosts"| jq -r -c '.[]|.' | while read -r virtualhostname; do
        sackmesser list "organizations/$organization/environments/$environment/virtualhosts/$virtualhostname" > "$export_folder/$organization/config/resources/edge/env/$environment/virtualhost/$virtualhostname".json
        elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/virtualhost/$virtualhostname".json)
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/virtualhost"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/virtualhost"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/virtualhosts".json
fi

echo "<div><table id=\"virtualhost-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"aliases\">Host Aliases</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"port\">Port</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"freecert\">useBuiltInFreeTrialCert</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/virtualhosts".json | while read i; do 
    virtualhostName=$(echo "$i" | jq -r '.name')
    hostAliases=$(echo "$i" | jq -r '.hostAliases[]')
    port=$(echo "$i" | jq -r '.port')
    useBuiltInFreeTrialCert=$(echo "$i" | jq -r '.useBuiltInFreeTrialCert')

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<td>$virtualhostName</td>"  >> "$report_html"
    echo "<td>$hostAliases</td>" >> "$report_html"
    echo "<td>$port</td>" >> "$report_html"
    echo "<td>$useBuiltInFreeTrialCert</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div>" >> "$report_html"