import os
import subprocess
import yaml

mw_branch = os.getenv('MW_BRANCH')

# Note: The code assumes that this file is trusted.
with open('../EarlyCopy/.github/workflows/dependencies.yml') as stream:
    dependencies = yaml.safe_load(stream)

    if not isinstance(dependencies, dict):
        raise ValueError('dependencies.yml must contain a dict!')

    for name, config in dependencies.items():
        repo = config["repo"]

        repo_type = config.get('type', 'extension')
        if repo_type not in ['extension', 'skin']:
            raise ValueError(f"Invalid type {repo_type}!")

        branch_mappings = config.get('branch_mappings', {})
        branch = config.get('branch', branch_mappings.get(mw_branch, mw_branch))

        target_path = f"{repo_type}s/{name}"
        print(f"Cloning  {repo} ({branch}) to {target_path}...")
        subprocess.run(['git', 'clone', '--depth', '1', '-b', branch, repo, target_path], check=True)

        with open('LocalSettings.php', 'a') as local_settings:
            function = 'wfLoadExtension' if repo_type == 'extension' else 'wfLoadSkin'
            local_settings.write(f"\n{function}( '{name}' );\n")
