import traceback
from datetime import datetime
import os
import random
import json
import re

import HTTPRequest
from typing import List, Iterable

from Input import Input, VerificationLabel
from function import is_CRUD, is_contain_words, fix_prepared_query, fix_named_prepared_query
from utils import fuzz_open
from config import config


class AttackSurface:
    def __init__(self, target: HTTPRequest):
        self.id = target.id
        self.target: HTTPRequest = target
        self.hit_path_set = set()
        ## Check the potential to drop this coverage variable to save more memory
        self.corpus: List[Input] = list()
        self.no_new_path_count = 0
        self.roles = list()
        self.checked_role = None

    def __eq__(self, other):
        if not isinstance(other, AttackSurface):
            # don't attempt to compare against unrelated types
            return NotImplemented

        return self.target == other.target

    def __str__(self):
        return f"{self.id} --> {self.target}"

    def get_num_sysgen_param(self):
        return self.target.num_sysgen

    def get_num_idsysgen_param(self):
        num = self.target.get_num_sysgen(doubling_numeric=True)
        if num==0:
            return 0.01
        return num

    def get_num_reference_param(self):
        num = self.target.get_num_ref_param()
        if num==0:
            return 0.01
        return num


    def getRequest(self):
        if len(self.corpus)>0:
            input = random.choice(self.corpus)
            return input.request
        else:
            input = Input(self.target, None, "Init")
            self.corpus.append(input)
            return self.target

    def getAllRequests(self, maxNumber=0):
        if maxNumber!=0 and len(self.corpus)>maxNumber:

            chosen_requests = random.choices(self.corpus,k=maxNumber)
            return [inp.request for inp in chosen_requests], [inp.response_title for inp in chosen_requests]
        elif len(self.corpus)>0:
            return [inp.request for inp in self.corpus], [inp.response_title for inp in self.corpus]
        else:
            return [self.target], []

    def is_containing_vulnerability(self, res):
        pass

    def is_login_page(self, res):
        if res:
            for key in config.data["LOGIN_PAGE_PHRASES"]:
                if res.find(key)>-1:
                    return True
            return False

    def is_restricted_page(self, res):
        if res:
            for key in config.data["UNAUTHORIZED_PAGE_PHRASES"]:
                if res.find(key)>-1:
                    return True
        return False

    def is_null(self, res):
        if res is None or res==0 or res=="" or res=="\n0":
            return True
        return False

    def is_empty(self, mutated_values):
        try:
            if mutated_values==None:
                print("[ATTACKSURFACE] None mutated values: ", mutated_values)
                return True

            if len(mutated_values)==0:
                print("[ATTACKSURFACE] Empty mutated values: ", mutated_values)
                return True

            if mutated_values[0]=="":
                print("[ATTACKSURFACE] Empty first element mutated values: ", mutated_values)
                return True
        except Exception as e:
            print("[ATTACKSURFACE] ", e)
            return True

        return False

    def is_mutated_values_exist_in_refpage(self, mutated_values, input: Input):
        if len(input.ids_from_refpage)>0:
            for val in mutated_values:
                if val in input.ids_from_refpage:
                    print(f"[ATTACKTARGET {self.checked_role}] Value of {val} is found in the ref page. BOLA or BOPLA checking is cancelled.")
                    print(f"[ATTACKTARGET {self.checked_role}] Full ref params: {input.params_from_refpage}")
                    print(f"[ATTACKTARGET {self.checked_role}] Full ref values: {input.ids_from_refpage}")
                    return True
        return False

    def is_BOLA(self, sql_error, input: Input):
        """
        When the where clause in UPDATE or DELETE query contain arbitrary object reference, it is BOLA
        :return:
        """

        if input.testname == "vertical":
            print(f"[ATTACKTARGET {self.checked_role}] Skip Checking BOLA because it is a vertical test")
            return False

        BOLA_proof = list()
        mutated_paramvals = input.request.get_changed_params()
        system_gen_values = [p.value for p in mutated_paramvals]
        input.mutated_paramvals = mutated_paramvals

        if len(system_gen_values)==0:
            print(f"[ATTACKTARGET {self.checked_role}] Skip Checking BOLA because NO mutated_paramvals")
            return False

        if self.is_mutated_values_exist_in_refpage(system_gen_values,input):
            return False

        print(f"[ATTACKTARGET {self.checked_role}] Checking BOLA")

        for query_str in sql_error:
            where_pos = str(query_str).lower().find("where")
            if where_pos>0:
                if self.is_containing_certain_values(query_str[where_pos+6:],system_gen_values,must_be_all=True):
                    BOLA_proof.append(query_str)

        if len(BOLA_proof)>0:
            print(f"[ATTACKTARGET {self.checked_role}] Test name: {input.testname}")
            input.detected_time = datetime.now()
            input.reason_to_add = f"BOLA"
            print(f"[ATTACKTARGET {self.checked_role}] BOLA is detected! -->", str(BOLA_proof)[:600], " <-- ", input.request)
            print(f"[ATTACKTARGET {self.checked_role}] Detected mutated params: {input.mutated_paramvals}")
            input.vul_oracles.extend(BOLA_proof)
            input.mutated_values = system_gen_values
            input.label=VerificationLabel.OBJECT_BROKEN
            for p in mutated_paramvals:
                p.BAC_label=VerificationLabel.OBJECT_BROKEN
            return True
        return False

    def is_BOPLA(self, sql_error, input: Input):
        """
        When the values of the additional params appear in the body query
        and the object reference value appear in the Where clause, it is BOPLA
        :return:
        """
        BOPLA_proof = list()
        added_property_paramvals = input.request.get_added_property_paramvals(set_to_false=True)
        added_property_values = [p.value for p in added_property_paramvals]
        input.mutated_paramvals = added_property_paramvals

        if len(added_property_values)==0:
            print(f"[ATTACKTARGET {self.checked_role}] Skip Checking BOPLA because NO added_property_paramvals")
            return False

        if self.is_mutated_values_exist_in_refpage(added_property_values,input):
            return False

        print(f"[ATTACKTARGET {self.checked_role}] Checking BOPLA")

        for query_str in sql_error:
            where_pos = str(query_str).lower().find("where")
            if where_pos>0:
                if self.is_containing_certain_values(query_str[:where_pos],added_property_values,must_be_all=False):
                    BOPLA_proof.append(query_str)
            elif (str(query_str).lower().find("insert")>-1):
                if self.is_containing_certain_values(query_str,added_property_values,must_be_all=False):
                    BOPLA_proof.append(query_str)

        if len(BOPLA_proof)>0:
            print(f"[ATTACKTARGET {self.checked_role}] Test name: {input.testname}")
            input.detected_time = datetime.now()
            input.reason_to_add = f"BOPLA"
            print(f"[ATTACKTARGET {self.checked_role}] BOPLA is detected! -->", str(BOPLA_proof)[:600], " <-- ", input.request)
            print(f"[ATTACKTARGET {self.checked_role}] Detected mutated params: {[pv.param for pv in input.mutated_paramvals]} Mutated values: {[pv.value for pv in input.mutated_paramvals]}")
            # input.vul_oracle += str(BOPLA_proof)
            input.vul_oracles.extend(BOPLA_proof)
            input.mutated_values = added_property_values
            input.label=VerificationLabel.PROPERTY_BROKEN
            for p in added_property_paramvals:
                p.BAC_label=VerificationLabel.PROPERTY_BROKEN
            return True
        return False

    def is_BFLA(self, sql_error, input: Input):
        """
        When the query involving non-log tables is executed.
        :return:
        """
        if input.testname!="vertical" and input.testname!="validate_BAC":
            return False

        print(f"[ATTACKTARGET {self.checked_role}] Checking BFLA")

        BFLA_proof = list()
        atomic_paramvals = input.request.get_all_atomic_param_vals()
        atomic_values = [p.value for p in atomic_paramvals]
        print(f"[ATTACKTARGET {self.checked_role}] Getting {atomic_values} atomic values")

        unique_paramvals = list()
        if len(input.ids_from_refpage)>0:
            for pv in atomic_paramvals:
                if pv.value not in input.ids_from_refpage:
                    print(f"[ATTACKTARGET {self.checked_role}] Value of {pv.value} is NOT FOUND in the ref page.")
                    unique_paramvals.append(pv)

            if len(unique_paramvals)>0:
                input.mutated_values = [p.value for p in unique_paramvals]
                input.mutated_paramvals = unique_paramvals
            else:
                print(f"[ATTACKTARGET {self.checked_role}] All params are found in the page, meaning those are indeed allowed. So, it not BFLA.")
                return False
        else:
            unique_paramvals = atomic_paramvals

        all_matched_paramvals = list()
        for query_str in sql_error:
            where_pos = str(query_str).lower().find("where")
            if where_pos>0:
                ## ONLY CHECK THE WHERE CLAUSE FOR THE UDATE AND DELETE QUERY
                matched_paramvals = self.get_matched_values(query_str[where_pos+6:],unique_paramvals)
            else:
                ## FOR THE INSERT QUERY, WE CHECK THE ENTIRE QUERY
                matched_paramvals = self.get_matched_values(query_str,unique_paramvals)

            if len(matched_paramvals)>0:
                BFLA_proof.append(query_str)
                all_matched_paramvals.extend(x for x in matched_paramvals if x not in all_matched_paramvals)

        if len(BFLA_proof)>0:
            print(f"[ATTACKTARGET {self.checked_role}] Test name: {input.testname} because the request is collected by using",self.roles)
            input.label=VerificationLabel.FUNCTIONAL_BROKEN
            input.detected_time = datetime.now()
            input.reason_to_add = f"BFLA"
            print(f"[ATTACKTARGET {self.checked_role}] BFLA is detected! -->", str(BFLA_proof)[:600], " <-- ", input.request)
            print(f"[ATTACKTARGET {self.checked_role}] Detected matched_paramvals: {all_matched_paramvals}")
            input.vul_oracles.extend(BFLA_proof)
            for p in all_matched_paramvals:
                p.BAC_label=VerificationLabel.FUNCTIONAL_BROKEN
            input.mutated_values = [p.value for p in all_matched_paramvals]
            input.mutated_paramvals = all_matched_paramvals
            return True
        return False

    def get_matched_values(self, queries_str, mutated_paramvals):
        matched_paramvals = list()
        if len(mutated_paramvals)==0:
            print(f"[ATTACKTARGET] Skip the check because the mutated values is NULL")
            return matched_paramvals

        try:
            if isinstance(queries_str, Iterable):
                queries = queries_str.replace('=', ' ')
                for par in queries.split():
                    if par=="" or par==" ":
                        continue
                    param = re.sub(r'\W+', '', par) # to escape weird characters like '
                    if param=="" or param==" ":
                        continue

                    for pv in mutated_paramvals:
                        if pv.value=="" or pv.value==" ":
                            continue

                        val = re.sub(r'\W+', '', pv.value) # to escape weird characters like '

                        if param==val:
                            print(f"[ATTACKTARGET] Finding query: {param} is the same with mutated values: {pv.value}")
                            matched_paramvals.append(pv)
        except Exception as e:
            print(f"[ATTACKTARGET] Error in get_matched_values: {e}")

        return matched_paramvals

    def is_containing_certain_values(self, queries, values, must_be_all=True):
        if self.is_empty(values):
            print(f"[ATTACKTARGET] Skip the check because the mutated values in NULL: ", values)
            return False

        found = 0

        mutated_values = list()
        for value in values:
            val = re.sub(r'\W+', '', str(value))
            mutated_values.append(val)

        print(f"[ATTACKTARGET] Checking values: {mutated_values} in SQL Query: [{queries}]")

        queries = queries.replace('(', ' ')
        queries = queries.replace(')', ' ')

        if isinstance(queries, Iterable):
            for par in queries.split():
                if par=="" or par==" ":
                    continue
                param = re.sub(r'\W+', '', par) # to escape weird characters like '
                if param=="" or param==" ":
                    continue

                if param in mutated_values:
                    print(f"[ATTACKTARGET] Finding query: {param} is the same with mutated values: {mutated_values}")
                    found += 1

        if found==0:
            return False
        elif not must_be_all:
            return True
        elif must_be_all and found==len(mutated_values):
            return True

        return False


    def is_delete_query_or_containing_unique_str(self, params):
        if isinstance(params, Iterable):
            for par in params:
                param = par.lower()
                if param.find("drop")>-1:
                    return True
                elif param.find("delete")>-1:
                    return True
                elif param.find(config.data["UNIQUE_STRING"])>-1:
                    return True
            return False

    def is_error_recorded(self, input: Input):
        mysql_error_file_path = (
            f"{config.data['MYSQL_PATHS']}/{input.request.id}.json"
        )
        print(f"[ATTACKTARGET {self.checked_role}] Checking MYSQL error from ", mysql_error_file_path[-50:])
        if not os.path.exists(mysql_error_file_path):
            print(f"[ATTACKTARGET {self.checked_role}] No error reported")
            return False

        error_report = list()
        sql_error = list()

        ## Collecting the query string
        query_str = ""
        query_statement = ""
        for line in fuzz_open(mysql_error_file_path,"r", isCompress=True):
            if not line.strip():
                continue
            error = json.loads(line)
            error_report.append(error)
            if error['errno'] == -9999:
                if 'params' in error and len(error['params'])>0:
                    if is_contain_words(error['params'][0], desired_words=config.data["IGNORING_SQL"]):
                        print(f"[ATTACKTARGET {self.checked_role}] Skipping query:", error['params'],"because it is pre-defined ignored query")
                        continue
                    else:
                        ## We assume a WUT uses prepared statemets that make query statement separated, like: delete from tblnotes where ID=:rid; 1;
                        if is_contain_words(error['params'][0], desired_words=["INSERT INTO","UPDATE ","DELETE FROM"]):
                            if query_statement != "":
                                ## Check if the query is a prepared statement
                                if query_statement.find("?")>-1:
                                    try:
                                        query_statement = fix_prepared_query(query_statement)
                                    except Exception as e:
                                        print(f"[ATTACKSURFACE {self.checked_role}] Error in fix_prepared_query: {e}")
                                        print(f"[ATTACKSURFACE {self.checked_role}] {traceback.format_exc()[-1000:]}")
                                elif query_statement.find("=>")>-1:
                                    try:
                                        query_statement = fix_named_prepared_query(query_statement)
                                    except Exception as e:
                                        print(f"[ATTACKSURFACE {self.checked_role}] Error in fix_named_query: {e}")
                                        print(f"[ATTACKSURFACE {self.checked_role}] {traceback.format_exc()[-1000:]}")
                                sql_error.append(query_statement)

                            ## This is the start of the query statement
                            query_statement = error['params'][0]
                        else:
                            ## We assume this part is the part of the previous query statement
                            query_statement = query_statement + " | " + str(error['params'][0])

                        query_str += f"{error['params'][0]}; "
                else:
                    print(f"[ATTACKTARGET {self.checked_role}] Skipping query because it is NULL")
                    continue
        ## END
        if query_statement != "":
            if query_statement.find("?")>-1:
                try:
                    query_statement = fix_prepared_query(query_statement)
                except Exception as e:
                    print(f"[ATTACKSURFACE {self.checked_role}] Error in fix_prepared_query: {e}")
                    print(f"[ATTACKSURFACE {self.checked_role}] {traceback.format_exc()[-1000:]}")
            elif query_statement.find("=>")>-1:
                try:
                    query_statement = fix_named_prepared_query(query_statement)
                except Exception as e:
                    print(f"[ATTACKSURFACE {self.checked_role}] Error in fix_named_query: {e}")
                    print(f"[ATTACKSURFACE {self.checked_role}] {traceback.format_exc()[-1000:]}")
            sql_error.append(query_statement)

        input.error_report = sql_error
        if self.is_BOLA(sql_error,input) or self.is_BFLA(sql_error,input) or self.is_BOPLA(sql_error,input):
            print(f"[ATTACKTARGET {self.checked_role}] Detecting BOLA or BOPLA or BFLA!")
            return True
        elif len(sql_error)>0:
            input.label = VerificationLabel.OTHER_MYSQL_ERROR
            print(f"[ATTACKTARGET {self.checked_role}] Just find usual SQL query: {query_str}")
            return False
        else:
            print(f"[ATTACKTARGET {self.checked_role}] No SQL error is found")
            return False



    def analyse(self, input: Input, response_str):
        self.checked_role = input.sent_role
        if isinstance(input.hit_path_set, set):
            new_paths = input.hit_path_set.difference(self.hit_path_set)
            number_of_new_paths = len(new_paths)
        else:
            new_paths = -1
            number_of_new_paths = 0

        if response_str and response_str.find("Invalid nonce")>-1:
            print(f"[ATTACKTARGET {self.checked_role}] Set need_to_update_nonce TRUE because getting a message: ", response_str)
            self.target.need_to_update_nonce = True
            input.request.need_to_update_nonce = True

        if self.is_error_recorded(input):
            print(f"[ATTACKTARGET {self.checked_role}] Request {input.request} managed to trigger error")
            self.corpus.append(input)
            if (number_of_new_paths>0):
                print(f"[ATTACKTARGET {self.checked_role}] New paths found:", number_of_new_paths)
                self.hit_path_set = self.hit_path_set | input.hit_path_set
        elif input.response and input.response.status==500:
            print(f"[ATTACKTARGET {self.checked_role}] The web server is error. Must be analysed! :", input.request.id)
            input.reason_to_add = f"The web server is error. Must be analysed!"
            input.label=VerificationLabel.ERROR
            input.detected_time = datetime.now()
            if input not in self.corpus:
                self.corpus.append(input)
        elif self.is_restricted_page(response_str) or self.is_login_page(response_str):
            print(f"[ATTACKTARGET {self.checked_role}] The response is restricted or login page")
            if (number_of_new_paths>0):
                print(f"f[ATTACKTARGET {self.checked_role}] New paths are found:", number_of_new_paths)
                input.reason_to_add = f"New paths are found: {number_of_new_paths}"
                self.corpus.append(input)
                self.hit_path_set = self.hit_path_set | input.hit_path_set
            else:
                print(f"[ATTACKTARGET {self.checked_role}] NO New paths, drop the request")
                self.no_new_path_count +=1
        elif self.is_null(response_str) or input.response.ok:
            print(f"[ATTACKTARGET {self.checked_role}] The response is not a restricted page nor login page. Must be analysed! :", input.request.id)
            input.reason_to_add = f"The response is not a restricted page nor login page. Must be analysed!"
            input.label=VerificationLabel.EXPLOITABLE
            if (number_of_new_paths>0):
                self.corpus.append(input)
                print(f"[ATTACKTARGET {self.checked_role}] New paths found:", number_of_new_paths)
                self.hit_path_set = self.hit_path_set | input.hit_path_set
        else:
            print(f"[ATTACKTARGET {self.checked_role}] The response code is not interesting: ",input.response.status)

        input.ids_from_refpage = None ## to save more memory
        input.params_from_refpage = None ## to save more memory
        return new_paths

    def delete_files(self, input):
        coverage_file_path = (
            f"{config.data['COV_PATHS']}/{input.request.id}.json"
        )

        mysql_error_file_path = (
            f"{config.data['MYSQL_PATHS']}/{input.request.id}.json"
        )

        print(f"[ATTACKTARGET {self.checked_role}] Deleting the file {coverage_file_path} after getting the coverage")
        try:
            os.system(f"rm {coverage_file_path}")
            print(f"[ATTACKTARGET {self.checked_role}] Deleting the file {mysql_error_file_path} after getting the SQL Report")
            os.system(f"rm {mysql_error_file_path}")
        except Exception as e:
            print(f"[ATTACKSURFACE {self.checked_role}] Error in delete_files: {input.request.id}")
            print(f"[ATTACKSURFACE {self.checked_role}] {e}")
            print(f"[ATTACKSURFACE {self.checked_role}] {traceback.format_exc()[:1000]}")