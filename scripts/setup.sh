# !/bin/bash

cd ../
python get-pip.py
python -m venv venv
source venv/bin/activate
pip install -r requirement.txt
pip install pytest-playwright
playwright install
playwright install-deps --dry-run