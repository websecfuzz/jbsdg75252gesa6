import asyncio
import json
import os
import sys
import time
from datetime import datetime, timezone

from playwright.async_api import async_playwright

from config import config
from general_functions import load_request_from_yaml_directory
from HTTPRequest import HTTPRequest


stats = config.stats
stats['fuzzed_req'] = 0
stats['processing_time_total'] = 0.0
stats['processing_time_ave'] = 0.0
config.stats['network_time_total'] = 0.0
config.stats['network_time_ave'] = 0.0

longest_time = 0.0


def safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs, flush=True)
    except BlockingIOError:
        try:
            sys.stdout.write("[WARN] stdout is busy; skipping log line\n")
        except Exception:
            pass


def extract_name(s):
    if not s:
        return ""

    prefix = "docker-compose-"
    suffix = ".yaml"

    if s.startswith(prefix) and s.endswith(suffix):
        return s[len(prefix):-len(suffix)]

    return ""


def _json_safe(value):
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    if isinstance(value, tuple):
        return [_json_safe(item) for item in value]
    if isinstance(value, dict):
        safe_dict = {}
        for key, val in value.items():
            safe_dict[str(key)] = _json_safe(val)
        return safe_dict
    return str(value)


def get_progress_file_path(wut_name):
    COMPOSE_FILE = os.environ.get('COMPOSE_FILE', '')
    COMPOSE_FILE_NAME = extract_name(COMPOSE_FILE)

    os.makedirs("saved_requests", exist_ok=True)
    return os.path.join("saved_requests", f"{wut_name}_{COMPOSE_FILE_NAME}_fuzz_progress.json")


def build_config_snapshot():
    snapshot = {}
    excluded_keys = {'logger'}
    for key, value in config.__dict__.items():
        if key in excluded_keys:
            continue
        snapshot[key] = _json_safe(value)
    return snapshot


def save_progress(progress_file, *, wut_name, compose_file, host_name, total_requests, last_processed_index, last_request_id, last_response_status):
    payload = {
        "version": 1,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "wut_name": wut_name,
        "compose_file": compose_file,
        "host_name": host_name,
        "total_requests": total_requests,
        "last_processed_index": last_processed_index,
        "last_request_id": last_request_id,
        "last_response_status": last_response_status,
        "longest_time": longest_time,
        "stats": _json_safe(config.stats),
        "config_values": build_config_snapshot(),
    }
    with open(progress_file, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)


def load_progress(progress_file):
    if not os.path.exists(progress_file):
        return None

    try:
        with open(progress_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        safe_print(f"[FUZZ] Failed to read progress file {progress_file}: {e}")
        return None


def archive_completed_progress_file(progress_file):
    if not os.path.exists(progress_file):
        return None

    directory = os.path.dirname(progress_file)
    filename = os.path.basename(progress_file)
    archived_name = f"finish_{filename}"
    archived_path = os.path.join(directory, archived_name)

    if os.path.exists(archived_path):
        ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        archived_name = f"finish_{ts}_{filename}"
        archived_path = os.path.join(directory, archived_name)

    os.rename(progress_file, archived_path)
    return archived_path


def restore_from_progress(progress_data):
    global longest_time

    if not progress_data:
        return

    saved_stats = progress_data.get("stats", {})
    if isinstance(saved_stats, dict):
        config.stats.clear()
        config.stats.update(saved_stats)

    saved_longest = progress_data.get("longest_time", 0.0)
    try:
        longest_time = float(saved_longest)
    except Exception:
        longest_time = 0.0

    saved_config_values = progress_data.get("config_values", {})
    if isinstance(saved_config_values, dict):
        for key, value in saved_config_values.items():
            if key == 'logger':
                continue
            if hasattr(config, key):
                try:
                    setattr(config, key, value)
                except Exception:
                    pass


async def render_and_screenshot(page, response, request, add_name=None):
    wut_name = os.environ.get('WUT_NAME', 'default')
    safe_print(f"[FUZZ] Calling render_and_screenshot for request {request.id[-3:]} with add_name: {add_name}")
    if page is None or response is None:
        safe_print(f"[FUZZ] Page or response is None, skipping render_and_screenshot for request {request.id[-3:]}")
        return

    try:
        headers = response.headers
    except Exception:
        headers = {}

    content_type = headers.get("content-type", "") if isinstance(headers, dict) else ""

    try:
        body_text = await response.text()
    except Exception as e:
        safe_print(f"[FUZZ] Failed to get response text for request {request.id[-3:]}, skipping render_and_screenshot. Error: {e}")
        return

    if not body_text:
        safe_print(f"[FUZZ] Response body is empty for request {request.id[-3:]}, skipping render_and_screenshot.")
        return

    is_html = "text/html" in content_type.lower() or body_text.lstrip().startswith("<")
    if not is_html:
        os.makedirs("data", exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
        safe_id = request.id.replace("/", "_")
        if add_name:
            text_path = os.path.join("data", f"[{add_name}]_{wut_name}_{safe_id}_{ts}.txt")
        else:
            text_path = os.path.join("data", f"{wut_name}_{safe_id}_{ts}.txt")
        with open(text_path, "w", encoding="utf-8", errors="replace") as f:
            f.write(body_text)
        safe_print(f"[FUZZ] Non-HTML response saved: {text_path}")
        return

    try:
        await page.set_content(body_text, wait_until="load")
    except Exception as e:
        safe_print(f"[FUZZ] Failed to set page content for request {request.id[-3:]}, retrying without wait_until. Error: {e}")
        await page.set_content(body_text)

    os.makedirs("data", exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
    safe_id = request.id.replace("/", "_")
    if add_name:
        screenshot_path = os.path.join("data", f"[{add_name}]_{wut_name}_{safe_id}_{ts}.png")
    else:
        screenshot_path = os.path.join("data", f"{wut_name}_{safe_id}_{ts}.png")
    await page.screenshot(path=screenshot_path, full_page=True)
    safe_print(f"[FUZZ] Screenshot saved: {screenshot_path}")


async def send_request(page, request):
    global longest_time
    safe_print(f"[GENERALFUNCTION {request.id[-3:]}] ---SENDING THE REQUEST [{request.id}] TO : [{request.method}] {request.full_url}")
    safe_print(f"[GENERALFUNCTION {request.id[-3:]}] Post data encoded: {request.post_data_encoded}")

    api_request_context = page.request

    try:
        start_calculation = None

        fetch_start = None
        if request.content_type and str(request.content_type).find("multipart/form-data") > -1:
            safe_print(f"[GENERALFUNCTION {request.id[-3:]}] Send using multipart/form-data type")
            start_calculation = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S,%f")
            fetch_start = time.perf_counter()

            response = await api_request_context.fetch(url_or_request=request.full_url,
                                                       method=request.method,
                                                       headers=request.header,
                                                       multipart=request.body_param_dict)
        else:
            start_calculation = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S,%f")
            fetch_start = time.perf_counter()

            response = await api_request_context.fetch(url_or_request=request.full_url,
                                                       method=request.method,
                                                       headers=request.header,
                                                       data=request.post_data_encoded)
        fetch_end = time.perf_counter()

        end_calculation = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S,%f")

        if request.timing is None:
            request.timing = dict()

        request.timing["network_duration"] = max(0.0, fetch_end - fetch_start)

        request.timing["start_calculation"] = start_calculation
        request.timing["end_calculation"] = end_calculation
        request.timing["calculation_duration"] = (datetime.strptime(end_calculation, "%Y-%m-%d %H:%M:%S,%f") - datetime.strptime(start_calculation, "%Y-%m-%d %H:%M:%S,%f")).total_seconds()

        config.stats['fuzzed_req'] = int(config.stats.get('fuzzed_req', 0)) + 1
        config.stats['processing_time_total'] = float(config.stats.get('processing_time_total', 0.0)) + request.timing["calculation_duration"]
        config.stats['processing_time_ave'] = config.stats['processing_time_total'] / max(config.stats['fuzzed_req'], 1)

        config.stats['network_time_total'] = float(config.stats.get('network_time_total', 0.0)) + request.timing["network_duration"]
        config.stats['network_time_ave'] = config.stats['network_time_total'] / max(config.stats['fuzzed_req'], 1)

        safe_print(f"Processing time for request {request.id[-3:]}: {request.timing['calculation_duration']:.4f}s")
        if request.timing["calculation_duration"] > longest_time:
            longest_time = request.timing["calculation_duration"]
            safe_print(f"New longest processing time: {longest_time:.4f}s for request {request.id[-3:]}")
            if longest_time > 3.0:
                await render_and_screenshot(page, response, request, add_name=f"{longest_time:.4f}s")

        safe_print(f"Average processing time: {config.stats['processing_time_ave']:.4f}s")
        safe_print(f"Average network (perf) time: {config.stats['network_time_ave']:.4f}s")

        return response
    except Exception as e:
        safe_print(f"[GENERALFUNCTION {request.id[-3:]}] Web server is error!: {str(e)[:2000]}")
        return None


async def main():
    compose_file = os.environ.get('COMPOSE_FILE', '')
    host_name = os.environ.get('HOST_NAME', '')
    safe_print(f"[FUZZ] Starting fuzzing for compose file: {compose_file}")

    wut_name = os.environ.get('WUT_NAME', 'default')
    directory = f"saved_requests/{wut_name}/"
    progress_file = get_progress_file_path(wut_name)

    raw_cookie = os.environ.get('cookie_value', None)
    cookie_value = raw_cookie.replace("Cookie: ", "", 1) if raw_cookie else None

    if not os.path.exists(directory):
        safe_print(f"[FUZZ] Directory {directory} does not exist.")
        return

    safe_print(f"[FUZZ] Loading requests from {directory}")
    request_data_list = load_request_from_yaml_directory(directory)
    safe_print(f"[FUZZ] Loaded {len(request_data_list)} requests")

    if not request_data_list:
        safe_print("[FUZZ] No requests found to replay.")
        return

    total_requests = len(request_data_list)
    last_processed_index = 0
    should_create_fresh_progress = False
    progress_data = load_progress(progress_file)
    if progress_data:
        resume_allowed = progress_data.get("wut_name") == wut_name and int(progress_data.get("total_requests", 0)) == total_requests
        if resume_allowed:
            loaded_last_processed_index = int(progress_data.get("last_processed_index", 0))
            if loaded_last_processed_index >= total_requests:
                archived_path = archive_completed_progress_file(progress_file)
                if archived_path:
                    safe_print(f"[FUZZ] Previous progress is complete. Archived progress file to {archived_path}.")
                should_create_fresh_progress = True
                last_processed_index = 0
            else:
                restore_from_progress(progress_data)
                last_processed_index = loaded_last_processed_index
                safe_print(f"[FUZZ] Progress loaded from {progress_file}. Resuming from request {last_processed_index + 1}.")
        else:
            safe_print("[FUZZ] Existing progress file does not match current run context. Starting from request 1.")

    if should_create_fresh_progress:
        save_progress(
            progress_file,
            wut_name=wut_name,
            compose_file=compose_file,
            host_name=host_name,
            total_requests=total_requests,
            last_processed_index=0,
            last_request_id=None,
            last_response_status=None,
        )
        safe_print(f"[FUZZ] Created fresh progress file: {progress_file}")

    start_index = max(1, last_processed_index + 1)
    if start_index > total_requests:
        safe_print("[FUZZ] All requests were already processed according to progress file.")
        return

    playwright = await async_playwright().start()
    browser = await playwright.chromium.launch(headless=True)
    context = await browser.new_context()
    page = await context.new_page()
    all_requests_succeeded = True

    try:
        for idx in range(start_index, len(request_data_list) + 1):
            request_data = request_data_list[idx - 1]
            safe_print(f"[FUZZ] Replaying request {idx}/{len(request_data_list)}")

            request = HTTPRequest()
            request.full_url = request_data.get('full_url', '')
            request.url = request_data.get('full_url', '').split('?')[0]
            request.method = request_data.get('method', 'GET')
            request.header = request_data.get('header_to_send', {})
            if cookie_value:
                request.header['Cookie'] = cookie_value
                safe_print(f"[GENERALFUNCTION {request.id[-3:]}] Added Cookie header for curl: {cookie_value}")

            request.post_data_encoded = request_data.get('post_data_encoded', None)
            request.body_param_dict = request_data.get('body_param_dict', None)
            request.content_type = request_data.get('content_type', None)
            request.timing = request_data.get('timing', None)
            request.id = f"replay_{idx}"
            request.param_encoded = None

            if '?' in request.full_url:
                request.param_encoded = request.full_url.split('?', 1)[1]

            response = await send_request(page, request)

            if response:
                safe_print(f"[FUZZ] Request {idx} completed with status: {response.status}")
                if response.status in config.stats:
                    config.stats[response.status] += 1
                else:
                    safe_print(f"[FUZZ] First time seeing status {response.status}, initializing count.")
                    config.stats[response.status] = 1
                    await render_and_screenshot(page, response, request, add_name=f"status_{response.status}")

                save_progress(
                    progress_file,
                    wut_name=wut_name,
                    compose_file=compose_file,
                    host_name=host_name,
                    total_requests=total_requests,
                    last_processed_index=idx,
                    last_request_id=request.id,
                    last_response_status=response.status,
                )
                safe_print(f"[FUZZ] Progress saved at request {idx}: {progress_file}")
            else:
                safe_print(f"[FUZZ] Request {idx} failed")
                all_requests_succeeded = False
    finally:
        await context.close()
        await browser.close()
        await playwright.stop()

    compose_file_name = extract_name(compose_file)
    stats_file = f"saved_requests/{wut_name}_fuzz_{compose_file_name}_{host_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    safe_print(f"[FUZZ] Saving statistics to {stats_file}")

    with open(stats_file, 'w', encoding='utf-8') as f:
        f.write("=== Fuzzing Statistics ===\n")
        f.write(f"Compose file: {compose_file}\n")
        f.write(f"WUT name: {wut_name}\n")
        f.write(f"Host name: {host_name}\n")
        f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

        for key, value in config.stats.items():
            f.write(f"{key}: {value}\n")

        f.write("\n=== End of Statistics ===\n")

    safe_print(f"[FUZZ] Statistics saved to {stats_file}")
    safe_print(f"[FUZZ] Total requests fuzzed: {config.stats.get('fuzzed_req', 0)}")
    safe_print(f"[FUZZ] Average processing time: {float(config.stats.get('processing_time_ave', 0)):.4f}s")

    if all_requests_succeeded and os.path.exists(progress_file):
        archived_path = archive_completed_progress_file(progress_file)
        if archived_path:
            safe_print(f"[FUZZ] Run completed. Archived progress file to {archived_path}.")


if __name__ == "__main__":
    asyncio.run(main())
