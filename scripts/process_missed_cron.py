import sys
import datetime
from croniter import croniter

def get_missed_crons(crontab_file, start_iso, end_iso):
    """
    Parses a crontab file and identifies jobs that were scheduled
    to run between start_iso and end_iso but were missed.
    """
    try:
        start_time = datetime.datetime.fromisoformat(start_iso.replace('Z', '+00:00'))
        end_time = datetime.datetime.fromisoformat(end_iso.replace('Z', '+00:00'))
    except ValueError as e:
        print(f"Error parsing dates: {e}", file=sys.stderr)
        sys.exit(1)

    missed_jobs = []

    try:
        with open(crontab_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue  # Skip comments, empty lines

                # check if it is an env variable assignment like MAILTO=admin
                if '=' in line.split(maxsplit=1)[0]:
                    continue

                parts = line.split(maxsplit=5)
                if len(parts) < 6:
                    continue # Not a valid cron line

                cron_expr = " ".join(parts[:5])
                command = parts[5]

                try:
                    # Initialize croniter at the start_time
                    iterator = croniter(cron_expr, start_time)
                    next_run = iterator.get_next(datetime.datetime)

                    # If the next scheduled run falls before our end_time, it was missed!
                    if next_run <= end_time:
                        missed_jobs.append(command)
                except ValueError as e:
                    print(f"Warning: Could not parse cron expression '{cron_expr}' - {e}", file=sys.stderr)
                    continue
    except FileNotFoundError:
        print(f"Error: Crontab file '{crontab_file}' not found.", file=sys.stderr)
        sys.exit(1)

    # Output the missed commands
    for job in set(missed_jobs): # Use set to avoid running a script 100 times if it runs every minute
        print(job)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 process_missed_cron.py <crontab_backup_file> <start_time_iso> <end_time_iso>")
        sys.exit(1)

    crontab_path = sys.argv[1]
    start_t = sys.argv[2]
    end_t = sys.argv[3]

    get_missed_crons(crontab_path, start_t, end_t)
