<p align="center">
  <img src="logo.svg" alt="Apigee Config Diff Generator Logo" width="500">
</p>

# Apigee Config Diff Generator

**Deploy only what changed in your Apigee configurations.**

This tool finds differences in Apigee Configuration files (KVMs, Target Servers, API Products, etc.) between two Git commits and uses the [Apigee Config Maven Plugin](https://github.com/apigee/apigee-config-maven-plugin) to apply only those changes.

## Why use this?

Standard Apigee configuration deployments often re-deploy the entire configuration set, which can be slow and risky for large organizations. This tool allows for **incremental deployments**:
- **Speed:** Only process files and resources that actually changed.
- **Safety:** Reduce the risk of accidental overwrites of stable configurations.
- **CI/CD Friendly:** Designed to run in pipelines (Jenkins, GitHub Actions, GitLab, etc.).

---

## How it Works

1. **Diff:** Compares two Git commits (e.g., `HEAD~1` vs `HEAD`).
2. **Generate:** Creates two temporary trees in `output/`:
   - `update/`: New or modified resources.
   - `delete/`: Resources removed or items deleted from within modified files.
3. **Deploy:** Runs `mvn install` on both trees with the `update` or `delete` option.

---

## Quick Start

### 1. Requirements
- Python 3.9+
- Maven (`mvn`) installed and in your PATH.
- (Optional) `tree` command for better dry-run visualization.

### 2. Basic Usage (Dry Run)
By default, the tool compares `HEAD~1` with `HEAD` in the `src/` directory.

```bash
python main.py
```

### 3. Deploy Changes
Add the `--confirm` flag to actually execute the Maven commands.

```bash
python main.py --confirm
```

---

## Configuration & Arguments

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--commit-before` | `HEAD~1` | Previous commit hash to compare. |
| `--current-commit` | `HEAD` | Current commit hash. |
| `--folder` | `src` | Folder containing the Apigee config tree. |
| `--output` | `output` | Where to generate the temporary diff trees. |
| `--confirm` | `False` | Must be present to execute `mvn` commands. |
| `--bearer` | `None` | Optional: Apigee bearer token to use for Maven. |
| `--sa-path` | `None` | Optional: Path to the service account key file. |

### Authentication
The tool passes authentication flags directly to the Maven command. You can provide them in three ways:

1. **Command Line (Recommended):**
   ```bash
   python main.py --confirm --bearer "$(gcloud auth print-access-token)"
   # OR
   python main.py --confirm --sa-path /tmp/sa.json
   ```

2. **Environment Variables:**
   If your `pom.xml` is configured to use environment variables (e.g., `${env.bearer}`), simply export them before running the script:
   ```bash
   export bearer=$(gcloud auth print-access-token)
   python main.py --confirm
   ```

3. **POM Configuration:**
   Hardcode the service account path or token directly in your `pom.xml` (not recommended for CI/CD).

---

## Expected Folder Structure
The tool expects the standard Maven config structure inside your `--folder` (default `src/`):

```text
<org-name>/
  ├── org/
  │   ├── apiProducts.json
  │   ├── developers.json
  │   └── ...
  └── env/
      ├── <env-name>/
      │   ├── targetServers.json
      │   ├── kvms.json
      │   └── ...
```

*Note: File names must start with the resource type (e.g., `targetServers-backend.json` is valid).*

---

## Advanced Usage

### Comparing Specific Branches or Commits
The tool natively supports Git references, including branch names, tags, and specific hashes:

```bash
python main.py --commit-before main --current-commit feature-branch
```

### GitHub Actions / CI Pipelines
Use the environment variables provided by your CI runner (like `GITHUB_BASE_REF` and `GITHUB_HEAD_REF`) to target PR commits:

```bash
python main.py \
  --commit-before origin/main \
  --current-commit ${{ github.event.pull_request.head.sha }} \
  --confirm \
  --bearer ${{ secrets.APIGEE_BEARER }}
```

---

## Contributing
Tests are located in the `diff/` directory. Run them with:
```bash
pytest --cov=diff
```
