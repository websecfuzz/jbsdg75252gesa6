import base64
import json
import logging
import re
import time
import traceback
import urllib
from enum import Enum
from uuid import uuid4
from urllib.parse import unquote

import yaml
from playwright.sync_api import Request, APIResponse
from typing import List, Dict
from urllib.parse import urlencode, urlparse

from requests_toolbelt import MultipartEncoder
from requests_toolbelt.multipart import decoder

from function import split_key_val, parse_post_data
from Dictionary import dictionary
from config import config
from VerificationLabel import VerificationLabel
from param_value import ParamValue, ParamValuePosition
from datetime import datetime
from zoneinfo import ZoneInfo

# logger = logging.getLogger(__name__)
logger = config.logger

class RequestStatus (Enum):
    UNDEFINED = 0

class HTTPRequest:
    def __init__(self):
        self.id = str(int(time.time())) + "-" + str(uuid4())
        self.full_url = None
        self.url = None
        self.base_url = None
        self.found_value = None
        self.keys = list()
        self.method = None
        self.header = None
        self.param_encoded = None
        self.post_data_json = None
        self.post_data_encoded = None
        self.content_type = None
        self.source = None
        self.paramvals_without_nonce = list()
        self.paramvals = list()
        self.num_sysgen = 0
        self.role = None
        self.saved_filename = None
        self.need_to_update_nonce = True
        self.referer = None
        self.split_char = '&'
        self.is_HTML_form = False
        
        self.timing = None
        self.id_ori_request = None
        self.response_code = None
        self.SQL_detected = None
        self.error_SQL_detected = None

        self.reference_params = None
        self.trigger = None

        self.body_param_dict = None

    def update_id(self):
        self.id = str(int(time.time())) + "-" + str(uuid4())

    def update_certain_paramval(self, param, new_value):
        for p in self.paramvals:
            if p.param == param:
                print(f"[HTTPREQUEST {self.role}] Update ", p, "with new value: ",new_value)
                p.value = new_value

            if p.is_nested():
                for p2 in p.paramvals:
                    if p2.param == param:
                        p2.value = new_value
                        print(f"[HTTPREQUEST {self.role}] Update ", p2, "with new value: ",new_value)

    def get_null_paramvals(self):
        paramvals = list()
        for pv in self.paramvals:
            if pv.value==None or pv.value=="":
                paramvals.append(pv)
        return paramvals

    def update_param_from_paramvals(self, add_paramvals=None, is_drop_previous_paramvals=True):
        """
        :param add_paramvals: a list of paramval-typed objects and you must ensure that the objects do not exist in the self paramvals
        :param is_drop_previous_paramvals:
        :return:
        """

        logger.info(f"[HTTPREQUEST {self.role}] Update url and body param from paramvals:")

        if add_paramvals:
            if is_drop_previous_paramvals:
                self.paramvals = add_paramvals
            else:
                self.paramvals += add_paramvals
        paramvals = self.paramvals

        body_param_dict = {}
        url_param_dict = {}
        path_list = list()

        sorted_paramvals = sorted(paramvals, key=lambda p: p.param)
        for paramval in sorted_paramvals:
            if paramval.position==ParamValuePosition.URL:
                if paramval.is_nested():
                    nested_param_dict = {}
                    for p in paramval.paramvals:
                        nested_param_dict[p.param] = p.value
                    nested_param_encoded = urllib.parse.urlencode(nested_param_dict, quote_via=urllib.parse.quote_plus)

                    url_param_dict[paramval.param] = nested_param_encoded
                    paramval.value = nested_param_encoded
                else:
                    url_param_dict[paramval.param] = paramval.value
            elif paramval.position==ParamValuePosition.BODY:
                if paramval.is_nested():
                    nested_param_dict = {}
                    for p in paramval.paramvals:
                        nested_param_dict[p.param] = p.value
                    nested_param_encoded = urllib.parse.urlencode(nested_param_dict, quote_via=urllib.parse.quote_plus)

                    body_param_dict[paramval.param] = nested_param_encoded
                    paramval.value = nested_param_encoded
                else:
                    if paramval.param==None or paramval.param=="None":
                        logger.info(f"[HTTPREQUEST {self.role}] Skip None Paramval to be included")
                    else:
                        body_param_dict[paramval.param] = paramval.value

            elif paramval.position==ParamValuePosition.PATH:
                path_list.append(paramval.value)

        self.body_param_dict = body_param_dict
        self.param_encoded = urllib.parse.urlencode(url_param_dict, quote_via=urllib.parse.quote_plus)
        if self.split_char!='&':
            self.param_encoded = self.param_encoded.replace('&',self.split_char)

        if self.content_type and self.content_type.find("application/json")>-1:
            self.post_data_encoded = json.dumps(body_param_dict)
        else:
            self.post_data_encoded = urllib.parse.urlencode(body_param_dict, quote_via=urllib.parse.quote_plus)

        if len(path_list) > 0:
            new_paths = "/" + "/".join(path_list)
            self.url = self.base_url+new_paths
            logger.info(f"[HTTPREQUEST {self.role}] New path: {new_paths}")

        logger.info(f"[HTTPREQUEST {self.role}] New post_data_encoded: %s",self.post_data_encoded)
        logger.info(f"[HTTPREQUEST {self.role}] New param encoded: %s",self.param_encoded)


    def init_data(self, *initial_data, **kwargs):
        for dictionary in initial_data:
            for key in dictionary:
                setattr(self, key, dictionary[key])
        for key in kwargs:
            setattr(self, key, kwargs[key])

    def __eq__(self, other):
        if not isinstance(other, HTTPRequest):
            # don't attempt to compare against unrelated types
            return NotImplemented


        if len(self.paramvals)>0 or len(other.paramvals)>0:
            return self.url == other.url and self.method == other.method and self.paramvals == other.paramvals

        return self.url == other.url and self.method == other.method and self.post_data_encoded == other.post_data_encoded

    def __str__(self):
        if len(self.paramvals)>0:
            return f"{self.method} | {self.url} | {[str(x) for x in self.paramvals]} | {self.referer}"
        return f"{self.method} | {self.url} {self.param_encoded} | {self.content_type} | {self.post_data_encoded} | {self.referer}"


    def get_changed_values(self):
        print(f"[HTTPREQUEST {self.role}] Getting mutated values")
        params = list()
        values = list()
        system_gen_values = list()
        for p in self.paramvals:
            if p.is_mutated:
                params.append(p.param)
                values.append(p.value)
                print(f"[HTTPREQUEST {self.role}] {p} is mutated")
                if p.is_reference:
                    system_gen_values.append(re.sub(r'\W+', '', p.value))
                    print(f"[HTTPREQUEST {self.role}] {p} is_reference")

            if p.is_nested():
                for p2 in p.paramvals:
                    if p2.is_mutated:
                        params.append(p2.param)
                        values.append(p2.value)
                        print(f"[HTTPREQUEST {self.role}] {p2} is mutated")
                        if p2.is_reference:
                            system_gen_values.append(re.sub(r'\W+', '', p2.value))
                            print(f"[HTTPREQUEST {self.role}] {p2} is_reference")

        return system_gen_values, values, params

    def get_changed_params(self):
        print(f"[HTTPREQUEST {self.role}] Getting mutated reference params")
        paramvals = list()
        for p in self.paramvals:
            if p.is_nested():
                for p2 in p.paramvals:
                    if p2.is_mutated:
                        if p2.is_reference:
                            paramvals.append(p2)
                            print(f"[HTTPREQUEST {self.role}] {p2} is mutated reference")
            elif p.is_mutated:
                if p.is_reference:
                    paramvals.append(p)
                    print(f"[HTTPREQUEST {self.role}] {p} is mutated reference")

        return paramvals

    def get_BAC_labelled_paramvals(self):
        paramvals = list()
        for p in self.paramvals:
            print(f"[HTTPREQUEST {self.role}] Checking BAC label in {p}")
            if isinstance(p, ParamValue):
                if p.is_nested():
                    for p2 in p.paramvals:
                        if isinstance(p2, ParamValue):
                            if p2.BAC_label==VerificationLabel.OBJECT_BROKEN or p2.BAC_label==VerificationLabel.PROPERTY_BROKEN or p2.BAC_label==VerificationLabel.FUNCTIONAL_BROKEN:
                                paramvals.append(p2)
                                print(f"[HTTPREQUEST {self.role}] {p2} is marked as {p2.BAC_label}")
                            if p2.BAC_label==VerificationLabel.PROPERTY_BROKEN:
                                p2.is_added_property = True
                elif p.BAC_label==VerificationLabel.OBJECT_BROKEN or p.BAC_label==VerificationLabel.PROPERTY_BROKEN or p.BAC_label==VerificationLabel.FUNCTIONAL_BROKEN:
                    paramvals.append(p)
                    print(f"[HTTPREQUEST {self.role}] {p} is marked as {p.BAC_label}")
                    if p.BAC_label==VerificationLabel.PROPERTY_BROKEN:
                        p.is_added_property = True
        return paramvals

    def get_added_property_values(self):
        print(f"[HTTPREQUEST {self.role}] Getting added_property_values")
        values = list()
        for p in self.paramvals:
            if p.is_added_property:
                values.append(p.value)
                print(f"[HTTPREQUEST {self.role}] {p} is added_property")

            if p.is_nested():
                for p2 in p.paramvals:
                    if p2.is_added_property:
                        values.append(p2.value)
                        print(f"[HTTPREQUEST {self.role}] {p2} is added_property")

        return values

    def get_added_property_paramvals(self, set_to_false=False):
        print(f"[HTTPREQUEST {self.role}] Getting added_property paramvals")
        paramvals = list()
        # values = list()
        for p in self.paramvals:
            if hasattr(p, 'is_added_property') and p.is_added_property:
                paramvals.append(p)
                print(f"[HTTPREQUEST {self.role}] {p} is added_property")
                if set_to_false:
                    p.is_added_property = False

            if p.is_nested():
                for p2 in p.paramvals:
                    if hasattr(p2, 'is_added_property') and p2.is_added_property:
                        paramvals.append(p2)
                        print(f"[HTTPREQUEST {self.role}] {p2} is added_property")
                        if set_to_false:
                            p2.is_added_property = False

        return paramvals

    def get_num_ref_param(self, doubling_numeric=False):
        count = 0
        for p in self.paramvals:
            if p.is_nested():
                for p2 in p.paramvals:
                    if doubling_numeric and p2.is_id:
                        count += 1

                    if p2.is_reference:
                        count += 1
            else:
                if doubling_numeric and p.is_id:
                    count += 1

                if p.is_reference:
                    count += 1
        return count

    def get_num_sysgen(self, doubling_numeric=False):
        count = 0
        for p in self.paramvals:
            if p.is_nested():
                for p2 in p.paramvals:
                    if doubling_numeric and p2.is_id:
                        count += 1

                    if p2.is_system_param:
                        count += 1
            else:
                if doubling_numeric and p.is_id:
                    count += 1

                if p.is_system_param:
                    count += 1

        return count

    def get_system_generated_param_vals(self, dropping_nonce=False, atomic_val_only=False, only_numeric=False):
        print(f"[HTTPREQUEST {self.role}] Get System Generated Param from: {self}")
        values = list()
        for p in self.paramvals:
            if dropping_nonce and p.is_nonce:
                print(f"[HTTPREQUEST {self.role}] {p} is nonce. Skip it.")
                continue

            if p.is_nested():
                for p2 in p.paramvals:
                    if dropping_nonce and p2.is_nonce:
                        print(f"[HTTPREQUEST {self.role}] {p2} is nonce. Skip it.")
                        continue
                    if atomic_val_only and p2.is_nested():
                        print(f"[HTTPREQUEST {self.role}] {p2} is nested and we do not take its whole value. Skip it.")
                        continue
                    if only_numeric and not p2.is_id:
                        print(f"[HTTPREQUEST {self.role}] {p2} is non-numeric and we do not take it. Skip it.")
                        continue

                    if p2.is_system_param:
                        values.append(p2)

            if atomic_val_only and p.is_nested():
                print(f"[HTTPREQUEST {self.role}] {p} is nested and we do not take its whole value. Skip it.")
                continue

            if only_numeric and not p.is_id:
                print(f"[HTTPREQUEST {self.role}] {p} is non-numeric and we do not take it. Skip it.")
                continue

            if p.is_system_param:
                values.append(p)

        return values

    def get_reference_param_vals(self, dropping_nonce=False, atomic_val_only=False, only_numeric=False):
        print(f"[HTTPREQUEST {self.role}] Get Reference Param from: {self}")
        values = list()
        for p in self.paramvals:
            if dropping_nonce and p.is_nonce:
                print(f"[HTTPREQUEST {self.role}] {p} is nonce. Skip it.")
                continue

            if p.is_nested():
                for p2 in p.paramvals:
                    if dropping_nonce and p2.is_nonce:
                        print(f"[HTTPREQUEST {self.role}] {p2} is nonce. Skip it.")
                        continue
                    if atomic_val_only and p2.is_nested():
                        print(f"[HTTPREQUEST {self.role}] {p2} is nested and we do not take its whole value. Skip it.")
                        continue
                    if only_numeric and not p2.is_id:
                        print(f"[HTTPREQUEST {self.role}] {p2} is non-numeric and we do not take it. Skip it.")
                        continue

                    if p2.is_reference:
                        values.append(p2)

            if atomic_val_only and p.is_nested():
                print(f"[HTTPREQUEST {self.role}] {p} is nested and we do not take its whole value. Skip it.")
                continue

            if only_numeric and not p.is_id:
                print(f"[HTTPREQUEST {self.role}] {p} is non-numeric and we do not take it. Skip it.")
                continue

            if p.is_reference:
                values.append(p)

        return values

    def get_all_atomic_param_vals(self, dropping_nonce=False, only_system_generated_param=False, only_user_param=False):
        print(f"[HTTPREQUEST {self.role}] Get All Atomic Param Values from: {self}")
        values = list()
        for p in self.paramvals:
            print(f"[HTTPREQUEST {self.role}] Checking {p}")

            if p.is_nested():
                for p2 in p.paramvals:
                    if dropping_nonce and p2.is_nonce:
                        print(f"[HTTPREQUEST {self.role}] Nested {p2} is nonce. Skip it.")
                        continue

                    if only_system_generated_param and p2.is_system_param and not p2.is_nested():
                        values.append(p2)
                        continue

                    if only_user_param and not p2.is_system_param and not p2.is_nested():
                        values.append(p2)
                        continue

                    if not only_system_generated_param and not only_user_param:
                        values.append(p2)
                        continue
            else:
                if dropping_nonce and p.is_nonce:
                    print(f"[HTTPREQUEST {self.role}] {p} is nonce. Skip it.")
                    continue

                if only_system_generated_param and p.is_system_param:
                    values.append(p)
                    continue

                if only_user_param and not p.is_system_param:
                    values.append(p)
                    continue

                if not only_system_generated_param and not only_user_param:
                    values.append(p)
                    continue

        return values

    def print_paramvals(self):
        for p in self.paramvals:
            print(f"[HTTPREQUEST {self.role}] {p.param} : {p.type} --> {p.value} [{p.is_system_param}]")
            if p.is_nested():
                for p2 in p.paramvals:
                    print(f"[HTTPREQUEST {self.role}] {p2.param} : {p.type} --> {p2.value} [{p2.is_system_param}]")

    def add_param_val(self, param, value, is_mutated, source):
        is_existed = False
        atomic_paramvals = self.get_all_atomic_param_vals()
        for pv in atomic_paramvals:
            if pv.param == param:
                pv.value = value
                pv.source = source
                pv.is_mutated = is_mutated
                print(f"[HTTPREQUEST {self.role}] Add the new value to existing paramval", pv)

                if dictionary.add(pv, source) == False:
                    return False
                is_existed = True

        if not is_existed:
            pv = ParamValue(param,value,ParamValuePosition.BODY)
            pv.role = self.role
            pv.source = source
            pv.is_mutated = is_mutated
            self.paramvals.append(pv)
            if dictionary.add(pv, source) == False:
                return False
            print(f"[HTTPREQUEST {self.role}] Add the new paramvalue to the request", pv)
        return True

    def extract_additional_param_value_from_post_encode(self,post_data_encoded, is_mutated, source):
        print(f"[HTTPREQUEST {self.role}] Extract additional param value from post encode:", post_data_encoded)

        if post_data_encoded:
            if post_data_encoded.find('&')>-1:
                for txt in post_data_encoded.split('&'):
                    key, val1 = split_key_val(txt)
                    if self.add_param_val(key,val1,is_mutated,source) == False:
                        return False
            else:
                key, val = split_key_val(post_data_encoded)
                if self.add_param_val(key,val,is_mutated,source) == False:
                    return False

            self.update_param_from_paramvals()
            self.source = source
        return True

    def extract_param_value_from_post_encode(self,is_mutated=False, source=None):
        self.paramvals = list()

        if self.post_data_encoded:
            if self.post_data_encoded.find('&')>-1:
                for txt in self.post_data_encoded.split('&'):
                    key, val1 = split_key_val(txt)
                    pv = ParamValue(key,val1,ParamValuePosition.BODY)
                    pv.role = self.role
                    if source:
                        pv.role = source
                    pv.is_mutated = is_mutated
                    self.paramvals.append(pv)
                    dictionary.add(pv)

                    if isinstance(val1,str):
                        value = val1
                        if value.find("%3D"):
                            value = unquote(val1)
                        ## There is a possibility that there is nested param values.
                        if value.find('=')>-1:
                            if value.find('&')>-1:
                                for txt in value.split('&'):
                                    key2, val = split_key_val(txt)
                                    pv1 = ParamValue(key2,val,ParamValuePosition.BODY)
                                    pv1.role = self.role
                                    if source:
                                        pv1.role = source
                                    pv1.is_mutated = is_mutated
                                    pv.paramvals.append(pv1)
                                    dictionary.add(pv1)
                            else:
                                key2, val = split_key_val(value)
                                pv2 = ParamValue(key2,val,ParamValuePosition.BODY)
                                pv2.role = self.role
                                if source:
                                    pv2.role = source
                                pv2.is_mutated = is_mutated
                                pv.paramvals.append(pv2)
                                dictionary.add(pv2)
                    else:
                        print(f"[HTTPREQUEST {self.role}] {key} --> {val1} is not string. No nested paramval check")
            else:
                key, val = split_key_val(self.post_data_encoded)
                pv2 = ParamValue(key,val,ParamValuePosition.BODY)
                pv2.role = self.role
                if source:
                    pv2.role = source
                pv2.is_mutated = is_mutated
                self.paramvals.append(pv2)
                dictionary.add(pv2)

    def extract_param_value(self, path_parts=None):
        self.paramvals = list()
        self.paramvals_without_nonce = list()
        self.num_sysgen = 0

        if path_parts:
            for i, p in enumerate(path_parts):
                pv = ParamValue(f"path{i}",p,ParamValuePosition.PATH)
                pv.role = self.role
                self.paramvals.append(pv)
                dictionary.add(pv)
                if not pv.is_nonce:
                    self.paramvals_without_nonce.append(pv)
                if pv.is_system_param and not pv.is_nested():
                    self.num_sysgen += 1

        if self.post_data_json and isinstance(self.post_data_json, dict):
            for key in self.post_data_json.keys():
                pv = ParamValue(key,self.post_data_json[key],ParamValuePosition.BODY)
                pv.role = self.role
                self.paramvals.append(pv)
                dictionary.add(pv)
                if not pv.is_nonce:
                    self.paramvals_without_nonce.append(pv)

                if isinstance(self.post_data_json[key],str):
                    value = self.post_data_json[key]
                    if value.find("%3D"):
                        value = unquote(self.post_data_json[key])
                    ## There is a possibility that there is nested param values.
                    if value.find('=')>-1:
                        if value.find('&')>-1:
                            for txt in value.split('&'):
                                key2, val = split_key_val(txt)
                                pv1 = ParamValue(key2,val,ParamValuePosition.BODY)
                                pv1.role = self.role
                                pv.paramvals.append(pv1)
                                dictionary.add(pv1)
                                if pv1.is_system_param:
                                    self.num_sysgen += 1
                                if not pv1.is_nonce:
                                    pv.paramvals_without_nonce.append(pv1)
                        else:
                            key2, val = split_key_val(value)
                            pv2 = ParamValue(key2,val,ParamValuePosition.BODY)
                            pv2.role = self.role
                            pv.paramvals.append(pv2)
                            dictionary.add(pv2)
                            if pv2.is_system_param:
                                self.num_sysgen += 1
                            if not pv2.is_nonce:
                                pv.paramvals_without_nonce.append(pv2)
                else:
                    logger.info(f"[HTTPREQUEST {self.role}] {key} --> {self.post_data_json[key]} is not string. No nested paramval check")

                if pv.is_system_param and not pv.is_nested():
                    self.num_sysgen += 1


        if self.param_encoded:
            if self.param_encoded.find('&')>-1:
                self.split_char = '&'
                for txt in self.param_encoded.split('&'):
                    key, val = split_key_val(txt)
                    pv1 = ParamValue(key,val,ParamValuePosition.URL)
                    pv1.role = self.role
                    self.paramvals.append(pv1)
                    dictionary.add(pv1)
                    if pv1.is_system_param:
                        self.num_sysgen += 1
                    if not pv1.is_nonce:
                        self.paramvals_without_nonce.append(pv1)
            elif self.param_encoded.find(';')>-1:
                self.split_char = ';'
                for txt in self.param_encoded.split(';'):
                    key, val = split_key_val(txt)
                    pv1 = ParamValue(key,val,ParamValuePosition.URL)
                    pv1.role = self.role
                    self.paramvals.append(pv1)
                    dictionary.add(pv1)
                    if pv1.is_system_param:
                        self.num_sysgen += 1
                    if not pv1.is_nonce:
                        self.paramvals_without_nonce.append(pv1)
            else:
                key, val = split_key_val(self.param_encoded)
                pv2 = ParamValue(key,val,ParamValuePosition.URL)
                pv2.role = self.role
                self.paramvals.append(pv2)
                dictionary.add(pv2)
                if pv2.is_system_param:
                    self.num_sysgen += 1
                if not pv2.is_nonce:
                    self.paramvals_without_nonce.append(pv2)

    def extract_reference_param(self):
        if self.reference_params:
            for param in self.paramvals:
                for param_nested in param.paramvals:
                    if param_nested.param in self.reference_params:
                        if param_nested.param!="" and param_nested.is_system_param:
                            param_nested.is_reference = True
                if param.param in self.reference_params:
                    if param.param!="" and param.is_system_param:
                        param.is_reference = True

def parse_cookie(cookie_str):
    if cookie_str.find(';')>-1:
        cookie_str = cookie_str.replace(';', '&')
    return parse_post_data(cookie_str)

def save_seclevel_cookie(cookie_str):
    parsed_cookie = parse_cookie(cookie_str)
    if "security" in parsed_cookie:
        parsed_cookie["security"]

def drop_cookie_from_header(headers: Dict[str, str]):
    new_header = {}
    if headers:
        for key in headers:
            if key.find(config.data["COOKIE_KEYWORD"])>-1:
                print("[HTTPREQUEST] Drop cookie from header", key, headers[key])
                pass
            else:
                new_header[key] = headers[key]

    return new_header

def parse_multipart_content(data, content_type):
    NAME_KEYWORD = "name="
    print(f"[HTTPREQUEST] Parsing Multipart Content")
    post_data = {}
    if isinstance(data, str):
        data = data.encode('utf-8')  # Convert to bytes
    multipart_data = decoder.MultipartDecoder(data,content_type)
    for part in multipart_data.parts:

        for k in part.headers:
            key = None
            value = part.headers[k].decode("utf-8")
            pos = value.find(NAME_KEYWORD)
            if pos>-1:
                key = value[pos+len(NAME_KEYWORD)+1:-1]

        try:
            post_data[key] = part.content.decode("utf-8")
        except Exception as e:
            print(f"[HTTPREQUEST] Error in decoding byte values. Try to use the raw byte")
            print(e)
            post_data[key] = part.content

    return post_data

def parse_keys_from_payload(req: HTTPRequest):
    if req.param_encoded:
        for txt in req.param_encoded.split('=')[:-1]:
            pos = txt.find('&')
            if pos>-1:
                key = txt[pos+1:]
                req.keys.append(key)
            else:
                req.keys.append(txt)

    if req.post_data_encoded:
        if req.content_type and req.content_type.find('multipart/form-data')>-1:
            if req.post_data_json:
                keylist = list(req.post_data_json.keys())
                req.keys += keylist
        else:
            for txt in req.post_data_encoded.split('=')[:-1]:
                pos = txt.find('&')
                if pos>-1:
                    key = txt[pos+1:]
                    req.keys.append(key)
                else:
                    req.keys.append(txt)

    print(f"[HTTPREQUEST] Parsed key:",req.keys)

async def convert_request_type(request: Request, role=None) -> HTTPRequest:
    print(f"[HTTPREQUEST] Converting Native Request to HTTP Request:", request)
    req = None
    try:
        req = HTTPRequest()
        req.source = "InterceptedRequest"
        req.role = role
        req.full_url = request.url
        ##PARSE TO <scheme>://<netloc>/<path>;<params>?<query>#<fragment>
        parsed_url = urlparse(req.full_url)
        req.url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
        req.base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
        req.param_encoded = parsed_url.query
        req.method = request.method

        if 'content-type' in request.headers:
            req.content_type = request.headers['content-type']

        if 'content-type' in request.headers and request.headers['content-type'].find('multipart/form-data')>-1:
            print(f"[HTTPREQUEST {role}] Seeing a post data with multipart/form-data content-type.")
            req.is_HTML_form = True
            req.post_data_encoded = request.post_data

            data_json = parse_multipart_content(request.post_data_buffer,req.content_type)
            print(f"[HTTPREQUEST {role}] DATA JSON: ",data_json)
            req.post_data_json = data_json
        elif 'content-type' in request.headers and request.headers['content-type'].find('x-www-form-urlencoded')>-1:
            req.is_HTML_form = True
            req.post_data_json = parse_post_data(request.post_data)
            
            if request.post_data_json and len(request.post_data_json)>0:
                req.post_data_encoded = urlencode(request.post_data_json, doseq=True)
            else:
                req.post_data_encoded =request.post_data
        else:
            req.post_data_json = request.post_data_json
            req.post_data_encoded = request.post_data

        req.extract_param_value()

        req.header = await request.all_headers()
        
        req.id_ori_request = id(request)

        if "referer" in req.header:
            req.referer = req.header['referer']

    except Exception as e:
        print(f"[HTTPREQUEST {role}] Error in printing result: {e}")
        print(f"[HTTPREQUEST {role}] {traceback.format_exc()[:1500]}")

    return req

def convert_request_from_entry(request_entry) -> HTTPRequest:
    logger.info(f"[HTTPREQUEST] Converting Request Entry to HTTP Request: %s", request_entry["id"])
    req = None
    try:
        req = HTTPRequest()
        req.source = "InterceptedRequest"
        req.id = request_entry['id']

        req.full_url = request_entry['request']['url']
        ##PARSE TO <scheme>://<netloc>/<path>;<params>?<query>#<fragment>
        parsed_url = urlparse(req.full_url)
        req.url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
        req.base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
        req.found_value = request_entry['found_value']
        req.param_encoded = parsed_url.query
        req.method = request_entry['request']['method']

        req.content_type = request_entry['request']['content_type']

        if req.content_type and req.content_type.find('multipart/form-data')>-1:
            logger.info(f"[HTTPREQUEST] Seeing a post data with multipart/form-data content-type in %s", request_entry["id"])
            req.is_HTML_form = True
            req.post_data_encoded = request_entry['request']['body']

            data_json = parse_multipart_content(request_entry['request']['body'],req.content_type)
            logger.info(f"[HTTPREQUEST] DATA JSON: %s",data_json)
            req.post_data_json = data_json
        elif req.content_type and req.content_type.find('x-www-form-urlencoded')>-1:
            logger.info(f"[HTTPREQUEST] Seeing a post data with x-www-form-urlencoded content-type in %s", request_entry["id"])
            req.is_HTML_form = True
            req.post_data_json = parse_post_data(request_entry['request']['body'])
            req.post_data_encoded = request_entry['request']['body']
        else:
            logger.info(f"[HTTPREQUEST] No content-type is found")
            req.post_data_json = None
            req.post_data_encoded = request_entry['request']['body']

        # Split the path by "/" and filter out empty strings
        path_parts = [part for part in parsed_url.path.split("/") if part]
        request_entry['path_parts'] = path_parts
        req.extract_param_value(request_entry['path_parts'])

        req.header = request_entry['request']['headers']

        req.id_ori_request = id(request_entry)

        if "referer" in req.header:
            req.referer = req.header['referer']

    except Exception as e:
        logger.error(f"[HTTPREQUEST] Error in printing result: {e}")
        logger.error(f"[HTTPREQUEST] {traceback.format_exc()[-1500:]}")

    return req

def convert_request_to_yaml(request: HTTPRequest):
    print(f"[HTTPREQUEST] Converting HTTP Request:", request.full_url, "to YAML")
    return yaml.dump(request.__dict__)

def convert_yaml_file_to_request(filename):
    print(f"[HTTPREQUEST] Loading HTTP Request from:", filename)
    with open(filename, encoding="utf-8_sig") as f:
        data = yaml.load(f, Loader=yaml.Loader)
    req = HTTPRequest()
    req.init_data(data)

    req.extract_param_value()
    req.extract_reference_param()

    return req
