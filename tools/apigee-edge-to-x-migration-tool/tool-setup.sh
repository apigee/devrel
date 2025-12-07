#!/usr/bin/env bash
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Define tool name
TOOL_NAME="apigee-edge-to-x-migration-tool"

# Function to display banner
display_banner() {
	echo "==================================="
	echo "          $TOOL_NAME setup         "
	echo "==================================="
}

# Function to check if Node.js is installed
check_node() {
	if command -v node >/dev/null 2>&1; then
		echo "Node.js is installed."
	else
		echo "Node.js is not installed. Please install Node.js first."
		exit 1
	fi
}

# Function to set up the tool
setup_tool() {
	echo "Setting up $TOOL_NAME..."

	# Check if package.json exists, if not initialize npm
	if [ ! -f package.json ]; then
		echo "Initializing npm..."
		npm init -y
	fi

	# Install necessary packages
	echo "Installing necessary packages..."
	npm install @inquirer/prompts
	node install-modules.js
	echo "$TOOL_NAME setup complete."
}

# Function to initialize the tool
init_tool() {
	echo "Initializing $TOOL_NAME..."

	npm link

	echo "Initialization done"
	echo "Command to Launch Tool : apigee-e2x"
	echo "Launching the tool"
	apigee-e2x

}

# Main script execution
display_banner
check_node
setup_tool
init_tool

exit 0
