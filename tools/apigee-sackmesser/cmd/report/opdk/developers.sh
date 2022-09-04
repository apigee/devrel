echo "<h3>Developers</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/developers"

sackmesser list "organizations/$organization/developers"| jq -r -c '.[]|.' | while read -r developerName; do
        sackmesser list "organizations/$organization/developers/$developerName" > "$export_folder/$organization/config/resources/edge/env/$environment/developers/$developerName".json
        elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/developers/$developerName".json)
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/developers"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/developers"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/developers".json
fi

echo "<div><table id=\"ts-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">UserName</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"name\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"email\">Email</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"status\">Status</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"apps\">Apps</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/developers".json | while read i; do 
    userName=$(echo "$i" | jq -r '.userName')
    firstName=$(echo "$i" | jq -r '.firstName')
    lastName=$(echo "$i" | jq -r '.lastName')
    email=$(echo "$i" | jq -r '.email')
    status=$(echo "$i" | jq -r '.status')
    apps=$(echo "$i" | jq -r '.apps[]')
    approvalType=$(echo "$i" | jq -r '.approvalType')

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<td>$userName</td>"  >> "$report_html"
    echo "<td>"$firstName" "$lastName"</td>"  >> "$report_html"
    echo "<td>$email</td>"  >> "$report_html"
    echo "<td>$status</td>"  >> "$report_html"
    echo "<td>$apps</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div>" >> "$report_html"