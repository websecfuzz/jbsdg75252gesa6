import importlib
import os
import sys
import json
import traceback
from concurrent.futures import ProcessPoolExecutor

import asyncio
from datetime import datetime

from playwright.async_api import async_playwright

from SQLIRequestCollection import sqli_request_collection
from config import config
from function import manual_login, exclude_certain_index, get_state_path, retrieve_arguments, \
    combine_url
from Dictionary import dictionary
from GlobalAttackSurfaces import global_attack_surfaces
from main_driver import MainDriver

async def running_tasks(tasks):
    for task in tasks:
        await task

def save_req_data():
    base_appdir = "../working/"
    requestsFound = {}

    idx = 0
    for attack in global_attack_surfaces.data:
        req = attack.target
        if req.SQL_detected==None or len(req.SQL_detected)==0:
            continue

        idx += 1
        key = f"{req.method} {req.full_url}"
        
        response_code = 200
        if req.response_code:
            response_code = req.response_code
        
        entry = {
            "_id": idx,
            "_urlstr": req.full_url,
            "_url": req.url,
            "_resourceType": "",
            "_method": req.method,
            "_postData": req.post_data_encoded,
            "_headers": req.header,
            "key": key,
            "timing": req.timing,            
            "response_status": response_code,
            "response_content-type": req.content_type,
            "sql_queries": req.SQL_detected
        }
        requestsFound[key] = entry

    inputSet = list()
    for pv in dictionary.data:
        inputSet.append(f"{pv.param}={pv.value}")

    jdata = json.dumps({"requestsFound": requestsFound, "inputSet": inputSet});
    json_fn = os.path.join(base_appdir, f"request_data_{config.data['PROJECT_NAME']}.json")
    with open(json_fn, "w") as txt_file:
        txt_file.write(jdata)

def init():
    args = retrieve_arguments()
    if args.config:
        config.load_config(file_path="../configs/"+args.config)
    else:
        config.load_config(file_path="../configs/config-general.yaml")
    if args.hour:
        config.data['RUNNING_TIME']['h'] = args.hour
        print(f"[FUZZER] SET RUNNING TIME {config.data['RUNNING_TIME']['h']} hours")
    if args.minute:
        config.data['RUNNING_TIME']['m'] = args.minute
        print(f"[FUZZER] SET RUNNING TIME {config.data['RUNNING_TIME']['m']} minutes")
    config.calculate_finish_time()
    if args.url:
        config.data['HOMEPAGE_URL'] = args.url
        print(f"[FUZZER] SET HOMEPAGE URL: {config.data['HOMEPAGE_URL']}")
    if args.name:
        config.data['PROJECT_NAME'] = args.name
        print(f"[FUZZER] SET PROJECT_NAME: {config.data['PROJECT_NAME']}")
    if args.roles:
        config.data['USER_ROLES'] = args.roles
        print(f"[FUZZER] SET USER_ROLES: {config.data['USER_ROLES']}")
    if args.only_driver:
        config.enable_checker = False
        print(f"[FUZZER] Only Running the Driver Module. Turn off the checker")
    if args.only_checker:
        config.enable_driver = False
        print(f"[FUZZER] Only Running the Checker Module. Turn off the driver")
    if args.only_crawling:
        config.only_crawling = True
        config.enable_driver = False
        config.enable_checker = False
        print(f"[FUZZER] Only Running the Crawling Module. Turn off the driver and the checker")
    if args.without_login:
        config.without_login = True
        print(f"[FUZZER] Without Login; Only Using the stored cookie")
    if args.ignored_sql:
        config.data['IGNORING_SQL'] += args.ignored_sql
        print(f"[FUZZER] Total DB tables that should be ignored:",config.data['IGNORING_SQL'])
    if args.proxy:
        config.proxy = args.proxy
        print(f"[FUZZER] Set up a proxy server:",config.proxy)

    cleaned_file_name = config.data['PROJECT_NAME'].replace('-', '').replace('.', '')
    config.data['PROJECT_NAME'] = config.data['PROJECT_NAME'].replace('-', '').replace('.', '')
    if os.path.exists(f"../auto_login/{cleaned_file_name}.py") and not config.without_login:
        print(f"[FUZZER] Calling login module: {cleaned_file_name}")

        sys.path.append('../auto_login/')
        mod=importlib.import_module(cleaned_file_name)
        
        meth = getattr(mod, "main", None)
        print(meth)
        if callable(meth):
            meth(config)
    else:
        folder_name = f"../login_state/{config.data['PROJECT_NAME']}"
        os.makedirs(folder_name, exist_ok=True)

async def main():
    start_time = datetime.now()
    print("STARTING TIME:", start_time)
    
    user_roles = config.data['USER_ROLES']
    drivers = {}

    homepages = config.homepages
    state_paths = {}

    async with async_playwright() as playwright:
            tasks = list()
            if config.enable_driver or config.only_crawling:
                for role in user_roles:
                    if os.path.exists(f"../auto_login/{config.data['PROJECT_NAME']}.py") and not config.without_login:
                        state_paths[role] = get_state_path(role)
                        if role in homepages:
                            print(f"[FUZZER] Specific homepage for {role} is found:",homepages[role])
                        else:
                            print(f"[FUZZER] No Homepage for {role} is found. Using the default one")
                            homepages[role] = config.data['HOMEPAGE_URL']
                    elif not config.without_login:
                        state_paths[role], homepages[role] = await manual_login(playwright, role, login_url=config.data['HOMEPAGE_URL'])
                    else:
                        state_paths[role] = get_state_path(role)
                        if role in homepages:
                            homepages[role] = combine_url(homepages[role], config.data['HOMEPAGE_URL'])
                        else:
                            homepages[role] = config.data['HOMEPAGE_URL']

                    drivers[role] = MainDriver(role)

                    await drivers[role].start_with_login_state(playwright, state_paths[role])
                    if config.only_crawling:
                        tasks.append(asyncio.create_task(drivers[role].crawl(homepages[role], is_saving_request=False)))
                    else:
                        tasks.append(asyncio.create_task(drivers[role].crawl(homepages[role])))

            await running_tasks(tasks)

            print(f"[FUZZER] Campaign duration: {datetime.now() - start_time}")

            if not config.only_crawling:
                # save_req_data()
                sqli_request_collection.print()
                sqli_request_collection.save_result(is_finish=True)

if __name__ == "__main__":
    init()
    asyncio.run(main())
