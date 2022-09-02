echo "<h3>Keystores</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/keystore"

sackmesser list "organizations/$organization/environments/$environment/keystores"| jq -r -c '.[]|.' | while read -r keystorename; do
        sackmesser list "organizations/$organization/environments/$environment/keystores/$keystorename" > "$export_folder/$organization/config/resources/edge/env/$environment/keystore/$keystorename".json
        elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/keystore/$keystorename".json)
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/keystore"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/keystore"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/keystores".json
fi

echo "<div><table id=\"keystore-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"keys\">Number of Keys</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"aliases\">Number of Aliases</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"certs\">Number of Certs</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/keystores".json | while read i; do 
    keystoreName=$(echo "$i" | jq -r '.name')
    aliasCount=$(echo "$i" | jq -r '.aliases | length')
    keyCount=$(echo "$i" | jq -r '.keys | length')
    certCount=$(echo "$i" | jq -r '.certs | length')

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<td>$keystoreName</td>"  >> "$report_html"
    echo "<td>$keyCount</td>" >> "$report_html"
    echo "<td>$aliasCount</td>" >> "$report_html"
    echo "<td>$certCount</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div>" >> "$report_html"