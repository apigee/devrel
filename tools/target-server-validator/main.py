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
    run_validator_proxy,
    delete_file,
    read_csv,
    write_csv_report,
    write_md_report,
    create_dir,
    unzip_file,
    parse_proxy_hosts,
    has_templating,
    get_tes,
    get_row_host_port,
)
from apigee_utils import Apigee  # pylint: disable=import-error


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
    print("INFO: exporting Target Servers !")
    for each_env in environments:
        target_servers = SourceApigee.list_target_servers(each_env)
        for each_ts in target_servers:
            ts_info = SourceApigee.get_target_server(each_env, each_ts)
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
        print(
            "INFO: exporting proxies to be analyzed ! this may take a while !"
        )
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
                    print(f"INFO : Skipping API {each_api}")
        for each_api_type, each_api_type_data in api_revision_map.items():
            proxy_hosts[each_api_type] = {}
            for each_api, each_api_rev in each_api_type_data["proxies"].items():  # noqa
                print(
                    f"Exporting API : {each_api} with revision : {each_api_rev} "  # noqa
                )
                SourceApigee.fetch_api_revision(
                    each_api_type,
                    each_api,
                    each_api_rev,
                    api_revision_map[each_api_type]["export_dir"],
                )
                print(
                    f"Unzipping API : {each_api} with revision : {each_api_rev} "  # noqa
                )
                unzip_file(
                    f"{api_revision_map[each_api_type]['export_dir']}/{each_api}.zip",  # noqa
                    f"{api_revision_map[each_api_type]['export_dir']}/{each_api}",  # noqa
                )
                parsed_proxy_hosts = parse_proxy_hosts(
                    f"{api_revision_map[each_api_type]['export_dir']}/{each_api}/apiproxy"  # noqa
                )
                proxy_hosts[each_api_type][each_api] = parsed_proxy_hosts
                proxy_tes = get_tes(parsed_proxy_hosts)
                for each_te in proxy_tes:
                    if each_te in proxy_targets:
                        proxy_targets[each_te].append(
                            f"{each_api_type} - {each_api}"
                        )
                    else:
                        proxy_targets[each_te] = [
                            f"{each_api_type} - {each_api}"
                        ]
    # Validate Targets against Target Apigee

    bundle_path = os.path.dirname(os.path.abspath(__file__))

    # Create Validation Proxy Bundle
    print("INFO: Creating proxy bundle !")
    create_proxy_bundle(bundle_path, cfg["validation"]["api_name"], "apiproxy")

    # Deploy Validation Proxy Bundle
    print("INFO: Deploying proxy bundle !")
    if not TargetApigee.deploy_api_bundle(
        cfg["validation"]["api_env"],
        cfg["validation"]["api_name"],
        f"{bundle_path}/{cfg['validation']['api_name']}.zip",
        cfg["validation"].getboolean("api_force_redeploy", False)
    ):
        print(f"Proxy: {cfg['validation']['api_name']} deployment failed.")
        sys.exit(1)
    # CleanUp Validation Proxy Bundle
    print("INFO: Cleaning Up local proxy bundle !")
    delete_file(f"{bundle_path}/{cfg['validation']['api_name']}.zip")

    # Fetch API Northbound Endpoint
    print(
        f"INFO: Fetching VHost with name {cfg['validation']['api_hostname']} !"  # noqa
    )
    vhost_domain_name = cfg["validation"]["api_hostname"]
    vhost_ip = cfg["validation"].get("api_ip", "").strip()
    api_url = f"https://{vhost_domain_name}/validate-target-server"
    final_report = []
    _cached_hosts = {}

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

    for batch in batches:
        updated_batch = {'host_port': []}
        host_ports = batch.get('host_port', [])
        for host_port in host_ports:
            if f"{host_port.get('host','')} : {host_port.get('port','')}" in _cached_hosts:  # noqa
                status = _cached_hosts[f"{host_port.get('host','')} : {host_port.get('port','')}"]  # noqa
                final_report.append(
                    [
                        host_port.get('name', ''),
                        host_port.get('extracted_from', ''),
                        host_port.get('host', ''),
                        host_port.get('port', ''),
                        host_port.get('env', ''),
                        status,
                        host_port["info"] if host_port.get("info") else " & ".join(  # noqa
                            list(set(proxy_targets[host_port["name"]])))
                        if host_port["name"] in proxy_targets
                        else "No References in any API",
                    ]
                )
            else:
                updated_batch.get('host_port', []).append(host_port)

        response = run_validator_proxy(
            api_url, vhost_domain_name, vhost_ip, json.dumps(updated_batch), allow_insecure  # noqa
        )
        if response.get("error"):
            print(response["error"])
        else:
            outputs = response.get("hostname_portnumbers_status", [])
            for output in outputs:
                _cached_hosts[f'{output["host"]} : {output["port"]}'] = output["status"]  # noqa
                final_report.append(
                    [
                        output["name"],
                        output["extracted_from"],
                        output["host"],
                        output["port"],
                        output["env"],
                        output["status"],
                        output["info"] if output.get("info") else " & ".join(
                            list(set(proxy_targets[output["name"]])))
                        if output["name"] in proxy_targets
                        else "No References in any API",
                    ]
                )
    # Write CSV Report
    # TODO: support relative report path
    if report_format == "csv":
        report_file = "report.csv"
        print(f"INFO: Dumping report to file {report_file}")
        write_csv_report(report_file, final_report)

    if report_format == "md":
        report_file = "report.md"
        print(f"INFO: Dumping report to file {report_file}")
        write_md_report(report_file, final_report)


if __name__ == "__main__":
    main()
