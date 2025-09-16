import os
from enum import Enum

from playwright.async_api import APIResponse

from HTTPRequest import HTTPRequest
from VerificationLabel import VerificationLabel
from general_functions import read_cov_from_file
from config import config

class Input:
    def __init__(self, request, response, testname):
        self.attack_surface_ID = None
        self.request: HTTPRequest = request
        self.response: APIResponse = response
        self.response_title = None
        self.hit_path_set = None
        self.label : VerificationLabel = VerificationLabel.UNDEFINED
        self.error_report = list()
        self.vul_oracle = ""
        self.vul_oracles = list()
        self.reason_to_add = None
        self.mutated_values = None
        self.mutated_paramvals = list()
        self.testname = testname
        self.detected_time = None
        self.sent_role = None
        self.ids_from_refpage = list()
        self.params_from_refpage = list()
        self.is_verification_proof = False
        self.detection_order = 0

        if response:
            self.calculate_coverage()

    def __eq__(self, other):
        if not isinstance(other, Input):
            # don't attempt to compare against unrelated types
            return NotImplemented

        return self.request == other.request and str(self.vul_oracles) == str(other.vul_oracles)

    def __str__(self):
        return f"{self.request}"

    def analyseResponse(self):
        pass

    def calculate_coverage(self):
        stringified_hit_paths = None
        coverage_file_path = (
            f"{config.data['COV_PATHS']}/{self.request.id}.json"
        )
        print(f"[INPUT {self.request.role}] Calculating coverage from ", coverage_file_path)
        self.hit_path_set, stringified_hit_paths = read_cov_from_file(coverage_file_path)

        stringified_hit_paths = None
