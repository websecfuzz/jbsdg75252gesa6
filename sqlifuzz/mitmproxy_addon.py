import json
import asyncio
import logging
import os
import re
import socket
import uuid

import psutil
from mitmproxy import http, ctx
from datetime import datetime

from HTTPRequest import convert_request_from_entry
from SQLIFuzz import fuzz
from SQLIRequestCollection import sqli_request_collection
from config import config
from general_functions import is_sql_syntax_error
from sql_analysis import find_queries_in_time_window, get_param_val_request_entry

WUT_PORT = os.environ.get('WUT_PORT', "8081")
PROXY_PORT = 8888

config.load_config(file_path="configs/config-general.yaml")

logger = config.logger

# Limit concurrent fuzzing tasks to prevent resource exhaustion
MAX_CONCURRENT = int(os.environ.get('MAX_CONCURRENT_FUZZ', "10"))
fuzz_semaphore = asyncio.Semaphore(MAX_CONCURRENT)  # Max concurrent fuzzing operations
pending_fuzz_count = 0
active_tasks = set()  # Track all active async tasks

# Idle timeout settings for auto-shutdown
import time
import shared_state
IDLE_TIMEOUT = int(os.environ.get('IDLE_TIMEOUT', "120"))  # seconds of inactivity before shutdown
shutdown_monitor_started = False

async def idle_shutdown_monitor():
    """Monitor for idle timeout and pending tasks completion, then shutdown."""
    
    # Wait for initial requests to come in
    initial_wait = 60
    logger.info(f"[HOOK] Idle shutdown monitor started. Will check after {initial_wait}s initial wait...")
    await asyncio.sleep(initial_wait)
    
    while True:
        idle_time = time.time() - shared_state.last_activity_time
        
        # Check if we're idle AND all tasks are complete
        if idle_time > IDLE_TIMEOUT and pending_fuzz_count == 0 and len(active_tasks) == 0:
            logger.info(f"[HOOK] Idle timeout ({IDLE_TIMEOUT}s) reached with no pending tasks. Initiating shutdown...")
            print(f"[HOOK] Idle timeout reached. Saving results and shutting down...")
            
            # Save results before shutdown
            config.finish_time = datetime.now()
            config.stats['running_time'] = str(config.finish_time - config.start_time)
            sqli_request_collection.print()
            sqli_request_collection.save_result(is_finish=True)
            
            # Trigger mitmproxy shutdown
            ctx.master.shutdown()
            break
        else:
            if pending_fuzz_count > 0 or len(active_tasks) > 0:
                logger.info(f"[HOOK] Idle monitor: {pending_fuzz_count} pending tasks, {len(active_tasks)} active tasks, idle {idle_time:.0f}s")
                log_memory_usage()
            await asyncio.sleep(20)  # Check every 20 seconds
    
    logger.info(f"[HOOK] FINISH on {config.finish_time}. Total run time: {config.finish_time - config.start_time}")
    print(f"[HOOK] FINISH on {config.finish_time}. Total run time: {config.finish_time - config.start_time}")

async def async_callback(flow_data, req):
    global pending_fuzz_count
    
    logger.info(f"[HOOK {flow_data['sid']}] Async callback triggered for: %s", flow_data["request"]["url"])

    # Call fuzz directly since it's now async with concurrency control
    pending_fuzz_count += 1
    try:
        async with fuzz_semaphore:
            print(f"[HOOK {flow_data['sid']}] Starting fuzz {flow_data["request"]["url"]} (pending: {pending_fuzz_count} requests)")
            logger.info(f"[HOOK {flow_data['sid']}] Starting fuzz (pending: {pending_fuzz_count})")
            await fuzz(flow_data, req)
            logger.info(f"[HOOK {flow_data['sid']}] Completed fuzz (remaining: {pending_fuzz_count - 1})")
    except Exception as e:
        logger.error(f"[HOOK {flow_data['sid']}] Fuzz failed with error: {e}")
    finally:
        pending_fuzz_count -= 1

def log_memory_usage(n_resp=0):
    pid = os.getpid()
    process = psutil.Process(pid)
    size = process.memory_info().rss / 1024 / 1024
    logger.info(f"[HOOK] Number response: {config.num_resp_captured} | Memory usage (MB): {size} PID: {pid}")
    logger.info(f"[STATS] {config.stats}")

# Helper function to extract timestamp
def current_utc_timestamp():
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]

def req_analysis(request_entry):
    logger.info(f"[HOOK {request_entry['sid']}] Check {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
    config.stats['total_req'] += 1

    if request_entry['response']['status_code'] in config.stats:
        config.stats[request_entry['response']['status_code']] += 1
    else:
        config.stats[request_entry['response']['status_code']] = 1

    request_entry['found_value'] = None
    req = convert_request_from_entry(request_entry)
    pairs = {}
    pairs.update({pv.param: pv.value for pv in req.paramvals})

    matching_queries, error_queries, found_value, combination_logs = find_queries_in_time_window(request_entry['request']['timestamp'], request_entry['response']['timestamp'], pairs, request_entry['sid'], request=req)

    if len(error_queries)>0:
        logger.info(f"[HOOK {request_entry['sid']}] Found Error Query: {error_queries} from {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        config.stats['error_req'] += 1

    request_entry['found_value'] = found_value
    if len(matching_queries)>0:
        logger.info(f"[HOOK {request_entry['sid']}] Get matching queries: {matching_queries} from {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        config.stats['sql_req'] += 1

        return req
    elif len(req.get_null_paramvals())>0:
        config.stats['null_req'] += 1
        logger.info(f"[HOOK {request_entry['sid']}] Seeing a null paramval. Fuzz it. {matching_queries} from {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        return req
    else:
        logger.info(f"[HOOK {request_entry['sid']}] The request does not trigger SQL query. Drop it. {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        config.stats['not_sql_req'] += 1
        return None

# Main addon class
class JSONLogger:
    def __init__(self):
        self.loop = asyncio.get_event_loop()
        # Dictionary to hold timestamps for each flow
        self.flow_timestamps = {}
        self.num_response = 0
        
        # Start the idle shutdown monitor
        global shutdown_monitor_started
        if not shutdown_monitor_started:
            shutdown_monitor_started = True
            self.loop.create_task(idle_shutdown_monitor())
            logger.info(f"[HOOK] Idle shutdown monitor scheduled (timeout: {IDLE_TIMEOUT}s)")

    def x_clear_up(self, flow):
        # Free memory by clearing contents
        flow.request.content = b""
        flow.response.content = b""
        flow.request.headers.clear()
        flow.response.headers.clear()
        flow.request.query = []
        flow.request.urlencoded_form = []
        flow.response.text = ""


    def request(self, flow: http.HTTPFlow):
        # Store request timestamp
        self.flow_timestamps[flow.id] = {
            "request_timestamp": current_utc_timestamp()
        }

    def response(self, flow: http.HTTPFlow):
        shared_state.last_activity_time = time.time()  # Update activity timestamp
        
        self.num_response += 1
        config.num_resp_captured += 1


        # Get timestamps
        timestamps = self.flow_timestamps.pop(flow.id, {})
        request_timestamp = timestamps.get("request_timestamp", current_utc_timestamp())
        response_timestamp = current_utc_timestamp()


        # Extract content-type (if exists)
        content_type = flow.response.headers.get("content-type", "") if flow.response else None
        req_content_type = flow.request.headers.get("content-type", None) if flow.request else None
        url = flow.request.pretty_url.lower()

        # Check if content type or file extension matches excluded types
        if (
                any(content_type.lower().startswith(t) for t in [
                    "application/javascript",
                    "application/x-javascript",
                    "text/javascript",
                    "text/css",
                    "image/",
                    "video/",
                    "audio/",
                    "font/",
                ])
                or url.endswith((".js", ".css", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".mp4", ".mp3", ".woff", ".woff2", ".ttf"))
        ):
            logger.info(f"[HOOK] Skip {url} because the content_type is {content_type}")
            return  # Do nothing / skip processing

        # Modify HTML responses
        if "text/html" in flow.response.headers.get("content-type", ""):
            html = flow.response.text

            # Replace links pointing to port 8081 with port 8888
            html = re.sub(
                rf"(https?://[^:/]+):{WUT_PORT}",
                rf"\1:{PROXY_PORT}",
                html,
                flags=re.IGNORECASE
            )

            flow.response.text = html

        # Modify redirect Location headers
        if "location" in flow.response.headers:
            location = flow.response.headers["location"]
            updated_location = re.sub(
                rf"(https?://[^:/]+):{WUT_PORT}",
                rf"\1:{PROXY_PORT}",
                location,
                flags=re.IGNORECASE
            )
            flow.response.headers["location"] = updated_location

        # Serialize the flow
        req_id = str(uuid.uuid4())

        data = {
            "id": req_id,
            "sid": req_id[-3:],
            "request": {
                "method": flow.request.method,
                "timestamp": request_timestamp,
                "url": flow.request.pretty_url,
                "content_type": req_content_type,
                "headers": dict(flow.request.headers),
                "body": flow.request.get_text()
            },
            "response": {
                "status_code": flow.response.status_code if flow.response else None,
                "timestamp": response_timestamp,
                "headers": dict(flow.response.headers) if flow.response else {},
                "body": flow.response.get_text() if flow.response else "",
                "content_type": content_type
            }
        }


        req = req_analysis(data)
        if req is not None:

            # Trigger async callback and track it
            task = self.loop.create_task(async_callback(data, req))
            active_tasks.add(task)
            task.add_done_callback(lambda t: active_tasks.discard(t))


# Register addon
addons = [
    JSONLogger()
]

# if __name__ == "__main__":
logger.info(f"Starting Time: {config.start_time}")
logger.info(f"Start MITM Addon with {MAX_CONCURRENT} max concurrent fuzzing tasks")
log_memory_usage()