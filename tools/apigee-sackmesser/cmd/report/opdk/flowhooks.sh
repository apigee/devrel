echo "<h3>FlowHooks</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/flowhook"

sackmesser list "organizations/$organization/environments/$environment/flowhooks"| jq -r -c '.[]|.' | while read -r flowhookname; do
        sackmesser list "organizations/$organization/environments/$environment/flowhooks/$flowhookname" > "$export_folder/$organization/config/resources/edge/env/$environment/flowhook/$flowhookname".json
        elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/flowhook/$flowhookname".json)
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/flowhook"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/flowhook"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/flowhooks".json
fi

echo "<div><table id=\"flowhook-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"sharedflow\">Shared Flow</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"contonerr\">Continue On Error</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/flowhooks".json | while read i; do 
    flowhookName=$(echo "$i" | jq -r '.name')
    sharedFlow=$(echo "$i" | jq -r '.sharedFlow')
    _continueOnError=$(echo "$i" | jq -r '.continueOnError')

    if [ $_continueOnError = true ]
        then
            continueOnError="✅"
        else
            continueOnError="❌"
    fi
    if [ $flowhookName != null ]
        then
            echo "<tr class=\"$highlightclass\">"  >> "$report_html"
            echo "<td>$flowhookName</td>"  >> "$report_html"
            echo "<td>$sharedFlow</td>" >> "$report_html"
            echo "<td>$continueOnError</td>" >> "$report_html"
            echo "</tr>"  >> "$report_html"
    fi            
done

echo "</tbody></table></div>" >> "$report_html"