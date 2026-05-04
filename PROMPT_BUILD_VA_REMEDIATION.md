# Comprehensive Prompt for Building the VA Remediation Tool

*Copy the text below and provide it to an AI assistant or development team to initiate the full build of the VA Remediation automation.*

***

**System Role:** You are an expert Cloud Automation and DevOps Engineer specializing in Azure DevOps (ADO), Ansible, Python, and Bash scripting.

**Task:** I need you to build a complete Vulnerability Assessment (VA) Remediation automation tool for Linux servers hosted in Azure and OCI. This tool will orchestrate patching (Qualys scan fixes/latest yum updates), service state management, cloud snapshots, and validation.

### Architecture & Framework constraints:
1. **Orchestrator:** A single, parameterized Azure DevOps Pipeline (`.azure-pipelines/pipeline-va-remediation.yml`).
2. **Parameters:** The pipeline must accept `customer`, `environment` (`prod` or `nonprod`), `cloud_provider` (`azure` or `oci`), and `exclude_servers` (a comma-separated list of hostnames to ignore).
3. **Execution Engine:** Ansible Playbooks running on dynamically routed ADO Agent Pools (Azure pool vs OCI pool).
4. **Targeting:** Target servers must be derived entirely from an Ansible Dynamic Inventory using tags (`tag_customer_<customer>` and `tag_env_<environment>`), heavily utilizing the `--limit` flag to safely handle the exclusions. Do NOT ask the user for target IPs.
5. **Customer Configuration:** Read environment-specific configurations (like validation URLs) from a structured directory hierarchy: `ansible/customer_configs/<customer>/<environment>.yml`.

### The 13-Step Remediation Process to Implement:

Please build the Ansible playbooks, roles, and necessary utility scripts to execute the following steps in order:

1. **Pre-Patching (PROD Only):** 1 hour before the main activity, backup the crontab to `/tmp/` and completely remove it (`crontab -r`).
   *(Note: The ADO pipeline must handle the 1-hour wait using an Agentless Delay Task so compute is not wasted).*
2. **Manual Approval Gate:** The ADO pipeline must explicitly extract the target server names from the dynamic inventory and display them in a manual approval prompt before proceeding.
3. **Handle Batch Jobs (All envs):** Execute a loop to check for running batch jobs. If in Production, wait for them to finish. If in Non-Prod, aggressively kill them.
4. **Initiation Email:** Use an existing Ansible email role to send a notification that patching is starting.
5. **Stop Services (Custom GAIA Framework):** Deploy a bash script (`scripts/manage_custom_services.sh`) that auto-discovers running custom applications.
   - These are not systemd services. They belong to the `egold` user in the `/opt/GOLD` directory.
   - The script must find `show_gaia` scripts, run `./show_gaia`, parse the output (e.g., `GAIA is running on following node(s) :\nCEN510PRD`), execute `./stop_gaia <NODE>`, and save a state file with the directory and stopped node names.
6. **Clone/Snapshot Boot Volume:** Use native Ansible modules (`azure_rm_manageddisk_snapshot` / `oci_volume_backup`) to take a snapshot of the boot volume.
7. **OS Patching:** Execute a `yum update` as root.
8. **Reboot:** Reboot the machine and wait for it to come back online.
9. **Start Services:** Execute the auto-discovery script from Step 5 again, but in "start" mode. It must read the state file, navigate to the specific directories, and run `./start_gaia <NODE>`.
10. **Remove Old Kernels:** Run a package cleanup to remove all but the currently running kernel (e.g., `package-cleanup --oldkernels --count=1`).
11. **App Validation:** Read a list of `validation_urls` from the customer's YAML config and use the Ansible `uri` module to assert they return a 200 OK status.
12. **Restore Cron & Missed Jobs:** Restore the backed-up crontab. Execute a custom Python script (using the `croniter` library) that compares the start and end times of the remediation window against the crontab backup, calculates which specific jobs were missed, and executes them immediately.
13. **Completion Email:** Send a final status email using the Ansible email role.

### Deliverables expected from you:
- Complete Azure DevOps YAML pipeline definition.
- The Ansible Playbook orchestrating the roles.
- The `scripts/manage_custom_services.sh` bash script for GAIA auto-discovery.
- The `scripts/process_missed_cron.py` python script.
- The required Ansible Roles (`batch_jobs`, `cloud_snapshots`, `os_patching`, `app_validation`, `cron_manager`).
- A sample `customer_configs/custA/prod.yml` file.