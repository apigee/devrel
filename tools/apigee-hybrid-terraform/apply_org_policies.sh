read -p "Please enter your Google Cloud project ID: " project
export project

if [ -z "$project" ]; then
  echo "Error: The 'project' variable is not set. Please set it before proceeding."
  exit 1
fi

apply_constraints() {
	echo "Applying organization policies to ${project}..."
	gcloud beta resource-manager org-policies disable-enforce compute.requireShieldedVm --project="${project}"
	gcloud beta resource-manager org-policies disable-enforce compute.requireOsLogin --project="${project}"
	gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountCreation --project="${project}"
	gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project="${project}"
	gcloud beta resource-manager org-policies disable-enforce compute.skipDefaultNetworkCreation --project="${project}"

	declare -a policies=("constraints/compute.trustedImageProjects"
		"constraints/compute.vmExternalIpAccess"
		"constraints/compute.restrictSharedVpcSubnetworks"
		"constraints/compute.restrictSharedVpcHostProjects"
		"constraints/compute.restrictVpcPeering"
		"constraints/compute.vmCanIpForward"
	)

	for policy in "${policies[@]}"; do
		cat <<EOF >new_policy.yaml
constraint: $policy
listPolicy:
 allValues: ALLOW
EOF
		gcloud resource-manager org-policies set-policy new_policy.yaml --project="${project}"
	done
	echo "Allow upto 30 seconds to Propagate the policy changes"
	sleep 30
	echo "Policy Changes done"
}

apply_constraints 
