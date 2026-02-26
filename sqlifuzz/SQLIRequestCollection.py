import os
import socket

from config import config

logger = config.logger

class SQLIRequestCollection:
    def __init__(self):
        self.data = list()
        self.sqli_detected = list()
        self.matched_without_error = list()
        self.different_error = list()

    # def add(self, request):
    #     for req in self.data:
    #         if request.url ==req.url:
    #             print("[SQLICollection] This request has been saved before. Drop it. ", request)
    #             return False


    #     # if request in self.data:
    #     #     print("[SQLICollection] This request has been saved before. Drop it. ", request)
    #     #     return False

    #     self.data.append(request)

    def add_to_matched_without_error(self, request):
        if request.parent:
            for req in self.matched_without_error:
                if request.parent.url ==req.parent.url:
                    # print("[SQLICollection] This request has been saved before. Drop it. ", request)
                    return False

        self.matched_without_error.append(request)

    def add_to_different_error(self, request):
        if request.parent:
            for req in self.different_error:
                if request.parent.url ==req.parent.url:
                    # print("[SQLICollection] This request has been saved before. Drop it. ", request)
                    return False

        self.different_error.append(request)
        return True

    def add(self, request):
        if request.SQL_injection_detected:
            return self.add_to_collection(self.sqli_detected, request)
        else:
            return self.add_to_collection(self.data, request)

    def add_to_collection(self, collection, request):
        if request.parent:
            for req in collection:
                # if request.url ==req.url:
                if request.parent.url ==req.parent.url:
                    # print("[SQLICollection] This request has been saved before. Drop it. ", request)
                    return False


        # if request in self.data:
        #     print("[SQLICollection] This request has been saved before. Drop it. ", request)
        #     return False

        collection.append(request)

    def save_result(self, is_finish=False):
        start_time = config.start_time
        WUT_NAME = os.environ.get('WUT_NAME', None)
        if WUT_NAME==None:
            WUT_NAME = config.data['PROJECT_NAME']

        FUZZER_NAME = os.environ.get('FUZZER_NAME', "")
        hostname = socket.gethostname()

        filename = f"final_result/{WUT_NAME}-{FUZZER_NAME}-{hostname}-{start_time.strftime('%s')}.txt"
        if is_finish:
            filename = f"final_result/FR/FR-{WUT_NAME}-{FUZZER_NAME}-{hostname}-{start_time.strftime('%s')}.txt"

        logger.info(f"[SQLICollection] Result will be saved in {filename}")
        logger.info(f"[SQLICollection] Statistics: {config.stats}")
        with open(filename, "w") as txt_file:
            txt_file.write(f"{config.stats}\n\n")

            txt_file.write(f"###Matched SQL Injection Detected: [METHOD] | [URL] | [PARAMS] | [POST_DATA] [MATCHED_PAYLOAD] ==> [SQLi_DETECTED]\n")
            if len(self.sqli_detected)==0:
                txt_file.write("No SQL Injection Detected.\n")
            else:
                for index, req in enumerate(self.sqli_detected):
                    txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} [{req.matched_payload}] ==> {req.SQL_injection_proof}\n")

            txt_file.write(f"\n\n\n\n\n##################################################:\n")            
            txt_file.write(f"\n###Matched but Different SQL Error:\n")            
            txt_file.write(f"###[METHOD] | [URL] | [PARAMS] | [POST_DATA] [MATCHED_PAYLOAD] ==> [SQL_DETECTED] || [ERROR_SQL_DETECTED]\n")
            for index, req in enumerate(self.different_error):
                # txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} ==> {req.SQL_detected if req.SQL_detected and len(req.SQL_detected)>0 else req.error_SQL_detected}\n")
                txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} ==> {req.SQL_detected} || {req.error_SQL_detected}\n")

            txt_file.write(f"\n###SQL Error but No Matched Strings:\n")            
            txt_file.write(f"###[METHOD] | [URL] | [PARAMS] | [POST_DATA] [MATCHED_PAYLOAD] ==> [SQL_DETECTED] || [ERROR_SQL_DETECTED]\n")
            for index, req in enumerate(self.data):
                # txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} ==> {req.SQL_detected if req.SQL_detected and len(req.SQL_detected)>0 else req.error_SQL_detected}\n")
                txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} ==> {req.SQL_detected} || {req.error_SQL_detected}\n")

            txt_file.write(f"\n###Matched Strings but No SQL error:\n")
            for index, req in enumerate(self.matched_without_error):
                # txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} ==> {req.SQL_detected if req.SQL_detected and len(req.SQL_detected)>0 else req.error_SQL_detected}\n")
                txt_file.write(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} [{req.matched_payload}] ==> {req.SQL_detected} \n")


    def print(self):
        logger.info("\n\n\n-----FINAL RESULT------")
        print("FINAL RESULT")

        logger.info(f"###Matched SQL Injection Detected: [METHOD] | [URL] | [PARAMS] | [POST_DATA] [MATCHED_PAYLOAD] ==> [SQL_DETECTED] || [ERROR_SQL_DETECTED]\n")
        print("###Matched SQL Injection Detected: [METHOD] | [URL] | [PARAMS] | [POST_DATA] [MATCHED_PAYLOAD] ==> [SQL_DETECTED] || [ERROR_SQL_DETECTED]\n")
        if len(self.sqli_detected)==0:
            logger.info("No SQL Injection Detected.\n")
            print("No SQL Injection Detected.\n")
        else:
            for index, req in enumerate(self.sqli_detected):
                logger.info(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} [{req.matched_payload}] ==> {req.SQL_injection_proof}\n")
                print(f"{index+1}. {req.method} | {req.url} | {req.param_encoded} | {req.post_data_encoded} [{req.matched_payload}] ==> {req.SQL_injection_proof}\n")   

sqli_request_collection = SQLIRequestCollection()