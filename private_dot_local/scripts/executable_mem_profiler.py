import psutil
import datetime
import json

def get_top_memory_processes(limit=5):
    processes = []
    for proc in psutil.process_iter(['pid', 'ppid', 'name', 'create_time', 'memory_info', 'cmdline']):
        try:
            processes.append(proc.info)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    # sort by RSS (resident set size, i.e. actual RAM)
    processes.sort(key=lambda p: p['memory_info'].rss if p['memory_info'] else 0, reverse=True)

    return processes[:limit]

def make_report(processes):
    report = []
    for p in processes:
        report.append({
            "pid": p['pid'],
            "ppid": p['ppid'],
            "name": p['name'],
            "start_time": datetime.datetime.fromtimestamp(p['create_time']).isoformat() if p['create_time'] else None,
            "ram_mb": round(p['memory_info'].rss / (1024 * 1024), 2) if p['memory_info'] else 0,
            "cmdline": " ".join(p['cmdline']) if p['cmdline'] else ""
        })
    return report

if __name__ == "__main__":
    top_processes = get_top_memory_processes(limit=5)  # change 5 to however many you want
    report = make_report(top_processes)
    print(json.dumps(report, indent=2))
