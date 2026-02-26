import logging
import re
import json
import os
import copy
import time
from urllib.parse import parse_qs, urlparse

from config import config
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo  # Python 3.9+

logger = config.logger

def new_get_log():
    """
    Reads and parses new lines from the log file, appending to a static parsed_logs list.
    Returns the up-to-date parsed_logs.
    """

    # Input file name
    WUT_NAME = os.environ.get('WUT_NAME', None)
    HOST_NAME = os.environ.get('HOST_NAME', "")
    if WUT_NAME==None:
        WUT_NAME = config.data['PROJECT_NAME']

    testloc = "/projects/fuzzing/SQLIFuzz/shared-data"
    log_file = os.path.join(testloc,f"mysql_proxy_{WUT_NAME}{HOST_NAME}.log")

    if not hasattr(new_get_log, "parsed_logs"):
        new_get_log.parsed_logs = []
        new_get_log.last_offset = 0

    parsed_logs = new_get_log.parsed_logs
    last_offset = getattr(new_get_log, "last_offset", 0)

    try:
        with open(log_file, "r") as f:
            f.seek(last_offset)
            new_lines = f.readlines()
            new_offset = f.tell()

        if new_lines:
            logger.info(f"[SQLAnalysis] Read {len(new_lines)} new lines from SQL log file.")
            # Parse lines once and keep only successfully parsed entries (skip None)
            # new_parsed = [p for p in (parse_log_line(line) for line in new_lines) if p is not None]

            new_parsed = []
            for line in new_lines:
                p = parse_log_line(line)
                if p:
                    new_parsed.append(p)

            if len(new_parsed)>0:
                parsed_logs.extend(new_parsed)
                logger.info(f"[SQLAnalysis] Appended {len(new_parsed)} parsed entries.")
            else:
                logger.info(f"[SQLAnalysis] No parsable new log entries found.")
            new_get_log.last_offset = new_offset
        else:
            logger.info(f"[SQLAnalysis] No new lines in SQL log file.")

    except FileNotFoundError as e:
        logger.error(f"[SQLAnalysis] Error reading log file %s: %s", log_file, e)

    return parsed_logs

# Helper function for parsing a log line
def parse_log_line(line):
    # Regex pattern
    log_pattern = re.compile(
        r"^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)\s"
        r"\[(?P<level>[A-Z]+)\]\s"
        r"\[\('(?P<ip>[\d\.]+)',\s(?P<port>\d+)\)\]\s###\s(?P<sql>.+)$"
    )

    line = line.strip()
    if not line:
        return None

    match = log_pattern.match(line)
    if match:
        return {
            "timestamp": match.group("timestamp"),
            "level": match.group("level"),
            "ip": match.group("ip"),
            "port": int(match.group("port")),
            "sql": match.group("sql")
        }

    return None

# Keep track of last-read file positions so subsequent calls only read new data
_log_file_offsets = {}
def get_log():
    # Input file name
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

    # If the log file doesn't exist yet, return empty list
    if not os.path.exists(log_file):
        return parsed_logs

    # Open file and only read from the last position we saw for this file
    try:
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

            # Save current file position for next call
            _log_file_offsets[log_file] = f.tell()

    except Exception as e:
        logger.error(f"[SQLAnalysis] Error reading log file %s: %s", log_file, e)

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

def normalize(value):
    return ''.join(c for c in str(value).lower() if c.isalnum())

def normalize_array_strings(query_array):
    return [normalize(item) for item in query_array]
    

def is_query(query_str):
    sql_keywords = [
        "select", "insert", "update", "delete", "create", "drop", "alter",
        "truncate", "replace", "grant", "revoke", "commit", "rollback", "set" ]
    query_lower = query_str.lower()
    return any(keyword in query_lower for keyword in sql_keywords)

def find_queries_in_time_window(start_time, end_time, param_pairs=None, id="", only_find_error=False, request=None, check_malformed=False):
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
    logs = new_get_log()
    logger.info(f"[SQLAnalysis {id}] Extracted {len(logs)} Logs {datetime.utcnow()}: %s", logs[-1:])
    start_dt = datetime.strptime(start_time, "%Y-%m-%d %H:%M:%S,%f")
    end_dt = datetime.strptime(end_time, "%Y-%m-%d %H:%M:%S,%f")


    sorted_logs = list()
    error_logs = list()
    new_pairs = param_pairs
    if request:
        logger.info(f"[SQLAnalysis {id}] Checking Request: {request}")
    logger.info(f"[SQLAnalysis {id}] Updated param pairs: %s", new_pairs)
    logger.info(f"[SQLAnalysis {id}] Looked timestamp {start_dt} -- {end_dt}")

    error_logs_non_combined = list()
    matched_logs_non_combined = list()

    found_value = None
    idx = -1
    for log in logs:
        idx += 1
        if start_dt <= datetime.strptime(log["timestamp"], "%Y-%m-%d %H:%M:%S,%f") <= end_dt:
            # Remove all " and `
            query_with_response = re.sub(r"[\"`]", "", log["sql"]).lower()

            ## Remove everything after *#*#, which is the response info, to get the original query
            query = query_with_response.split("*#*#", 1)[0].strip()
            query_array = re.split(r'[,\s;]+', query)
            normalized_query_array = normalize_array_strings(query_array)

            logger.info(f"[SQLAnalysis {id}] query_array to be checked: {query_array}")
            logger.info(f"[SQLAnalysis {id}] normalized_query_array: {normalized_query_array}")

            if only_find_error:
                if "*#*#error" in query_with_response:
                    error_logs.append(log["sql"])

                    ## We catch the error response that not brings the malformed query to be combined
                    if not is_query(query):
                        logger.info(f"[SQLAnalysis {id}] Getting error log without query explanation: {query_with_response}")
                        error_logs_non_combined.append((idx, log))

            for key, val in new_pairs.items():
                if val==None or val=="":
                    continue

                if check_malformed:
                    if val.lower() in query.lower():
                        sorted_logs.append(query_with_response)
                        matched_logs_non_combined.append((idx, log))
                        logger.info(f"[SQLAnalysis {id}] Getting malformed {key}==>{val} in {query_with_response}")
                        found_value = val

                        if request:
                            request.SQL_detected.append(query_with_response)
                            if val not in request.found_values:
                                request.found_values.append(val)
                        else:
                            break

                elif len(query_array)>0:

                    nval = normalize(val)


                    if nval and nval in normalized_query_array:
                        sorted_logs.append(query_with_response)
                        matched_logs_non_combined.append((idx, log))
                        logger.info(f"[SQLAnalysis {id}] Getting {key}==>{val} [{nval}] in {normalized_query_array}")
                        found_value = val

                        if request:
                            request.SQL_detected.append(query_with_response)
                            if val not in request.found_values:
                                request.found_values.append(val)
                        else:
                            break


    combination_logs = combining_matching_and_error_queries(matched_logs_non_combined, error_logs_non_combined, id)

    return sorted_logs, error_logs, found_value, combination_logs

def is_sql_syntax_error(SQL_response):
    # Check if the SQL response contains both syntax and error words
    error_indicators = ["syntax", "error"]
    another_indicators = ["near", "error"]
    if all(indicator in SQL_response.lower() for indicator in error_indicators):
        return True
    if all(indicator in SQL_response.lower() for indicator in another_indicators):
        return True
    return False

def combining_matching_and_error_queries(matching_queries, error_queries, id):
    MAX_INDEX_GAP = 5
    index = -1
    if len(error_queries)>0 and len(matching_queries)>0:
        combined_queries = list()
        try:
            logger.info(f"[SQLAnalysis {id}] Combining matching and error queries") 

            port = None
            for idx, eq in error_queries:
                if is_sql_syntax_error(eq['sql']):
                    port = eq['port']
                    combined_queries.append(eq)
                    index = idx
                    logger.info(f"[SQLAnalysis {id}] Including {eq['sql']} to combined queries for port {port}.")
                    break

            if port:
                for idx, eq in matching_queries:
                    if eq['port']==port and abs(idx - index) <= MAX_INDEX_GAP:
                        logger.info(f"[SQLAnalysis {id}] Including {eq['sql']} to combined queries for port {port}.") 
                        combined_queries.append(eq)

            if len(combined_queries)>1:
                return combined_queries
            else:
                return None
        except Exception as e:
            logger.error(f"[SQLAnalysis {id}] Error combining queries: {e}")
            return None
    return None

def remove_limit_clause(sql_query: str) -> str:
    """
    Removes the LIMIT clause (including optional offset) from a SQL query string.
    Example: "LIMIT 0,1" or "LIMIT 10"
    """
    # Regex matches "LIMIT" followed by numbers (and optional comma)
    cleaned_query = re.sub(r'\s+LIMIT\s+\d+(?:\s*,\s*\d+)?', '', sql_query, flags=re.IGNORECASE)
    return cleaned_query.strip()

def get_request_start_end_times_from_timing(timing):
    """
    Convert timing dict with absolute startTime in millis + offsets
    to formatted start and end timestamps localized to Amsterdam timezone.
    
    Args:
        timing (dict): timing info with keys including:
            - startTime: absolute start time in milliseconds since epoch (UTC)
            - responseEnd: offset in milliseconds from startTime
            
    Returns:
        tuple: (start_time_str, end_time_str) in "%Y-%m-%d %H:%M:%S,%f" format,
               localized to Europe/Amsterdam timezone
    """
    # amsterdam_tz = ZoneInfo("Europe/Amsterdam")

    # Convert startTime millis to UTC datetime
    start_time_utc = datetime.fromtimestamp(timing["startTime"] / 1000.0, tz=ZoneInfo("UTC"))
    
    # Convert to Amsterdam timezone
    # start_time_local = start_time_utc.astimezone(amsterdam_tz)
    start_time_local = start_time_utc
    
    # Calculate end time by adding responseEnd offset (if present), else use startTime
    response_end_offset_ms = timing.get("responseEnd", 0)

    if response_end_offset_ms > 0:
        # end_time_local = start_time_local + timedelta(milliseconds=response_end_offset_ms)
        end_time_local = start_time_local + timedelta(milliseconds=response_end_offset_ms) + timedelta(milliseconds=config.SAFE_GAP)
    else:
        end_time_local = start_time_local
    
    # Format timestamps, trimming microseconds to milliseconds
    start_time_str = start_time_local.strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]
    end_time_str = end_time_local.strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]

    logger.info("[SQLAnalysis] Start Time: %s", start_time_str)
    logger.info("[SQLAnalysis] End Time: %s", end_time_str)
    
    return start_time_str, end_time_str

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
        ## Only extract the last part of the path as param value
        if i==len(path_parts)-1:
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