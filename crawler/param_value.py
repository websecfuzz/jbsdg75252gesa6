from enum import Enum

from config import config
from VerificationLabel import VerificationLabel
from general_functions import is_token_key


class ParamValue:
    def __init__(self, param, value, position):
        self.param = param
        self.value = value
        self.type = "string"

        self.is_reference = False

        try:
            if self.value==None or self.value=="" or str(self.value).find(str(config.data["UNIQUE_NUMBER"]))==0:
                self.is_system_param = False
            elif isinstance(self.value, str) and self.value.lower().find(config.data["UNIQUE_STRING"])>-1:
                self.is_system_param = False
            else:
                self.is_system_param = True
        except Exception as e:
            print(f"[PARAMVAL] Error in {value}: ",e)
            self.is_system_param = True

        self.position = position
        self.role = None
        self.is_nonce = False
        self.paramvals = list()
        self.paramvals_without_nonce = list()
        self.is_mutated = False
        self.is_added_property = False
        self.source = None
        self.BAC_label = VerificationLabel.UNDEFINED

        self.infer_type_from_value()

        if isinstance(param, str) and (param.lower().find("id")==0 or param.lower().find("id")==len(param)-2):
            self.is_id = True
        elif isinstance(self.value, int) or self.type == "int":
            self.is_id = True
        elif self.value and isinstance(self.value, str) and len(self.value)>0 and self.value[0].isnumeric():
            ## We consider a value started with a number is an ID
            self.is_id = True
        else:
            self.is_id = False

        if "NONCE_KEYWORD" in config.data and config.data['NONCE_KEYWORD'] != "":
            self.check_nonce()

    def check_nonce(self):
        search = config.data['NONCE_KEYWORD']
        if self.param and self.param.find(search)>-1:
            self.is_nonce = True
        elif self.param and is_token_key(self.param):
            self.is_nonce = True

    def infer_type_from_value(self):
        if self.value:
            if isinstance(self.value, dict):
                self.type = "dict"
            elif str(self.value).isnumeric():
                self.type = "int"
            elif isinstance(self.value, str) and ((self.value.find("@")>-1 and self.value.find(".")>-1) or self.value.find("%40")>-1):
                self.type = "email"
            elif isinstance(self.value, str) and self.value.find(".")>-1:
                self.type = "url"

    def is_nested(self):
        if len(self.paramvals)>0:
            return True
        return False

    def get_formatted_paramval(self):
        return f"{self.param}={self.value}"

    def __str__(self):
        if self.is_nested():
            return f"[{self.type} ({self.is_reference})({self.role})] {self.param} ==> {[str(x) for x in self.paramvals]}"
        return f"[{self.type} ({self.is_reference})({self.role})] {self.param}={self.value}"

    def __eq__(self, other):
        if not isinstance(other, ParamValue):
            print("[PARAMVALUE] don't attempt to compare against unrelated types")
            return NotImplemented

        if self.is_nested() or other.is_nested():
            return self.param == other.param and self.paramvals == other.paramvals

        if self.is_system_param or other.is_system_param:
            return self.param == other.param and self.value == other.value
        else:
            return self.param == other.param


class ParamValuePosition(Enum):
    HEADER = 1
    URL = 2
    BODY = 3
    FORM = 4
    PATH = 5