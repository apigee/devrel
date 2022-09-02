echo "<h3>Key Value Maps</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/kvm"

sackmesser list "organizations/$organization/environments/$environment/keyvaluemaps"| jq -r -c '.[]|.' | while read -r kvmname; do
        sackmesser list "organizations/$organization/environments/$environment/keyvaluemaps/$kvmname" > "$export_folder/$organization/config/resources/edge/env/$environment/kvm/$kvmname".json
        elem_count=$(jq '.entries? | length' "$export_folder/$organization/config/resources/edge/env/$environment/kvm/$kvmname".json)
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/kvm"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/kvm"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/kvms".json
fi

echo "<div><table id=\"kvm-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"encrypted\">Encrypted</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"keys\">Number of Keys</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/kvms".json | while read i; do 
    kvmName=$(echo "$i" | jq -r '.name')
    _encrypted=$(echo "$i" | jq -r '.encrypted')
    keyCount=$(echo "$i" | jq -r '.entry | length')

    if [ $_encrypted = true ]
        then
            encrypted="✅"
        else
            encrypted="❌"
    fi

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<td>$kvmName</td>"  >> "$report_html"
    echo "<td>"$encrypted"</td>"  >> "$report_html"
    echo "<td>$keyCount</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div>" >> "$report_html"