import os
import sys
import subprocess

def process_files(output_base_path, resources_folder, confirm):
    actions = ["update", "delete"]
    
    # Strip trailing slash from resources_folder to ensure correct path joining
    resources_subpath = resources_folder.strip(os.sep)
    
    for action in actions:
        # Construct the base path for this action and resource folder
        # e.g. output/update/src
        action_base_path = os.path.join(output_base_path, action, resources_subpath)
        
        if not os.path.exists(action_base_path):
            # It's possible the folder doesn't exist if no files matched the criteria
            # Check if at least the action folder exists to avoid confusion
            if os.path.exists(os.path.join(output_base_path, action)):
                 print(f"No files found in {action_base_path} (subfolder empty).")
            continue

        print(f"\nProcessing files in folder {action_base_path} for action {action}")

        # Find all files recursively
        affected_files = []
        for root, dirs, files in os.walk(action_base_path):
            for file in files:
                affected_files.append(os.path.join(root, file))
        
        if not affected_files:
            print(f"No files to process for {action}.")
            continue

        org_env_map = {} # org -> set(envs)

        for full_path in affected_files:
            # Get path relative to the base (e.g. org/env/dev/file.json)
            rel_path = os.path.relpath(full_path, action_base_path)
            parts = rel_path.split(os.sep)

            if not parts:
                continue

            org_name = parts[0]
            
            # Basic validation
            if not org_name or org_name == rel_path:
                # Should not happen given we are walking the dir, but safe to check
                continue

            if org_name not in org_env_map:
                org_env_map[org_name] = set()

            # Check if the path is within an 'env' directory
            # Structure: <org-name>/env/<env-name>/...
            if len(parts) > 2 and parts[1] == "env":
                env_name = parts[2]
                org_env_map[org_name].add(env_name)

        # Show what was found
        print("--- Affected Orgs and Environments ---")
        if not org_env_map:
             print("No orgs/environments found.")
        else:
             for org, envs in org_env_map.items():
                 envs_list = list(envs)
                 print(f"Org: {org}, Envs: {envs_list if envs_list else '(None)'}")

        if confirm:
            print(f"--- Processing affected Orgs and Environments ({action}) ---")
            for org, envs in org_env_map.items():
                
                config_dir = os.path.join(action_base_path, org)
                
                if envs:
                    for e in envs:
                        print(f"Running env {e} for org {org}...")
                        cmd = [
                            "mvn", "install", "-Pdefault",
                            f"-Dapigee.config.dir={config_dir}",
                            f"-Dapigee.org={org}",
                            f"-Dapigee.env={e}",
                            f"-Dapigee.config.options={action}"
                        ]
                        try:
                            subprocess.run(cmd, check=True)
                        except subprocess.CalledProcessError as e:
                            print(f"Error running maven command: {e}", file=sys.stderr)
                            # decide whether to exit or continue. Bash script would fail? 
                            # Usually best to stop on error in CI/CD.
                            sys.exit(1)
                else:
                    print(f"Running for org {org} (no specific env detected)...")
                    cmd = [
                        "mvn", "install", "-Pdefault",
                        f"-Dapigee.config.dir={config_dir}",
                        f"-Dapigee.org={org}",
                        f"-Dapigee.config.options={action}"
                    ]
                    try:
                        subprocess.run(cmd, check=True)
                    except subprocess.CalledProcessError as e:
                        print(f"Error running maven command: {e}", file=sys.stderr)
                        sys.exit(1)

        else:
            print(f"\n[Dry Run] The following structure would be processed for action ({action}):")
            # Mimic 'tree' command if available
            try:
                subprocess.run(["tree", action_base_path], check=False)
            except FileNotFoundError:
                # Fallback if tree is not installed
                for f in affected_files:
                    print(f"  {f}")
            
    if not confirm:
        print("\nTo execute, call again with --confirm")
