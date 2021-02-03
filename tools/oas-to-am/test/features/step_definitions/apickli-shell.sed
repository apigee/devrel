# Apickli-provided step definitions

## Remove empty lines, leading spaces and echo non-executable lines
/^\s*$/d
s/^\s*\(.*\)/\1/
/\s*Given\|When\|Then\|And/! s/\(.*\)/echo "\1"/

# Add new line before each Scenario to scope variables
s/.*Scenario/\n&/

## Given I run command (cmd)
s/\s*\(Given\|And\) I run \(.*\)/echo "&" \
\2 > \/dev\/null /

## Given I set variable (var name) to (value)
s/\s*\(Given\|And\) I set variable \(.*\) to \(.*\)/echo "&" \
\2=\3/

## When I successfully run (cmd)
s/\s*\(When\|And\) I successfully run \(.*\)/echo "&" \
RESULT=$(\2)/

## When I fail to run
s/\s*\(When\|And\) I fail to run \(.*\)/echo "&" \
! RESULT=$(\2)/

## Then result contains (string)
s/\s*\(Then\|And\) result contains \(.*\)/echo "&" \
echo "$RESULT" | grep -q \2/

## Then result does not contain (string)
s/\s*\(Then\|And\) result does not contain \(.*\)/echo "&" \
echo "$RESULT" | grep -q -v \2/

## Then on the result, I run (cmd)
s/\s*\(Then\|And\) on the result, I run \(.*\)/echo "&" \
echo "$RESULT" | \2 > \/dev\/null/

## Then I can now successfully run
s/\s*\(Then\|And\) I can now successfully run \(.*\)/echo "&" \
\2 > \/dev\/null/

## Then result JSON (jq path) should be (value)
s/\s*\(Then\|And\) result JSON \(.*\) should be \(.*\)/echo "&" \
echo "$RESULT" | test $(jq -r -e '\2') == \3 /

## Then result JSON (jq path) should not be (value)
s/\s*\(Then\|And\) result JSON \(.*\) should not be \(.*\)/echo "&" \
echo "$RESULT" | test $(jq -r -e '\2') != \3 /

