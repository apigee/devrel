setup() {

    node_module_path() {
      bats_location=$(which bats);
      echo "${bats_location%/*/*/*/*}";
    }
    
    load "$(node_module_path)/bats-assert/load.bash";
    load "$(node_module_path)/bats-support/load.bash";

    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../src:$PATH"
}

@test "Directory with no shared flows" {
    run gensfds.sh $DIR/no-shared-flows tsort
    
    assert_output 'ERROR: */ directory is not a shared flow file structure. Missing: */sharedflowbundle/policies'
}

@test "Generate dot output" {
    run gensfds.sh $DIR/shared-flows dot
    
    assert_output 'digraph G {
  rankdir=LR
  node [shape=box,fixedsize=true,width=3]
  "add-response-fapi-interaction-id";
  "authenticate-with-private-key-jwt" -> "validate-audience-in-jwt";
  "authenticate-with-private-key-jwt" -> "check-token-not-reused";
  "check-token-not-reused";
  "validate-audience-in-jwt";
}'
}

@test "Generate tsort output" {
    run gensfds.sh $DIR/shared-flows tsort
    
    assert_output 'validate-audience-in-jwt
check-token-not-reused
authenticate-with-private-key-jwt
add-response-fapi-interaction-id'
}
