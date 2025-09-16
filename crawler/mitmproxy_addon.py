import json
import asyncio
import logging
import os
import re
import socket
import uuid
from concurrent.futures import ThreadPoolExecutor

import psutil
from mitmproxy import http, ctx
from datetime import datetime

from HTTPRequest import convert_request_from_entry
from SQLIFuzz import fuzz
from SQLIRequestCollection import sqli_request_collection
from config import config
from sql_analysis import find_queries_in_time_window

WUT_PORT = os.environ.get('WUT_PORT', "8081")
PROXY_PORT = 8888

config.load_config(file_path="configs/config-general.yaml")

executor = ThreadPoolExecutor()

logger = config.logger

async def async_callback(flow_data):
    logger.info(f"[HOOK {flow_data['sid']}] Async callback triggered for: %s", flow_data["request"]["url"])

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(executor, fuzz, flow_data)

def log_memory_usage(n_resp=0):
    pid = os.getpid()
    process = psutil.Process(pid)
    size = process.memory_info().rss / 1024 / 1024
    logger.info(f"[HOOK] Number response: {n_resp} | Memory usage (MB): {size} PID: {pid}")
    logger.info(f"[STATS] {config.stats}")

def current_utc_timestamp():
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]

def req_analysis(request_entry):
    logger.info(f"[HOOK {request_entry['sid']}] Check {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
    config.stats['total_req'] += 1

    request_entry['found_value'] = None
    req = convert_request_from_entry(request_entry)
    pairs = {}
    pairs.update(dict(req.header))
    pairs.update({pv.param: pv.value for pv in req.paramvals})

    matching_queries, error_queries, found_value = find_queries_in_time_window(request_entry['request']['timestamp'], request_entry['response']['timestamp'], pairs, request_entry['sid'])

    if len(error_queries)>0:
        logger.info(f"[HOOK] Found Error Query: {error_queries} from {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        config.stats['error_req'] += 1

    request_entry['found_value'] = found_value
    if len(matching_queries)>0:
        logger.info(f"[HOOK {request_entry['sid']}] Get matching queries: {matching_queries} from {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        config.stats['sql_req'] += 1

        for query in matching_queries:
            if "**error" in query:
                req.SQL_detected = list()
                req.SQL_detected.append(query)

                logger.info(f"[HOOK] SQL Injection is detected: {req} ==> {query}")
                print(f"[HOOK] SQL Injection is detected: {req} ==> {query}")
                sqli_request_collection.add(req)
                sqli_request_collection.save_result()
                config.stats['sql_req_detected'] += 1
        return True
    elif len(req.get_null_paramvals())>0:
        logger.info(f"[HOOK {request_entry['sid']}] Seeing a null paramval. Fuzz it. {matching_queries} from {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        return True
    else:
        logger.info(f"[HOOK {request_entry['sid']}] The request does not trigger SQL query. Drop it. {request_entry['request']['method']} {request_entry['request']['url']} || {request_entry['request']['body']}")
        config.stats['not_sql_req'] += 1
        return False

class JSONLogger:
    def __init__(self):
        self.loop = asyncio.get_event_loop()
        # Dictionary to hold timestamps for each flow
        self.flow_timestamps = {}
        self.num_response = 0

    def x_clear_up(self, flow):
        # Free memory by clearing contents
        flow.request.content = b""
        flow.response.content = b""
        flow.request.headers.clear()
        flow.response.headers.clear()
        flow.request.query = []
        flow.request.urlencoded_form = []
        flow.response.text = ""

    def done(self):
        """Called when the proxy shuts down."""
        sqli_request_collection.print()
        sqli_request_collection.save_result(is_finish=True)

    def request(self, flow: http.HTTPFlow):
        # Store request timestamp
        self.flow_timestamps[flow.id] = {
            "request_timestamp": current_utc_timestamp()
        }

    def response(self, flow: http.HTTPFlow):
        self.num_response += 1
        if self.num_response % 200 == 0:
            log_memory_usage(self.num_response)

        # Get timestamps
        timestamps = self.flow_timestamps.pop(flow.id, {})
        request_timestamp = timestamps.get("request_timestamp", current_utc_timestamp())
        response_timestamp = current_utc_timestamp()

        content_type = flow.response.headers.get("content-type", "") if flow.response else None
        req_content_type = flow.request.headers.get("content-type", None) if flow.request else None
        url = flow.request.pretty_url.lower()

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

        if req_analysis(data):
            # Trigger async callback
            self.loop.create_task(async_callback(data))


# Register addon
addons = [
    JSONLogger()
]

# if __name__ == "__main__":
logger.info(f"Start MITM Addon")
log_memory_usage()