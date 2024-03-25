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


import os
import sys
import requests
import shutil
from time import sleep
import google.auth
import google.auth.transport.requests
from utilities import (  # pylint: disable=import-error
    run_validator_proxy,
    unzip_file,
    parse_proxy_hosts,
    get_tes,
)
from base_logger import logger


class Apigee:
    def __init__(
        self,
        apigee_type="x",
        base_url="https://apigee.googleapis.com/v1",
        auth_type="oauth",
        org="validate",
    ):
        self.org = org
        self.baseurl = f"{base_url}/organizations/{org}"
        self.apigee_type = apigee_type
        self.auth_type = auth_type
        access_token = self.get_access_token()
        self.auth_header = {
            "Authorization": f"Bearer {access_token}"
            if self.auth_type == "oauth"
            else f"Basic {access_token}"  # noqa
        }

    def is_token_valid(self, token):
        url = f"https://www.googleapis.com/oauth2/v1/tokeninfo?access_token={token}"  # noqa
        response = requests.get(url)
        if response.status_code == 200:
            logger.info(f"Token Validated for user {response.json()['email']}")
            return True
        return False

    def get_access_token(self):
        try:
            credentials, project_id = google.auth.default()
            request = google.auth.transport.requests.Request()
            credentials.refresh(request)
            access_token = credentials.token
            if self.is_token_valid(access_token):
                return access_token
            logger.error('please run "export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)" first or set the Application Default Credentials using "gcloud auth application-default login" !! ')  # noqa
        except Exception as e:
            logger.debug(f"Couldn't find the default credentials. ERROR-INFO :{e}")  # noqa

        logger.debug("Checking env variable value.")
        token = os.getenv(
            "APIGEE_ACCESS_TOKEN"
            if self.apigee_type == "x"
            else "APIGEE_OPDK_ACCESS_TOKEN"
        )
        if token is not None:
            if self.apigee_type == "x":
                if self.is_token_valid(token):
                    return token
                else:
                    logger.error('please run "export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)" first or set the Application Default Credentials using "gcloud auth application-default login" !! ')  # noqa
                    sys.exit(1)
            else:
                return token
        else:
            if self.apigee_type == "x":
                logger.error('please run "export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)" first or set the Application Default Credentials using "gcloud auth application-default login" !! ')  # noqa
            else:
                logger.error('please export APIGEE_OPDK_ACCESS_TOKEN or set the Application Default Credentials using "gcloud auth application-default login"')  # noqa
            sys.exit(1)

    def set_auth_header(self):
        access_token = self.get_access_token()
        self.auth_header = {
            "Authorization": "Bearer {}".format(access_token)
            if self.auth_type == "oauth"
            else "Basic {}".format(access_token)
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
            revision = response.json().get('revision', ['1'])
            return True, revision
        else:
            return False, None

    def create_api(self, api_name, proxy_bundle_path):
        url = f"{self.baseurl}/apis?action=import&name={api_name}&validate=true"  # noqa
        proxy_bundle_name = os.path.basename(proxy_bundle_path)
        files = [
            (
                "data",
                (proxy_bundle_name, open(proxy_bundle_path, "rb"), "application/zip"),  # noqa
            )
        ]
        headers = self.auth_header.copy()
        response = requests.request(
            "POST", url, headers=headers, data={}, files=files
        )
        if response.status_code == 200:
            revision = response.json().get('revision', "1")
            return True, revision
        logger.debug(response.text)
        return False, None

    def get_api_deployments(self, api_name):
        headers = self.auth_header.copy()

        deployed_revision_url = f"{self.baseurl}/apis/{api_name}/deployments"
        deployed_revision_get_response = requests.request(
            "GET", deployed_revision_url, headers=headers, data={}
            )
        deployments = deployed_revision_get_response.json()
        revision_deployements = deployments.get('deployments')
        return revision_deployements

    def delete_api(self, api_name):
        headers = self.auth_header.copy()
        revision_deployements = self.get_api_deployments(api_name)

        if revision_deployements:
            for revision_deployement in revision_deployements:
                deployed_env = revision_deployement.get('environment')
                rev = revision_deployement.get('revision')

                # delete api deployment
                revision_delete_url = f"{self.baseurl}/environments/{deployed_env}/apis/{api_name}/revisions/{rev}/deployments"  # noqa
                revision_response = requests.request(
                    "DELETE",
                    revision_delete_url, headers=headers, data={}
                )
                if revision_response.status_code == 200:
                    logger.info(f"Successfully deleted {api_name} api proxy revision {rev} in env {deployed_env}")  # noqa

        # proxy deletion
        url = f"{self.baseurl}/apis/{api_name}"
        try:
            response = requests.request(
                "DELETE", url, headers=headers, data={}
            )
            if response.status_code == 200:
                logger.info(f"Api proxy {api_name} deleted successfully.")
            else:
                logger.error(f"Error deleting Api proxy {api_name}. ERROR-INFO - {response.json()}")  # noqa
        except Exception as e:
            logger.error(f"Couldn't delete api proxy {api_name}. ERROR-INFO- {e}")  # noqa

    def get_api_revisions_deployment(self, env, api_name, api_rev):  # noqa
        url = (
            url
        ) = f"{self.baseurl}/environments/{env}/apis/{api_name}/revisions/{api_rev}/deployments"  # noqa
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers, data={})
        if response.status_code == 200:
            resp = response.json()
            api_deployment_status = resp.get("state", "")
            if self.apigee_type == "x":
                if api_deployment_status == "READY":
                    return True
            if self.apigee_type == "opdk":
                if api_deployment_status == "deployed":
                    return True
            logger.debug(f"API {api_name} is in Status: {api_deployment_status} !")  # noqa
            return False
        else:
            logger.debug(response.text)
            return False

    def deploy_api(self, env, api_name, api_rev):
        url = (
            url
        ) = f"{self.baseurl}/environments/{env}/apis/{api_name}/revisions/{api_rev}/deployments?override=true"  # noqa
        headers = self.auth_header.copy()
        response = requests.request("POST", url, headers=headers, data={})
        if response.status_code == 200:
            return True
        else:
            resp = response.json()
            if "already deployed" in resp["error"]["message"]:
                logger.info(f"Proxy {api_name} is already Deployed")
                return True
            logger.debug(f"{response.text}")
            return False

    def deploy_api_bundle(self, env, api_name, proxy_bundle_path, api_force_redeploy=False):  # noqa
        api_deployment_retry = 60
        api_deployment_sleep = 5
        api_deployment_retry_count = 0
        api_exists = False
        get_api_status, api_revs = self.get_api(api_name)
        if get_api_status:
            api_exists = True
            api_rev = api_revs[-1]
            logger.warning(f"Proxy with name {api_name} with revision {api_rev} already exists in Apigee Org {self.org}")  # noqa
            if api_force_redeploy:
                api_exists = False
        if not api_exists:
            api_created, api_rev = self.create_api(api_name, proxy_bundle_path)
            if api_created:
                logger.info(f"Proxy has been imported with name {api_name} in Apigee Org {self.org}")  # noqa
                api_exists = True
            else:
                logger.error(f"ERROR : Proxy {api_name} import failed !!! ")
                return False
        if api_exists:
            if self.get_api_revisions_deployment(
                        env, api_name, api_rev
                    ):
                logger.info(f"Proxy {api_name} already active in to {env} in Apigee Org {self.org} !")  # noqa
                return True
            else:
                if self.deploy_api(env, api_name, api_rev):
                    logger.info(f"Deploying proxy with name {api_name}  to {env} in Apigee Org {self.org}")  # noqa
                    while api_deployment_retry_count < api_deployment_retry:
                        if self.get_api_revisions_deployment(
                            env, api_name, api_rev
                        ):
                            logger.info(f"Proxy {api_name} active in runtime after {api_deployment_retry_count*api_deployment_sleep} seconds ")  # noqa
                            return True
                        else:
                            logger.debug(f"Checking API deployment status in {api_deployment_sleep} seconds")  # noqa
                            sleep(api_deployment_sleep)
                            api_deployment_retry_count += 1
                else:
                    logger.error(f"ERROR : Proxy deployment  to {env} in Apigee Org {self.org} Failed !!")  # noqa
                    return False

    def get_api_vhost(self, vhost_name, env):
        if self.apigee_type == "opdk":
            url = f"{self.baseurl}/environments/{env}/virtualhosts/{vhost_name}"  # noqa
        else:
            url = f"{self.baseurl}/envgroups/{vhost_name}"
        headers = self.auth_header.copy()
        response = requests.request("GET", url, headers=headers)
        if response.status_code == 200:
            if self.apigee_type == "opdk":
                hosts = response.json()["hostAliases"]
            else:
                hosts = response.json()["hostnames"]
            if len(hosts) == 0:
                logger.error(f"Vhost/Env Group {vhost_name} contains no domains")  # noqa
                return None
            return hosts
        else:
            logger.error(f"Vhost/Env Group {vhost_name} contains no domains")
            return None

    def list_apis(self, api_type):
        url = f"{self.baseurl}/{api_type}"
        headers = self.auth_header.copy()
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            if self.apigee_type == "x":
                if len(response.json()) == 0:
                    return []
                return [
                    p["name"]
                    for p in response.json()[
                        "proxies" if api_type == "apis" else "sharedFlows"
                    ]
                ]  # noqa
            return response.json()
        else:
            return []

    def list_api_revisions(self, api_type, api_name):
        url = f"{self.baseurl}/{api_type}/{api_name}/revisions"
        headers = self.auth_header.copy()
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            return []

    def fetch_api_revision(self, api_type, api_name, revision, export_dir):  # noqa
        url = f"{self.baseurl}/{api_type}/{api_name}/revisions/{revision}?format=bundle"  # noqa
        headers = self.auth_header.copy()
        response = requests.get(url, headers=headers, stream=True)
        if response.status_code == 200:
            self.write_proxy_bundle(export_dir, api_name, response.raw)
            return True
        return False

    def fetch_api_proxy_ts_parallel(self, arg_tuple):
        self.fetch_api_revision(arg_tuple[0], arg_tuple[1], arg_tuple[2], arg_tuple[3])  # noqa
        unzip_file(
                    f"{arg_tuple[3]}/{arg_tuple[1]}.zip",  # noqa
                    f"{arg_tuple[3]}/{arg_tuple[1]}",  # noqa
                )
        parsed_proxy_hosts = parse_proxy_hosts(f"{arg_tuple[3]}/{arg_tuple[1]}/apiproxy")  # noqa
        proxy_tes = get_tes(parsed_proxy_hosts)
        return arg_tuple[0], arg_tuple[1], parsed_proxy_hosts, proxy_tes

    def fetch_env_target_servers_parallel(self, arg_tuple):
        ts_info = self.get_target_server(arg_tuple[0], arg_tuple[1])
        return arg_tuple[1], ts_info

    def call_validator_proxy_parallel(self, arg_tuple):
        response = run_validator_proxy(arg_tuple[0], arg_tuple[1], arg_tuple[2], arg_tuple[3], arg_tuple[4])  # noqa
        if isinstance(response, list):
            report = []
            for output in response:
                report.append(
                    [
                        output["name"],
                        output["extracted_from"],
                        output["host"],
                        output["port"],
                        output["env"],
                        output["status"],
                        output["info"] if output.get("info") else " & ".join(
                            list(set(arg_tuple[5][output["name"]])))
                        if output["name"] in arg_tuple[5]
                        else "No References in any API",
                    ]
                )
            return report
        else:
            return {"error": f"Error while calling the validator proxy - {response.get('error','unknown error')} with payload {arg_tuple[3]}"}  # noqa

    def write_proxy_bundle(self, export_dir, file_name, data):
        file_path = f"./{export_dir}/{file_name}.zip"
        with open(file_path, "wb") as fl:
            shutil.copyfileobj(data, fl)
