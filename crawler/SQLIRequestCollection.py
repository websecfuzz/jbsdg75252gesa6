import os
import socket

from config import config

logger = config.logger

class SQLIRequestCollection:
    def __init__(self):
        self.data = list()

    def add(self, request):
        for req in self.data:
            if request.url ==req.url:
                print("[SQLICollection] This request has been saved before. Drop it. ", request)
                return False

        self.data.append(request)

    def save_result(self, is_finish=False):
        start_time = config.start_time
        WUT_NAME = os.environ.get('WUT_NAME', None)
        if WUT_NAME==None:
            WUT_NAME = config.data['PROJECT_NAME']

        FUZZER_NAME = os.environ.get('FUZZER_NAME', "")
        hostname = socket.gethostname()

        filename = f"final_result/{WUT_NAME}-{FUZZER_NAME}-{hostname}-{start_time.strftime('%s')}.txt"
        if is_finish:
            filename = f"final_result/FR-{WUT_NAME}-{FUZZER_NAME}-{hostname}-{start_time.strftime('%s')}.txt"

        logger.info(f"[SQLICollection] Result will be saved in {filename}")
        logger.info(f"[SQLICollection] Statistics: {config.stats}")
        with open(filename, "w") as txt_file:
            txt_file.write(f"{config.stats}\n\n")
            for index, req in enumerate(self.data):
                txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} ==> {req.SQL_detected} || {req.error_SQL_detected}\n")



    def print(self):
        logger.info("\n\n\n-----FINAL RESULT------")
        for index, req in enumerate(self.data):
            logger.info(f"{index+1}. {req} ==> {req.SQL_detected}")


sqli_request_collection = SQLIRequestCollection()