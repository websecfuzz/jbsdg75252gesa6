import os
import random
from urllib.parse import unquote

import yaml

from config import config

class Dictionary:
    def __init__(self):
        self.data = list()
        self.num_ref_param = 0


    def add(self, paramval, source=None):
        try:
            if not isinstance(paramval.value, list):
                paramval.value = unquote(str(paramval.value))
        except Exception as e:
            print("[DICTIONARY] Failed to unquote:", paramval.value, e)

        if self.is_existing_paramval(paramval):
            return False

        self.data.append(paramval)

        if paramval.is_reference:
            self.num_ref_param += 1

        return True

    def is_existing_paramval(self, pv):
        for pv2 in self.data:
            if pv.param == pv2.param and pv.value == pv2.value and pv.role == pv2.role:
                return True
        return False

    def search_field_values(self, field_name, role=None):
        values = set()
        for paramval in self.data:
            if paramval.param == field_name:
                if role:
                    if paramval.role == role:
                        values.add(str(paramval.value))
                else:
                    values.add(str(paramval.value))
        return list(values)

    def get_random_paramval(self, role=None):
        if len(self.data)>0:
            idx = random.randint(0,len(self.data)-1)
            return self.data[idx]
        else:
            return None


    def get_complement_id_ref_values(self, paramname, avoided_role):
        """
        Try to get ID ref values beside those in paramname
        :param paramname:
        :param avoided_role:
        :return:
        """
        avoided_values = set()
        for pv in self.data:
            if pv.is_reference and pv.is_id and pv.role == avoided_role and pv.param == paramname:
                avoided_values.add(str(pv.value))

        complement_values = set()
        for pv in self.data:
            if pv.role == avoided_role or pv.param == paramname:
                continue
            if pv.is_reference and not pv.is_nested() and pv.is_id:
                complement_values.add(str(pv.value))

        if len(complement_values)>0:
            if avoided_values and len(avoided_values)>0:
                return list(complement_values - avoided_values)
            else:
                return list(complement_values)
        else:
            return list()

    def get_complement_non_id_values(self, paramname, avoided_role):
        """
        Try to find values beside those in paramname
        :param paramname:
        :param avoided_role:
        :return:
        """
        avoided_values = set()
        for pv in self.data:
            if pv.role == avoided_role and pv.param == paramname:
                avoided_values.add(str(pv.value))

        complement_values = set()
        for pv in self.data:
            if pv.role == avoided_role or pv.param == paramname:
                continue
            if pv.param and (pv.param.find("id")==0 or pv.param.find("id")==len(pv.param)-2):
                continue
            if pv.is_reference and not pv.is_nested():
                complement_values.add(str(pv.value))

        if len(complement_values)>0:
            if avoided_values and len(avoided_values)>0:
                return list(complement_values - avoided_values)
            else:
                return list(complement_values)
        else:
            return list()

    def get_role_values(self, role, param_name=None):
        values = set()
        for pv in self.data:
            if param_name:
                if pv.role == role and pv.param == param_name:
                    values.add(str(pv.value))
            else:
                if pv.role == role:
                    values.add(str(pv.value))

        return list(values)

    def get_complement_values(self, avoided_role, param_name=None):
        avoided_values = set()
        for pv in self.data:
            if pv.role == avoided_role and pv.param == param_name:
                avoided_values.add(str(pv.value))

        complement_values = set()
        for pv in self.data:
            if pv.role == avoided_role:
                continue

            if pv.param == param_name:
                complement_values.add(str(pv.value))

        if len(complement_values)>0:
            if avoided_values and len(avoided_values)>0:
                return list(complement_values - avoided_values)
            else:
                return list(complement_values)
        else:
            return list()

    def get_value(self, param_name, role):
        values = set()
        for pv in self.data:
            if pv.role == role and pv.param == param_name:
                values.add(str(pv.value))

        value_list = list(values)
        if len(value_list)>0:
            idx = random.randint(0,len(value_list)-1)
            return value_list[idx]
        return None


    def get_random_reference_paramval(self,only_numeric=False,avoided_role=None,avoid_nested=False,avoided_paramnames=None):
        max_iteration = 10
        n = 0

        if len(self.data)>0:
            while True and n<max_iteration:
                n += 1
                idx = random.randint(0,len(self.data)-1)
                if self.data[idx].is_reference:
                    print(f"[Dictionary] Got a reference param: {self.data[idx]}")
                    if only_numeric and not self.data[idx].is_id:
                        continue
                    if avoided_role and self.data[idx].role==avoided_role:
                        continue
                    if avoid_nested and self.data[idx].is_nested():
                        continue
                    if avoided_paramnames and self.data[idx].param in avoided_paramnames:
                        continue

                    return self.data[idx]
                else:
                    print(f"[Dictionary] {self.data[idx]} is not a reference param. Drop it.")

        return None

    def get_random_system_generated_paramval(self,only_numeric=False,avoided_role=None,avoid_nested=False,avoided_paramnames=None):
        max_iteration = 10
        n = 0

        if len(self.data)>0:
            while True and n<max_iteration:
                n += 1
                idx = random.randint(0,len(self.data)-1)
                if self.data[idx].is_system_param:
                    if only_numeric and not self.data[idx].is_id:
                        continue
                    if avoided_role and self.data[idx].role==avoided_role:
                        continue
                    if avoid_nested and self.data[idx].is_nested():
                        continue
                    if avoided_paramnames and self.data[idx].param in avoided_paramnames:
                        continue

                    return self.data[idx]
                else:
                    print(f"[Dictionary] {self.data[idx]} is not a system param. Drop it.")

        return None

    def get_random_user_generated_paramval(self, avoid_param_names=None):
        n = 0
        if len(self.data)>0:
            while True:
                n +=1
                if n>50:
                    return None

                idx = random.randint(0,len(self.data)-1)
                if self.data[idx].is_system_param:
                    print(f"[Dictionary] {self.data[idx]} is not a user param. Drop it.")
                else:
                    if avoid_param_names:
                        if self.data[idx].param in avoid_param_names:
                            continue
                    return self.data[idx]
        else:
            return None

    def created_sorted_paramvals(self):
        paramvals = dict()

        for paramval in self.data:
            source = paramval.role
            try:
                if source in paramvals:
                    if paramval.param in paramvals[source]:
                        paramvals[source][paramval.param].add(str(paramval.value))
                    else:
                        paramvals[source][paramval.param] = set()
                        paramvals[source][paramval.param].add(str(paramval.value))
                else:
                    paramvals[source] = dict()
                    paramvals[source][paramval.param] = set()
                    paramvals[source][paramval.param].add(str(paramval.value))

            except Exception as e:
                print(f"[DICTIONARY] Failed to add Paramvals:",e)

        return paramvals

    def save_captured_paramvals(self, start_time):

        foldername = "default"
        if "PROJECT_NAME" in config.data:
            foldername = config.data["PROJECT_NAME"]
        dir_location = os.path.join(os.getcwd(), '../attack_surface', foldername)
        if not os.path.exists(dir_location):
            os.makedirs(dir_location, exist_ok=True)
        print(f"[DICTIONARY] Storing paramvals YAML to {dir_location}")
        with open(f"{dir_location}/paramval.yaml", "w") as txt_file:
            txt_file.write(yaml.dump(self.data))

    def load_captured_paramvals(self):
        foldername = "default"
        if "PROJECT_NAME" in config.data:
            foldername = config.data["PROJECT_NAME"]
        dir_location = os.path.join(os.getcwd(), '../attack_surface', foldername)

        with open(f"{dir_location}/paramval.yaml", encoding="utf-8_sig") as f:
            self.data = yaml.load(f, Loader=yaml.Loader)
        print("[DICTIONARY] load_captured_paramvals from",dir_location)

dictionary = Dictionary()
