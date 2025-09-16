import os
import random
import traceback

from datetime import datetime
from config import config

from HTTPRequest import convert_yaml_file_to_request
from AttackSurface import AttackSurface
from Dictionary import dictionary
from VerificationLabel import VerificationLabel
from general_functions import extract_sql_command_and_table, extract_all_pairs
from sql_analysis import find_queries_in_time_window
from time import strftime, localtime


def str_obj(list):
    str = ""
    for l in list:
        return str + f"{l} "

class GlobalAttackSurfaces:
    def __init__(self):
        self.data = list()
        self.success_inputs = list()
        self.processing_time = dict()
        self.response_codes = dict()
        
    def get_response_code_proportion(self):
        proportion = dict()
        total = 0
        try:
            for code in self.response_codes:
                total = total + self.response_codes[code]

            for code in self.response_codes:
                proportion[code] = self.response_codes[code] / total
        except Exception as e:
            print(f"[GLOBALAS] Error in get_response_code_proportion: {e}")

        return proportion

    def add_response_code(self, code):
        if code in self.response_codes:
            self.response_codes[code] += 1
        else:
            self.response_codes[code] = 1

    def add_success_input(self, input):
        self.success_inputs.append(input)

    def add(self, attack_surface, role):
        for attack in self.data:
            if attack == attack_surface:
                print(f"[GLOBALAS] The new attack surface is the same with: {attack}")
                if role in attack.roles:
                    print(f"[GLOBALAS] Drop the attack surface because it exists: {attack_surface} with role {role}")
                    return False
                else:
                    print(f"[GLOBALAS] Only adding role {role} of the attack surface")
                    attack.roles.append(role)
                    return True
        print(f"[GLOBALAS] New attack surface! Add it {attack_surface}")
        attack_surface.roles.append(role)
        self.data.append(attack_surface)
        return True

    def add_expanded_request(self, request, role):
        attack_surface = AttackSurface(request)
        print(f"[GLOBALAS] New attack surface! Add it {attack_surface}")
        attack_surface.roles.append(role)
        self.data.append(attack_surface)

        if config.sql_analysis and len(request.paramvals)>0:
            pairs = {}
            pairs.update(dict(request.header))
            pairs.update({pv.param: pv.value for pv in request.paramvals})
            matching_queries, error_queries, found_values = find_queries_in_time_window(request.timing["start_calculation"], request.timing["end_calculation"], pairs)
            request.SQL_detected = matching_queries
            if len(matching_queries)>0:
                return True
        return False

    def get_random_attack_surface(self):
        if len(self.data)>0:
            idx = random.randint(0,len(self.data)-1)
            return self.data[idx]
        else:
            return None

    def get_detected_time(self,inp):
        if inp.detected_time:
            return inp.detected_time
        return datetime.now()

    def get_sent_role(self, inp):
        if inp.sent_role:
            return inp.sent_role
        return "0"

    def get_mutated_params(self,inp):
        ## Return paramname1paramname2
        mutated_params = [pv.param for pv in inp.mutated_paramvals]
        if len(mutated_params)>0:
            return ''.join(mutated_params)
        return "0"

    def get_numerical_source(self,inp):
        if inp.request.source == "InterceptedRequest":
            return 1
        else:
            return len(inp.request.source)

    def time_diff(self,later_time, first_time):
        difference = later_time - first_time
        duration_in_s = difference.total_seconds()
        days    = divmod(duration_in_s, 86400)        # Get days (without [0]!)
        hours   = divmod(days[1], 3600)               # Use remainder of days to calc hours
        minutes = divmod(hours[1], 60)                # Use remainder of hours to calc minutes
        seconds = divmod(minutes[1], 1)

        return days,int(hours[0]),int(minutes[0]),int(seconds[0])

    def print_param_ref(self):
        print("\n-----Calling print_param_ref")
        params = list()
        for attack_surface in global_attack_surfaces.data:
            try:
                request = attack_surface.target
                if request.reference_params:
                    for pv in request.paramvals:
                        for param_nested in pv.paramvals:
                            if param_nested.is_reference and param_nested.param not in params:
                                params.append(param_nested.param)
                                vals = dictionary.search_field_values(param_nested.param)
                                print(f"{param_nested.param} ==> {vals}")
                        if pv.is_reference and pv.param not in params:
                            if not pv.is_nested():
                                params.append(pv.param)
                                vals = dictionary.search_field_values(pv.param)
                                print(f"{pv.param} ==> {vals}")
            except Exception as e:
                print(f"[GAS] Error in print_param_ref: {e}")
                print(f"[GAS] {traceback.format_exc()[:500]}")
        print("TOTAL param_ref:", len(params))


    def load_attack_surface_from_file(self, foldername="default"):
        if "PROJECT_NAME" in config.data:
            foldername = config.data["PROJECT_NAME"]
        dir_location = os.path.join(os.getcwd(), '../attack_surface', foldername)
        print(f"[GLOBALAS] Loading the corpus from files in dir:", dir_location)

        for rolename in os.listdir(dir_location):
            role_location = os.path.join(dir_location, rolename)

            if os.path.isdir(role_location):
                for filename in os.listdir(role_location):
                    request = convert_yaml_file_to_request(f"{role_location}/{filename}")
                    attack = AttackSurface(request)
                    print(f"[GLOBALAS] Save it to Global Attack Surface [{filename}]:",attack)
                    self.add(attack, rolename)

        print(f"[GLOBALAS] In total, we got {len(self.data)} Attack Surface")
        print(f"[GLOBALAS] Num of Ref param per total param: {dictionary.num_ref_param}/{len(dictionary.data)} ")

    def get_command_and_table_name(self, queries):
        for query in queries:
            command, table = extract_sql_command_and_table(query)
            if command and table:
                return f"{command} {table}"
        return ""

    def is_same_table_names(self, queries1, queries2):
        names1 = set()
        for query in queries1:
            command, table = extract_sql_command_and_table(query)
            names1.add(table)

        names2 = set()
        for query in queries2:
            command, table = extract_sql_command_and_table(query)
            names2.add(table)

        return set(names1) <= set(names2) or set(names2) <= set(names1)

    def analyse_and_print_final_result(self, start_time, is_finish=False):
        endpoints = list()

        i = 0
        filename = f"../final_result/{config.data['PROJECT_NAME']}-{start_time.hour}{start_time.minute}{start_time.second}{start_time.microsecond}.txt"
        if is_finish:
            filename = f"../final_result/FR-{config.data['PROJECT_NAME']}-{start_time.hour}{start_time.minute}{start_time.second}{start_time.microsecond}.txt"

        vulnerable_elements = set()
        cmd_tables = set()

        print(f"[GLOBALATTACKSURFACE] Will be saved in {filename}")
        with open(filename, "w") as txt_file:
            sorted_corpus = sorted(self.success_inputs, key = lambda x: (x.detection_order, self.get_detected_time(x)))

            txt_file.write(f"FORMAT:\n")
            txt_file.write(f"[Number]. [Role] [Reason]: [Mutator] [Detected Time] | [Mutated Param Names] | [Mutated Param Values] | [Method] | [Full URL] | [Body] | [Referer] | [Button Triggering the Req] | [ID] --> [SQL Queries]\n")

            verification_proof_num = 0
            is_verification_proof = False
            skipped_detection_order = 0
            vul_element = None
            for index, inp in enumerate(sorted_corpus):
                mutated_params = [pv.param for pv in inp.mutated_paramvals]
                try:
                    if inp.attack_surface_ID and isinstance(inp.attack_surface_ID, str) and len(inp.attack_surface_ID)>2:
                        vul_element = str(inp.request.url) + f" [{inp.attack_surface_ID[-2:]}] ||  " + ", ".join(mutated_params)
                    else:
                        vul_element = inp.request.url + "  ||  " + ", ".join(mutated_params)
                except Exception as e:
                    print(f"[GLOBALATTACKSURFACE] Error in getting vul_element: {e}")

                cmd_table = self.get_command_and_table_name(inp.vul_oracles)
                if inp.is_verification_proof:
                    if  verification_proof_num>=10 or inp.detection_order == skipped_detection_order:
                        continue
                    else:
                        verification_proof_num += 1
                        txt_file.write("**")
                        is_verification_proof = True
                elif vul_element in vulnerable_elements:
                    skipped_detection_order = inp.detection_order
                    continue
                elif cmd_table in cmd_tables:
                    skipped_detection_order = inp.detection_order
                    continue
                elif sorted_corpus[index+1] and not self.is_same_table_names(inp.vul_oracles, sorted_corpus[index+1].vul_oracles):
                    skipped_detection_order = inp.detection_order
                    continue
                else:
                    vulnerable_elements.add(vul_element)
                    cmd_tables.add(cmd_table)
                    txt_file.write("\n---\n")
                    verification_proof_num = 0

                if inp.detected_time:
                    d,h,m,s = self.time_diff(inp.detected_time, start_time)
                else:
                    h = 0
                    m = 0
                    s = 0

                # msg = inp.vul_oracle
                msg = str(inp.vul_oracles)
                if msg=="":
                    msg = str(inp.response_title).strip()
                    msg = msg.replace("\n", " ")

                if is_verification_proof:
                    is_verification_proof = False
                else:
                    i += 1
                    txt_file.write(f"{i}. ")
                txt_file.write(f"[{inp.sent_role}] {inp.reason_to_add}: {inp.request.source} [{h}:{m}:{s}] | {mutated_params} | {[pv.value for pv in inp.mutated_paramvals]} | {inp.request.method} | {inp.request.full_url} | {inp.request.post_data_encoded} | Ref: {inp.request.referer} | {inp.request.trigger if inp.request.trigger else None} | {inp.request.id} --> \n{msg}\n")


            txt_file.write(f"\n\nLINE COVERAGE: {len(config.line_coverage)}")

            txt_file.write(f"\n\nQUICK RECAP: VULNERABLE URLs = {len(vulnerable_elements)}")
            str_vulnerable_elements = "\n".join(sorted(vulnerable_elements))
            txt_file.write(f"\n\n{str_vulnerable_elements}")
            txt_file.write(f"\n\nAverage Processing time: {self.processing_time}")
            txt_file.write(f"\n\nResponse Code Collection: {self.response_codes}")
            txt_file.write(f"\n\nProportion: {self.get_response_code_proportion()}")

            if is_finish:
                txt_file.write(f"\nChecking Finish")

global_attack_surfaces = GlobalAttackSurfaces()
