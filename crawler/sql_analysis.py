import logging
import re
import json
import os
import time
from urllib.parse import parse_qs, urlparse

from config import config
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo  # Python 3.9+

logger = config.logger

def get_log():
    WUT_NAME = os.environ.get('WUT_NAME', None)
    if WUT_NAME==None:
        WUT_NAME = config.data['PROJECT_NAME']

    testloc = "/projects/fuzzing/SQLIFuzz/shared-data"
    log_file = os.path.join(testloc,f"mysql_proxy_{WUT_NAME}.log")

    # Regex pattern
    log_pattern = re.compile(
        r"^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)\s"
        r"\[(?P<level>[A-Z]+)\]\s"
        r"\[\('(?P<ip>[\d\.]+)',\s(?P<port>\d+)\)\]\s###\s(?P<sql>.+)$"
    )

    parsed_logs = []

    # Read and parse the file
    with open(log_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            match = log_pattern.match(line)
            if match:
                parsed_logs.append({
                    "timestamp": match.group("timestamp"),
                    "level": match.group("level"),
                    "ip": match.group("ip"),
                    "port": int(match.group("port")),
                    "sql": match.group("sql")
                })

    return parsed_logs

def check_important_param_pairs(param_pairs):
    new_pairs = {}
    if param_pairs:
        for k, value in param_pairs.items():
            ### skip_useless_field
            key = k.lower() if k else ""
            if key=='content-type' or key=='accept' or key =='sec-ch-ua' or key=='sec-ch-ua-mobile' or key =='connection' or key =='user-agent' or key =='content-length':
                continue

            new_pairs[key] = value

    return new_pairs

def find_queries_in_time_window(start_time, end_time, param_pairs=None, id="", only_find_error=True):
    """
    Filter queries between start_time and end_time.

    Args:
        logs (list): Parsed log entries.
        start_time (str): Start time, format 'YYYY-MM-DD HH:MM:SS,mmm'
        end_time (str): End time, format 'YYYY-MM-DD HH:MM:SS,mmm'

    Returns:
        list: Matching log entries.
    """
    time.sleep(1)
    logs = get_log()
    logger.info(f"[SQLAnalysis {id}] Extracted Logs {datetime.utcnow()}: %s", logs[-1:])
    start_dt = datetime.strptime(start_time, "%Y-%m-%d %H:%M:%S,%f")
    end_dt = datetime.strptime(end_time, "%Y-%m-%d %H:%M:%S,%f")

    sorted_logs = list()
    error_logs = list()
    new_pairs = check_important_param_pairs(param_pairs)
    logger.info(f"[SQLAnalysis {id}] Updated param pairs: %s", new_pairs)
    logger.info(f"[SQLAnalysis {id}] Looked timestamp {start_dt} -- {end_dt}")

    found_value = None
    for log in logs:
        if start_dt <= datetime.strptime(log["timestamp"], "%Y-%m-%d %H:%M:%S,%f") <= end_dt:
            # Remove all " and `
            query = re.sub(r"[\"`]", "", log["sql"]).lower()
            query_array = re.split(r'[,\s;]+', query)

            logger.info(f"[SQLAnalysis {id}] query_array to be checked: {query_array} with {new_pairs}")

            if only_find_error:
                if "**error" in query:
                    error_logs.append(log["sql"])

            for key, val in new_pairs.items():
                if val==None or val=="":
                    continue

                if len(query_array)>0:
                    if any(str(val).lower() in item for item in query_array):
                        sorted_logs.append(log["sql"])
                        logger.info(f"[SQLAnalysis {id}] Getting {key}==>{val} in %s", log)
                        found_value = val
                        break

    return sorted_logs, error_logs, found_value

def remove_limit_clause(sql_query: str) -> str:
    """
    Removes the LIMIT clause (including optional offset) from a SQL query string.
    Example: "LIMIT 0,1" or "LIMIT 10"
    """
    # Regex matches "LIMIT" followed by numbers (and optional comma)
    cleaned_query = re.sub(r'\s+LIMIT\s+\d+(?:\s*,\s*\d+)?', '', sql_query, flags=re.IGNORECASE)
    return cleaned_query.strip()

def get_param_val_request_entry(entry):
    pairs = {}
    pairs.update(entry['request']['headers'])

    parsed_url = urlparse(entry['request']['url'])
    try:
        pairs.update({k: v[0] for k, v in parse_qs(parsed_url.query).items()})
    except Exception as e:
        logger.info(f"[SQLAnalysis] Error in get_param_val_request_entry: {e}")

    # Split the path by "/" and filter out empty strings
    path_parts = [part for part in parsed_url.path.split("/") if part]
    entry['path_parts'] = path_parts
    for i, p in enumerate(path_parts):
        pairs.update({f"path{i}": p})

    # Body parameters (only parse if it's form-encoded or JSON)
    body_text = entry['request'].get('body_preview_text')
    ctype = entry['request'].get('content_type', None)
    if ctype:
        ctype = ctype.lower()

    if body_text:
        if 'application/x-www-form-urlencoded' in ctype:
            pairs.update({k: v for k, v in parse_qs(body_text).items()})
        elif 'application/json' in ctype:
            try:
                pairs.update(json.loads(body_text))
            except Exception:
                body_params = {"_raw": body_text}

    return pairs