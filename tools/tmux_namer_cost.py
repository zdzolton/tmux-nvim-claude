import re
import fileinput
import statistics
from datetime import datetime
from collections import defaultdict

def parse_and_analyze():
    daily_costs = defaultdict(float)
    weekly_costs = defaultdict(float)
    task_costs = defaultdict(float)
    
    # Regex updated to capture 'cost' and 'name'
    pattern = re.compile(r'(\d{4}-\d{2}-\d{2})T.*?cost=\$([\d\.]+).*?name="([^"]+)"')

    for line in fileinput.input():
        match = pattern.search(line)
        if match:
            date_str, cost_val, name = match.groups()
            cost = float(cost_val)
            
            # Grouping
            daily_costs[date_str] += cost
            task_costs[name] += cost
            
            # Weekly Grouping
            date_obj = datetime.strptime(date_str, '%Y-%m-%d')
            year, week, _ = date_obj.isocalendar()
            weekly_costs[f"{year}-W{week:02d}"] += cost

    if not daily_costs:
        print("No log data found matching the expected format.")
        return

    # --- 1. DAILY & WEEKLY TOTALS ---
    print(f"\n{'PERIOD':<15} | {'TOTAL COST':<12}")
    print("-" * 30)
    for date in sorted(daily_costs.keys()):
        print(f"{date:<15} | ${daily_costs[date]:.4f}")
    
    print("-" * 30)
    for week in sorted(weekly_costs.keys()):
        print(f"{week:<15} | ${weekly_costs[week]:.4f}")

    # --- 2. STANDARD DAILY STATISTICS ---
    daily_vals = list(daily_costs.values())
    print(f"\n--- DAILY STATS ({len(daily_vals)} days) ---")
    print(f"Average: ${statistics.mean(daily_vals):.4f}")
    print(f"Median:  ${statistics.median(daily_vals):.4f}")
    print(f"Maximum: ${max(daily_vals):.4f}")
    print(f"Minimum: ${min(daily_vals):.4f}")

    # --- 3. TOP 5 MOST EXPENSIVE TASKS ---
    print("\n--- TOP 5 TASKS BY COST ---")
    top_tasks = sorted(task_costs.items(), key=lambda x: x[1], reverse=True)[:5]
    for i, (name, total) in enumerate(top_tasks, 1):
        print(f"{i}. {name:<20} | ${total:.4f}")

if __name__ == "__main__":
    parse_and_analyze()
