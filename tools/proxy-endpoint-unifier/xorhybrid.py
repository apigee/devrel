#!/usr/bin/python

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import requests
import os

class ApigeeXorHybrid:
    def __init__(self,org):
        self.baseurl=f"https://apigee.googleapis.com/v1/organizations/{org}"
        self.auth_header = {}

    def set_auth_header(self,token):
        self.auth_header = {
            'Authorization' : f"Bearer {token}"
        }
    
    def validate_api(self,api_type,proxy_bundle_path):
        api_name = os.path.basename(proxy_bundle_path).split('.zip')[0]
        url = f"{self.baseurl}/{api_type}?name={api_name}&action=validate&validate=true"
        files=[
        ('data',(api_name,open(proxy_bundle_path,'rb'),'application/zip'))
        ]
        response = requests.request("POST", url, headers=self.auth_header, data={}, files=files)
        if response.status_code == 200 :
            return True
        else:
            return response.json()