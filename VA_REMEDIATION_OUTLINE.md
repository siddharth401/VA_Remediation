# VA Remediation Automation for Linux Servers - Architecture & Outline

## Overview
This document outlines the architecture and structured approach for automating Vulnerability Assessment (VA) remediation on Linux servers hosted in Azure and OCI. The solution leverages Azure DevOps (ADO) Pipelines orchestrating Ansible Playbooks to perform patching (Qualys scan fixes/latest yum updates), service management, state backups, and validation.

## Architecture Decisions

1. **Pipeline & Agent Routing:**
   - A single Azure DevOps Pipeline handles the end-to-end process.
   - Using ADO conditional jobs, execution will be dynamically routed to different Agent Pools:
     - OCI servers will be targeted using an OCI-specific agent pool.
     - Azure servers will be targeted using an Azure-specific agent pool.
   - Ansible dynamic inventories will handle real-time server discovery.

2. **The 1-Hour Pre-Patching Delay (Production):**
   - **Problem:** Stopping the crontab 1 hour before patching in Production.
   - **Solution:** The pipeline uses an **Agentless Job** with a "Delay" task.
   - **Flow:** Stage 1 stops the crontab -> Pipeline pauses for 1 hour (no compute cost) -> Stage 2 requests Manual Approval -> Stage 3 executes remediation.

3. **Service Management via Auto-Discovery (GAIA Custom Framework):**
   - Applications running under the `egold` user (specifically the GAIA framework) are highly dynamic and managed via profile aliases in `/opt/GOLD/`. We will **not** use hardcoded YAML configurations.
   - Instead, Ansible will deploy and execute a custom auto-discovery script (`scripts/manage_custom_services.sh`).
   - **Stop Phase:** The script locates all `show_gaia` instances, changes into their directories, and executes `./show_gaia` as `egold`. It parses the output to identify active nodes (e.g., `CEN510PRD`), executes `./stop_gaia <NODE>`, and saves the directory-node mapping to a state file.
   - **Start Phase:** Post-reboot, Ansible triggers the script again, which reads the saved state file, navigates back to the specific directories, and automatically executes `./start_gaia <NODE>`.

4. **Boot Volume Snapshots:**
   - We will use **Ansible Native Modules** (`azure_rm_manageddisk_snapshot` / `oci_volume_backup`) rather than Terraform. This avoids state-file management overhead for a stateless operational task.

5. **Missed Cron Job Handling:**
   - A custom Python script will be executed. It will parse the original crontab format, take the downtime window (start to end times), and calculate which specific jobs were scheduled but missed. Those commands will then be extracted and executed.

6. **Logging & Reporting:**
   - **High-level:** Azure DevOps Pipeline native logs.
   - **Granular:** ARA (Ansible Run Analysis) running on the Ansible control nodes.
   - **Reporting:** An HTML/Markdown summary report will be generated and passed to the existing Ansible email role for completion notification.

---

## High-Level Process Flow (The 13 Steps Mapped)

| Step | Environment | Action | Tool / Implementation |
|---|---|---|---|
| 0. | Non-Prod | **Initiation Email** | Ansible playbook (Email Role). |
| 1. | Prod | **Stop Crontab** (1 hr before) | Ansible playbook backs up and removes cron. |
| - | Prod | **Wait 1 Hour** | ADO Pipeline Agentless Delay Task. |
| - | All | **Approval Gate** | ADO Manual Validation Gate (displays server names). |
| 2. | All | **Handle Batch Jobs** | Ansible executes shell script: loop to check running jobs. (Prod: Wait; Non-prod: Kill). |
| 3. | Prod | **Initiation Email** | Ansible playbook (Email Role). |
| 4. | All | **Backup Service State** | Script auto-discovers running instances and writes state to `/tmp/va_remediation_stopped_services.txt`. |
| 5. | All | **Stop Services** | Auto-discovery script parses `./show_gaia` and executes `./stop_gaia <NODE>`. |
| 6. | All | **Clone/Snapshot Boot Volume** | Ansible Cloud Modules (Azure / OCI) using dynamic config. |
| 7. | All | **YUM Update** | Ansible `yum` module (run as root). |
| 8. | All | **Reboot** | Ansible `reboot` module with pre/post wait conditions. |
| 9. | All | **Start Services** | Auto-discovery script reads state file and executes `./start_gaia <NODE>`. |
| 10. | All | **Remove Old Kernels** | Ansible executes `package-cleanup --oldkernels --count=1` or equivalent. |
| 11. | All | **App Validation** | Ansible `uri` module testing URLs defined in YAML. |
| 12. | All | **Restore Cron & Missed Jobs** | Ansible restores cron. Python script identifies missed jobs & executes them. |
| 13. | All | **Completion Email** | Ansible playbook (Email Role) sending validation status. |

---

## Repository Directory Structure

```text
.
├── .azure-pipelines/
│   └── pipeline-va-remediation.yml    # Main ADO Pipeline definition
├── ansible/
│   ├── ansible.cfg                    # Ansible configuration (ARA integration)
│   ├── inventories/
│   │   ├── azure_rm.yml               # Azure Dynamic Inventory
│   │   └── oci.yml                    # OCI Dynamic Inventory
│   ├── group_vars/
│   │   └── all.yml                    # Global variables
│   ├── customer_configs/
│   │   ├── custA_prod.yml             # Specific config for URLs, custom services
│   │   └── custB_nonprod.yml
│   ├── playbooks/
│   │   ├── 00_init_email.yml
│   │   ├── 01_pre_patch_prod.yml      # Stops cron 1 hr prior
│   │   ├── 02_remediation_main.yml    # Core patching loop (Steps 2 - 12)
│   │   └── 03_completion_email.yml
│   └── roles/
│       ├── batch_jobs/                # Waits/kills jobs
│       ├── custom_services/           # Stops/Starts egold custom apps
│       ├── cloud_snapshots/           # Azure/OCI snapshot logic
│       ├── os_patching/               # Yum update, reboot, old kernel cleanup
│       ├── app_validation/            # URL checks
│       └── cron_manager/              # Backup/restore cron + execute missed jobs
└── scripts/
    └── process_missed_cron.py         # Python logic to calculate missed crons
```
