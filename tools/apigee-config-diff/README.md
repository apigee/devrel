# Apigee Config Diff Generator

**A helper tool designed to find differences within files in Apigee Config Maven tree structure.**

It identifies file content changes between 2 commits and generate 2 file tree structures as output:

1. **output/update folder:** containing file structure to be created/updated
2. **output/delete folder:** containing file structure to be deleted

It then **applies [apigee-config-maven-plugin](https://github.com/apigee/apigee-config-maven-plugin)** on **both of those folders** and you're done!

## Requirements

- Python 3
- Maven (mvn)
- tree (optional, for dry run visualization)

## How to run it?

The tool is now consolidated into a single Python script with reasonable defaults.

### Arguments

- `--commit-before`: Previous commit hash (default: `HEAD~1`)
- `--current-commit`: Current commit hash (default: `HEAD`)
- `--folder`: Files folder from repo root to diff (default: `src/`)
- `--output`: Output folder for generated trees (default: `output/`)
- `--confirm`: Execute the Maven plugin (apply changes)

### 1. Dry Run (Generate Plan)

Run the script to diff between two git hashes and see the plan.
By default, it compares `HEAD~1` vs `HEAD` in `src/`.

```bash
# Simplest usage (HEAD~1 vs HEAD)
python main.py

# Specify commits
python main.py --commit-before 2b8d428 --current-commit 4a622b7
```

This will:
1. Compare the commits.
2. Generate output trees in `output/` (default).
3. Display the structure of files to be processed (dry run).

### 2. Execute (Apply Changes)

To actually apply the changes using the Apigee Maven Plugin, add the `--confirm` flag:

```bash
python main.py --confirm
```

This will execute `mvn install` on the generated file structures.

**Authentication Note:**
Ensure you have configured your **authentication to Apigee** on `pom.xml`:
- Change `<apigee.serviceaccount.file>/tmp/sa.json</apigee.serviceaccount.file>` to your service account key location.
- Or else, change for `<apigee.bearer>${bearer}</apigee.bearer>` and populate the `bearer` env variable.

**Tip:** it's recommended to add those steps in a pipeline triggered by commit.

## Folder structure

This repository expects the following Apigee file structure (it's the same as Apigee Config Maven Plugin).

In the example run above, the file tree below would be inside `src/` (at the root of git repository):

```
<org-name>
  ├── api
  │   ├── forecastweatherapi
  │   │   ├── kvms.json
  │   │   ├── kvms-security.json
  │   └── oauth
  │       ├── kvms.json
  ├── env
  │   ├── <prod>
  │   │   ├── kvms.json
  │   │   ├── kvms-targets.json
  │   │   ├── flowhooks.json
  │   │   ├── targetServers.json
  │   │   ├── references.json
  │   ├── <test>
  │   │   ├── kvms.json
  │   │   ├── targetServers.json
  │   │   ├── targetServers-backend.json
  │   │   ├── keystores.json
  │   │   ├── keystores-signed.json
  │   │   ├── aliases.json
  │   │   └── references.json
  └── org
      ├── apiProducts.json
      ├── appGroups.json
      ├── appGroupApps.json          
      ├── developerApps.json
      ├── developers.json
      ├── kvms.json
      ├── reports.json
      └── importKeys.json
```

## Notes

- **org-name** and folders directly inside **env** must be the actual correct names for your organizations/environments. You can have multiple organizations and multiple environments.

- Each file for each type **must** start with the correct naming convention, but the suffix may change, like **targetServers.json** and **targetServers-backend.json**.
