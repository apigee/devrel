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
import json
from utilities import (  # pylint: disable=import-error
    parse_config,
    create_proxy_bundle,
    delete_file,
    read_csv,
    write_csv_report,
    write_md_report,
    create_dir,
    has_templating,
    get_row_host_port,
    run_parallel,
)
from apigee_utils import Apigee  # pylint: disable=import-error
from base_logger import logger


def main():
    # Parse Inputs
    cfg = parse_config("input.properties")
    check_proxies = cfg["validation"].getboolean("check_proxies")
    proxy_export_dir = cfg["validation"]["proxy_export_dir"]
    report_format = cfg["validation"]["report_format"]
    allow_insecure = cfg["validation"].getboolean("allow_insecure")
    if report_format not in ["csv", "md"]:
        report_format = "md"

    # Intialize Source & Target Apigee
    SourceApigee = Apigee(
        "x" if "apigee.googleapis.com" in cfg["source"]["baseurl"] else "opdk",
        cfg["source"]["baseurl"],
        cfg["source"]["auth_type"],
        cfg["source"]["org"],
    )

    TargetApigee = Apigee(
        "x" if "apigee.googleapis.com" in cfg["source"]["baseurl"] else "opdk",
        cfg["target"]["baseurl"],
        cfg["target"]["auth_type"],
        cfg["target"]["org"],
    )

    environments = SourceApigee.list_environments()
    all_target_servers = []

    # Fetch Target Servers from  Source Apigee@
    logger.info("exporting Target Servers !")
    for each_env in environments:
        target_servers = SourceApigee.list_target_servers(each_env)
        args = ((each_env, each_ts) for each_ts in target_servers)
        results = run_parallel(SourceApigee.fetch_env_target_servers_parallel, args)  # noqa
        for result in results:
            ts, ts_info = result
            ts_info["env"] = each_env
            ts_info["extracted_from"] = "TargetServer"
            all_target_servers.append(ts_info)

    # Fetch Targets in APIs & Shared Flows from Source Apigee
    proxy_hosts = {}
    proxy_targets = {}
    if check_proxies:
        skip_proxy_list = (
            cfg["validation"].get("skip_proxy_list", "").split(",")
        )
        logger.info("exporting proxies to be analyzed ! this may take a while !")  # noqa
        api_types = ["apis", "sharedflows"]
        api_revision_map = {}
        for each_api_type in api_types:
            api_revision_map[each_api_type] = {}
            api_revision_map[each_api_type]["proxies"] = {}
            api_revision_map[each_api_type]["export_dir"] = (
                proxy_export_dir + f"/{each_api_type}"
            )
            create_dir(proxy_export_dir + f"/{each_api_type}")

            for each_api in SourceApigee.list_apis(each_api_type):
                if each_api not in skip_proxy_list:
                    api_revision_map[each_api_type]["proxies"][
                        each_api
                    ] = SourceApigee.list_api_revisions(each_api_type, each_api)[  # noqa
                        -1
                    ]
                else:
                    logger.info(f"Skipping API {each_api}")

        args = (
            (
                each_api_type,
                each_api,
                each_api_rev,
                api_revision_map[each_api_type]["export_dir"]
            )
            for each_api_type, each_api_type_data in api_revision_map.items()
            for each_api, each_api_rev in each_api_type_data["proxies"].items()
        )
        logger.debug("Exporting proxy target servers")
        results = run_parallel(SourceApigee.fetch_api_proxy_ts_parallel, args)

        for result in results:
            each_api_type, each_api, parsed_proxy_hosts, proxy_ts = result
            if proxy_hosts.get(each_api_type):
                proxy_hosts[each_api_type][each_api] = parsed_proxy_hosts
            else:
                proxy_hosts[each_api_type] = {}
                proxy_hosts[each_api_type][each_api] = parsed_proxy_hosts

            for each_te in proxy_ts:
                if each_te in proxy_targets:
                    proxy_targets[each_te].append(
                        f"{each_api_type} - {each_api}"
                    )
                else:
                    proxy_targets[each_te] = [
                        f"{each_api_type} - {each_api}"
                    ]
        logger.debug("Exporting proxy target servers done")

    bundle_path = os.path.dirname(os.path.abspath(__file__))

    # Create Validation Proxy Bundle
    logger.info("Creating proxy bundle !")
    create_proxy_bundle(bundle_path, cfg["validation"]["api_name"], "apiproxy")

    # Deploy Validation Proxy Bundle
    logger.info("Deploying proxy bundle !")
    if not TargetApigee.deploy_api_bundle(
        cfg["validation"]["api_env"],
        cfg["validation"]["api_name"],
        f"{bundle_path}/{cfg['validation']['api_name']}.zip",
        cfg["validation"].getboolean("api_force_redeploy", False)
    ):
        logger.error(f"Proxy: {cfg['validation']['api_name']} deployment failed.")  # noqa
        sys.exit(1)
    # CleanUp Validation Proxy Bundle
    logger.info(f"Cleaning Up local proxy bundle !")  # noqa
    delete_file(f"{bundle_path}/{cfg['validation']['api_name']}.zip")

    # Fetch API Northbound Endpoint
    logger.info(f"Fetching VHost with name {cfg['validation']['api_hostname']} !")  # noqa
    vhost_domain_name = cfg["validation"]["api_hostname"]
    vhost_ip = cfg["validation"].get("api_ip", "").strip()
    api_url = f"https://{vhost_domain_name}/validate-target-server"
    final_report = []

    for each_api_type, apis in proxy_hosts.items():
        for each_api, each_targets in apis.items():
            for each_target in each_targets:
                if (
                    not has_templating(each_target["host"])
                    and not each_target["target_server"]
                ):
                    each_target["env"] = "_ORG_API_"
                    if each_api_type == "apis":
                        each_target["extracted_from"] = "APIProxy"
                    else:
                        each_target["extracted_from"] = "SharedFlow"
                    each_target["name"] = each_api
                    each_target["info"] = each_target["source"]
                    all_target_servers.append(each_target)

    if cfg["validation"].getboolean("check_csv"):
        csv_file = cfg["csv"]["file"]
        default_port = cfg["csv"]["default_port"]
        csv_rows = read_csv(csv_file)
        for each_row in csv_rows:
            each_host, each_port = get_row_host_port(each_row, default_port)
            ts_csv_info = {}
            ts_csv_info["host"] = each_host
            ts_csv_info["port"] = each_port
            ts_csv_info["name"] = each_host
            ts_csv_info["info"] = "_NA_"
            ts_csv_info["env"] = "_NA_"
            ts_csv_info["extracted_from"] = "Input CSV"
            all_target_servers.append(ts_csv_info)

    batch_size = 5
    batches = []
    new_structure = {"host_port": []}

    for entry in all_target_servers:
        host = entry.get('host', '')
        port = entry.get('port', '')

        if host and port:
            new_entry = {'host': host, 'port': str(port), 'name': entry.get('name', ''), 'env': entry.get('env', ''), 'extracted_from': entry.get('extracted_from', ''),'info': entry.get('info', '')}  # noqa
            entry['port'] = str(port)
            new_structure.get('host_port', []).append(new_entry)

            if len(new_structure['host_port']) == batch_size:
                batches.append(new_structure)
                new_structure = {'host_port': []}

    if new_structure:
        batches.append(new_structure)

    args = ((api_url,vhost_domain_name,vhost_ip, json.dumps(batch),allow_insecure, proxy_targets) for batch in batches)  # noqa
    output_reports = run_parallel(SourceApigee.call_validator_proxy_parallel, args)  # noqa
    for output in output_reports:
        final_report.extend(output)

    # Write CSV Report
    # TODO: support relative report path
    if report_format == "csv":
        report_file = "report.csv"
        logger.info(f"Dumping report to file {report_file}")
        write_csv_report(report_file, final_report)

    if report_format == "md":
        report_file = "report.md"
        logger.info(f"Dumping report to file {report_file}")
        write_md_report(report_file, final_report)


if __name__ == "__main__":
    main()
