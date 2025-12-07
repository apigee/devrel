# Apigee Edge to X Migration Tool

## Introduction
The **Apigee Edge to X Migration Tool** is designed to facilitate the seamless transition of entities from Apigee Edge to the new Apigee X platform. This tool streamlines the migration process, ensuring minimal disruption and optimal performance during the transition.

## Features
- **Automated Migration:** Effortlessly migrate your entities from Edge to X.
- **Custom Module Support:** Extend functionality by adding custom modules.
- **User-Friendly Interface:** Navigate through the migration tool with an intuitive prompts menu.
- **Comprehensive Logging:** Track the migration process with detailed logs for troubleshooting and analysis.

## Prerequisites
- **Node.js:** Ensure Node.js is installed on your system.
- **Git:** Required for cloning repositories and managing version control.
- **Access:** 
  - Edge credentials with atleast Read-Only privileges
  - Apigee X Service Account Key

## Setup Instructions

1. **Clone the Repository**
   - Clone the `apigee/devrel` repository to your local machine:
     ```bash
     git clone <git-repo-url>
     ```

2. **Checkout the Relevant Branch**
   - For the release version, checkout the `main` branch:
     ```bash
     git checkout main
     ```

3. **Custom Modules**
   - Custom Modules built in-line to the framework can be used to extend the features.
   - If there are any custom modules, add the code base under `src/modules`.

4. **Environment Setup**
   - `.env` file is required with below information
    ```bash
        # Configure the source gateway type:
        # - apigee_edge
        # - apigee_x
        source_gateway_type="apigee_edge"

        # Configure the base URL for the source gateway's management APIs
        source_gateway_base_url="https://api.enterprise.apigee.com/v1/organizations/"

        # When source gateway is Apigee, configure the name of the Apigee org
        source_gateway_org="<edge-org>"

        # When source gateway is Apigee X, configure the service account
        # used to connect to management APIs. Base64 encode the service account JSON.
        # Ignore if source_gateway_type="apigee_edge" 
        source_gateway_service_account = ""

        # Configure the destination gateway type:
        # - apigee_edge
        # - apigee_x
        destination_gateway_type="apigee_x"

        # Configure the base URL for the destination gateway's management APIs
        destination_gateway_base_url="https://apigee.googleapis.com/v1/organizations/"

        # When destination gateway is Apigee, configure the name of the Apigee org
        destination_gateway_org="<apigee-x-org>"

        # When destination gateway is Apigee X, configure the service account
        # used to connect to management APIs. Base64 encode the service account JSON.
        destination_gateway_service_account = ""

        # When source and destination gateways are both Apigee, configure the mapping
        # between source gateway environment names to destination gateway environment names.
        apigee_environment_map='{"edge-env":"x-env"}'

        # Configure whether to auto-npm-install plugins placed in the ~/src/modules folder
        install_modules = 1
    ```
   - Load Apigee Edge credentials into environment variables
    ```bash
        export source_gateway_username="<edge_username>"
        export source_gateway_password="<edge_password>"
    ```
   - For building the value for `destination_gateway_service_account`, you need to build a JSON file in below structure and must base64encode. Copy the final result as value for `destination_gateway_service_account`
    ```json
        {"instance_type":"hybrid","organization":"<YOUR_PROJECT_ID>","account_json_key":<SERVICE_ACCOUNT_KEY_JSON>}
    ```

    ```bash
        base64 <<< 'above_json_value'
    ```


## Execution Instructions

1. **Open Terminal**
   - Open the terminal or command line interface in the `apigee-edge-to-x-migration-tool` directory.

2. **Launch the Tool**
   - The tool features a setup helper `tool-setup.sh`. Provide execute permissions to the file.
     ```bash
     chmod +x tool-setup.sh
     ```
   - Use the same for the initial set up and auto launch
     ```bash
     ./tool-setup.sh
     ```

3. **Run the Program**
   - After the initial launch, tool presents the Menu options.
   - Whenever you need to launch the tool without the setup helper, in your terminal use the command
   ```bash
     apigee-migration-tool
   ```
4. **Selecting from Menu**
   - Navigate through the program using the arrow keys.
   - Follow the instructions in the menu, user helper text for understanding the option.
   - Press `<enter>` to proceed with your selection.
   - At any time, use `Back` menu option to return to previous menu.
   - At any time, use `Exit` menu option to exit the tool.
   - Primary Action in tool.
    ```bash
      apigee-migration-tool
      ? Choose a tool (Use arrow keys)
      ❯ Apigee Edge to X
    ```
   - Features available in the tool
    ```bash
      apigee-e2x
      ✔ Choose a tool Apigee Edge to X
      ? Action (Use arrow keys)
      ❯ Migrate
        View Logs
    ```

## Migrate
  - Menu option to be selected for migrating entities from Apigee Edge to X.
### Supported Apigee Entities
The tool currently features options to migrate
  - API Proxies (All revisions included)
  - Shared Flows (All revisions included)
  - API Products
  - Developers
  - Developer Apps
  - Key Value Maps (Encrypted KVMs excluded)
  - Resource Files (Enviroment Level Only)

### Execution Model:
  - Once a supported Entity is selected for migration, the tool presents you the options to select an execution model.
  - Recommendation is to select one appropriate to the migration stage.
  1. **Migrate**
    
    - Description:
      - `Migrates entities` only if they do not already exist in the `target environment`.
    - Use When:
      - You're running the migration for the first time or want to avoid overwriting `any existing resources`.
    - Effect:
      - `Skips already existing entities` and `logs them as duplicates` in the `migration summary`.
 
  2. **Synchronize**

    - Description:
      - Compares existing entities between `Apigee Edge (source) and Apigee X (target)`. Only entities with differences are updated.
    - Use When:
      - You want to sync environments safely, ensuring only updated content is migrated.
    - Effect:
      - Identical entities are skipped, and only changed ones are updated. No unnecessary overwrites.
      - For any conflicting values , data in `Apigee X (target)` is considered as final value.
      - Only net new values from `Apigee Edge (source)` will be synchronized.
 
  3. **Overwrite**

    - Description:
      - `Deletes and fully replaces` existing entities in the target environment with those from the source.
    - Use When:
      - You want to fully `refresh or replace` outdated entities in the target system.
    - Effect:
      - Only when entity name matches on both source and target
      - Matched entities in `Apigee X (target)` are `deleted and re-created/migrated` from the source. This is a `destructive operation`, so use with caution.

## View Logs

    - Menu Option to View Status, Summary, Delta Information and Logs.
    - Menu Option, `All Entities` collects information of supported Entities.
    - All the logs are printed to console only. Adjust the console for a better visibility.
    - Any additonal lookup can be done using the data available.
  
  1. **Stats**

    - Select to view migration status of one/all entities.
    - In the sub-menu, select to view by status of migration
  
  2. **Summary**
    
    - Select to view migration summary of one/all entities.
  
  3. **Delta**
    
    - Select to view the delta information identified by comparing source and target entity
  
  4. **Logs**
    
    - Select to view transaction logs.
    - Paginated by 200 records at a time, multiple tables of logs will be provided
  
