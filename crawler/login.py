import importlib
import json
import os
import sys

from config import config

WUT_NAME = os.environ.get('WUT_NAME', "")

if os.path.exists(f"../auto_login/{WUT_NAME}.py"):
    print(f"[FUZZER] Calling login module: {WUT_NAME}.py")

    sys.path.append('../auto_login/')
    mod=importlib.import_module(WUT_NAME)

    meth = getattr(mod, "main", None)
    print(f"[FUZZER] {meth}")
    if callable(meth):
        meth(config)

data_path = f"../login_state/{WUT_NAME}/Admin.json"
if os.path.exists(data_path):
    print(f"[FUZZER] Extract data from : {data_path}")
    # Load cookies from the file
    with open(data_path, 'r') as f:
        data = json.load(f)

    # Extract the cookies and format them for the Cookie header
    cookie_header = "; ".join([f"{cookie['name']}={cookie['value']}" for cookie in data['cookies']])

    # Save the "Cookie" header string to a file
    with open(f"../login_state/{WUT_NAME}/Admin.txt", 'w') as f:
        f.write(f"Cookie: {cookie_header}")

    print("[FUZZER] Cookie header is saved")