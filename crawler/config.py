import logging
import os
import socket

import yaml
from datetime import datetime, timedelta

class Config:
    def __init__(self, file_path=None):
        self.start_time = datetime.now()
        self.finish_time = self.start_time + timedelta(hours=8)
        self.file_path = file_path
        self.data = None
        self.homepages = {}
        self.enable_driver = True
        self.enable_checker = True
        self.only_crawling = False
        self.without_login = False
        self.line_coverage = {}
        self.proxy = None
        self.AIModel = "deepseek/deepseek-chat" ## Other option: "gemini/gemini-2.0-flash"
        self.sql_analysis = True
        self.SAFE_GAP = 50 ## milisecond
        self.logger = self.setup_custom_logger()
        self.stats = {}
        if file_path is not None:
            self.load_config()

    def setup_custom_logger(self):
        os.makedirs("log", exist_ok=True)
        logger = logging.getLogger("sqlifuzz")
        logger.setLevel(logging.INFO)

        # Avoid adding multiple handlers if reloaded
        if not logger.handlers:
            WUT_NAME = os.environ.get('WUT_NAME', "")
            FUZZER_NAME = os.environ.get('FUZZER_NAME', "")
            hostname = socket.gethostname()
            fh = logging.FileHandler(f"log/{FUZZER_NAME}_{WUT_NAME}_{hostname}_{self.start_time.strftime('%s')}.log")
            formatter = logging.Formatter("%(message)s")
            fh.setFormatter(formatter)
            logger.addHandler(fh)

        return logger

    def calculate_finish_time(self):
        self.finish_time = self.start_time + timedelta(hours=self.data['RUNNING_TIME']['h'],minutes=self.data['RUNNING_TIME']['m'])

    def load_config(self, file_path=None):
        if file_path is not None:
            self.file_path = file_path

        with open(self.file_path, encoding="utf-8_sig") as f:
            self.data = yaml.load(f, Loader=yaml.FullLoader)
        self.logger.info(f'[CONFIG] A config file from {self.file_path} is loaded.')

config = Config()