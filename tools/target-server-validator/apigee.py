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
import sys
import shutil
from time import sleep


class Apigee:

    def __init__(
            self,
            apigee_type="x",
            base_url="https://apigee.googleapis.com/v1",
            auth_type="oauth",
            org="validate"):
        self.org = org
        self.baseurl = f"{base_url}/organizations/{org}"
        self.apigee_type = apigee_type
        self.auth_type = auth_type
        access_token = self.get_access_token()
        self.auth_header = {
            'Authorization': 'Bearer {}'.format(access_token) if self.auth_type == 'oauth' else 'Basic {}'.format(access_token)  # noqa
        }

    def is_token_valid(self, token):
        url = f"https://www.googleapis.com/oauth2/v1/tokeninfo?access_token={token}"  # noqa
        r = requests.get(url)
        if r.status_code == 200:
            print(f"Token Validated for user {r.json()['email']}")
            return True
        return False

    def get_access_token(self):
        token = os.getenv('APIGEE_ACCESS_TOKEN' if self.apigee_type == 'x' else 'APIGEE_OPDK_ACCESS_TOKEN')  # noqa
        if token is not None:
            if self.apigee_type == 'x':
                if self.is_token_valid(token):
                    return token
                else:
                    print('please run "export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)" first !! ')  # noqa
                    sys.exit(1)
            else:
                return token
        else:
            if self.apigee_type == 'x':
                print('please run "export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)" first !! ')  # noqa
            else:
                print('please export APIGEE_OPDK_ACCESS_TOKEN')
            sys.exit(1)

    def set_auth_header(self):
        access_token = self.get_access_token()
        self.auth_header = {
            'Authorization': 'Bearer {}'.format(access_token) if self.auth_type == 'oauth' else 'Basic {}'.format(access_token)  # noqa
        }

    def list_environments(self):
        url = f"{self.baseurl}/environments"
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            return []

    def list_target_servers(self, env):
        url = f"{self.baseurl}/environments/{env}/targetservers"
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            return []

    def get_target_server(self, env, target_server):
        url = f"{self.baseurl}/environments/{env}/targetservers/{target_server}"  # noqa
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            return []

    def get_api(self, api_name):
        url = f"{self.baseurl}/apis/{api_name}"
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers)
        if response.status_code == 200:
            return True
        else:
            return False

    def create_api(self, api_name, proxy_bundle_path):
        url = f"{self.baseurl}/apis?action=import&name={api_name}&validate=true"  # noqa
        proxy_bundle_name = os.path.basename(proxy_bundle_path)
        files = [
        ('data',(proxy_bundle_name,open(proxy_bundle_path,'rb'),'application/zip'))  # noqa
        ]
        headers = self.auth_header.copy()
        response = requests.request("POST", url, headers=headers, data={}, files=files)  # noqa
        if response.status_code == 200:
            return True
        else:
            print(response.json())
            return False

    def get_api_revisions_deployment(self, env, api_name, api_rev):  # noqa
        url = url = f"{self.baseurl}/environments/{env}/apis/{api_name}/revisions/{api_rev}/deployments"  # noqa
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers, data={})
        if response.status_code == 200:
            resp = response.json()
            api_deployment_status = resp.get('state', '')
            if self.apigee_type == 'x':
                if api_deployment_status == 'READY':
                    return True
            if self.apigee_type == 'opdk':
                if api_deployment_status == 'deployed':
                    return True
            print(f"API {api_name} is in Status: {api_deployment_status} !")  # noqa
            return False
        else:
            return False

    def deploy_api(self, env, api_name, api_rev):
        url = url = f"{self.baseurl}/environments/{env}/apis/{api_name}/revisions/{api_rev}/deployments?override=true"  # noqa
        headers = self.auth_header.copy()
        response = requests.request("POST", url, headers=headers, data={})
        if response.status_code == 200:
            return True
        else:
            resp = response.json()
            if 'already deployed' in resp['error']['message']:
                print('Proxy {} is already Deployed'.format(api_name))
                return True
            return False

    def deploy_api_bundle(self, env, api_name, proxy_bundle_path, api_rev=1):  # noqa
        api_deployment_retry = 60
        api_deployment_sleep = 5
        api_deployment_retry_count = 0
        api_exists = False
        if self.get_api(api_name):
                print(f'Proxy with name {api_name} already exists in Apigee Org {self.org}')  # noqa
                api_exists = True
        else:
            if self.create_api(api_name, proxy_bundle_path):
                print(f'Proxy has been imported with name {api_name} in Apigee Org {self.org}')  # noqa
                api_exists = True
            else:
                print(f'ERROR : Proxy {api_name} import failed !!! ')
                return False
        if api_exists:
            if self.deploy_api(env, api_name, api_rev):
                print(f'Proxy with name {api_name} has been deployed  to {env} in Apigee Org {self.org}')  # noqa
                while api_deployment_retry_count < api_deployment_retry:
                    if self.get_api_revisions_deployment(env, api_name, api_rev):  # noqa
                        print(f'Proxy {api_name} active in runtime after {api_deployment_retry_count*api_deployment_sleep} seconds ')  # noqa
                        return True
                    else:
                        print(f"Checking API deployment status in {api_deployment_sleep} seconds")  # noqa
                        sleep(api_deployment_sleep)
                        api_deployment_retry_count += 1
            else:
                print(f'ERROR : Proxy deployment  to {env} in Apigee Org {self.org} Failed !!')  # noqa
                return False

    def get_api_vhost(self, vhost_name, env):
        if self.apigee_type == 'opdk':
            url = f"{self.baseurl}/environments/{env}/virtualhosts/{vhost_name}"  # noqa
        else:
            url = f"{self.baseurl}/envgroups/{vhost_name}"
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers)
        if response.status_code == 200:
            if self.apigee_type == 'opdk':
                hosts = response.json()['hostAliases']
            else:
                hosts = response.json()['hostnames']
            if len(hosts) == 0:
                print(f'ERROR: Vhost/Env Group {vhost_name} contains no domains')  # noqa
                return None
            return hosts
        else:
            print(f'ERROR: Vhost/Env Group {vhost_name} contains no domains')  # noqa
            return None

    def list_apis(self, api_type):
        url = f"{self.baseurl}/{api_type}"
        headers = self.auth_header.copy()
        r = requests.get(url, headers=headers)
        if r.status_code == 200:
            if self.apigee_type == 'x':
                if len(r.json()) == 0:
                    return []
                return [ p['name'] for p in r.json()['proxies' if api_type == 'apis' else 'sharedFlows']]  # noqa
            return r.json()
        else:
            return []

    def list_api_revisions(self, api_type, api_name):
        url = f"{self.baseurl}/{api_type}/{api_name}/revisions"
        headers = self.auth_header.copy()
        r = requests.get(url, headers=headers)
        if r.status_code == 200:
            return r.json()
        else:
            return []

    def fetch_api_revision(self, api_type, api_name, revision, export_dir):  # noqa
        url = f"{self.baseurl}/{api_type}/{api_name}/revisions/{revision}?format=bundle"  # noqa
        headers = self.auth_header.copy()
        r = requests.get(url, headers=headers, stream=True)
        if r.status_code == 200:
            self.write_proxy_bundle(export_dir, api_name, r.raw)
            return True
        return False

    def write_proxy_bundle(self, export_dir, file_name, data):
        file_path = f"./{export_dir}/{file_name}.zip"
        with open(file_path, 'wb') as fl:
            shutil.copyfileobj(data, fl)
