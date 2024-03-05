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
import argparse
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
    create_custom_metric,
    report_metric,
    create_custom_dashboard,
    get_metric_descriptor,
    gcs_upload_json,
    download_json_from_gcs,
    write_json_to_file,
    read_json_from_file,
)
from apigee_utils import Apigee  # pylint: disable=import-error
from base_logger import logger


def main():

    # Arguments
    parser = argparse.ArgumentParser(description='details',
    usage='use "%(prog)s --help" for more information',formatter_class=argparse.RawTextHelpFormatter)  # noqa
    parser.add_argument('--onboard', action='store_true', help='Toggle to onboard validator proxy, custom metric descriptors and dashboard')  # noqa
    parser.add_argument('--scan', action='store_true', help='Toggle to read all resources')  # noqa
    parser.add_argument('--monitor', action='store_true', help='Toggle to check the status of target servers and push to GCP Logging')  # noqa

    args = parser.parse_args()

    # Parse Inputs
    cfg = parse_config("input.properties")
    check_proxies = cfg["validation"].getboolean("check_proxies")
    proxy_export_dir = cfg["validation"]["proxy_export_dir"]
    enable_gcp_metrics = cfg["gcp_metrics"].getboolean("enable_gcp_metrics")
    report_format = cfg["validation"]["report_format"]
    allow_insecure = cfg["validation"].getboolean("allow_insecure")
    metrics_project_id = cfg["gcp_metrics"]["project_id"]
    metric_name = cfg["gcp_metrics"]["metric_name"]
    enable_dashboard = cfg["gcp_metrics"]["enable_dashboard"]
    state_file = cfg["target_server_state_file"]["state_file"]
    gcs_project_id = cfg["target_server_state_file"]["gcs_project_id"]

    if report_format not in ["csv", "md"]:
        report_format = "md"

    # Intialize Source & Target Apigee
    source_apigee = Apigee(
        "x" if "apigee.googleapis.com" in cfg["source"]["baseurl"] else "opdk",
        cfg["source"]["baseurl"],
        cfg["source"]["auth_type"],
        cfg["source"]["org"],
    )

    target_apigee = Apigee(
        "x" if "apigee.googleapis.com" in cfg["target"]["baseurl"] else "opdk",
        cfg["target"]["baseurl"],
        cfg["target"]["auth_type"],
        cfg["target"]["org"],
    )

    if args.onboard:
        # Create Validation Proxy Bundle
        bundle_path = os.path.dirname(os.path.abspath(__file__))
        logger.info("Creating proxy bundle !")
        create_proxy_bundle(bundle_path, cfg["validation"]["api_name"], "apiproxy")  # noqa

        # Deploy Validation Proxy Bundle
        logger.info("Deploying proxy bundle !")
        if not target_apigee.deploy_api_bundle(
            cfg["validation"]["api_env"],
            cfg["validation"]["api_name"],
            f"{bundle_path}/{cfg['validation']['api_name']}.zip",
            cfg["validation"].getboolean("api_force_redeploy", False)
        ):
            logger.error(f"Proxy: {cfg['validation']['api_name']} deployment failed.")  # noqa
            sys.exit(1)
        # CleanUp Validation Proxy Bundle
        logger.info("Cleaning Up local proxy bundle !")  # noqa
        delete_file(f"{bundle_path}/{cfg['validation']['api_name']}.zip")

        # create metric descriptor and dashboard
        if enable_gcp_metrics:
            logger.info("Creating metric descriptor")
            descriptor = create_custom_metric(metrics_project_id, metric_name)

            if enable_dashboard:
                logger.info(f"Creating dashboard in project {metrics_project_id}")  # noqa
                dashboard_title = cfg["gcp_metrics"]["dashboard_title"]
                alert_policy_name = cfg["gcp_metrics"]["alert_policy_name"]
                notification_channel_id = cfg["gcp_metrics"]["notification_channel_id"]  # noqa
                create_custom_dashboard(metrics_project_id, dashboard_title, metric_name, alert_policy_name, notification_channel_id)  # noqa

    if args.scan:
        environments = source_apigee.list_environments()
        all_target_servers = []

        # Fetch Target Servers from  Source Apigee@
        logger.info("exporting Target Servers !")
        for each_env in environments:
            target_servers = source_apigee.list_target_servers(each_env)
            target_server_args = ((each_env, each_ts) for each_ts in target_servers)  # noqa
            results = run_parallel(source_apigee.fetch_env_target_servers_parallel, target_server_args)  # noqa
            for result in results:
                _, ts_info = result
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

                for each_api in source_apigee.list_apis(each_api_type):
                    if each_api not in skip_proxy_list:
                        api_revision_map[each_api_type]["proxies"][
                            each_api
                        ] = source_apigee.list_api_revisions(each_api_type, each_api)[  # noqa
                            -1
                        ]
                    else:
                        logger.info(f"Skipping API {each_api}")

            parallel_args = (
                (
                    each_api_type,
                    each_api,
                    each_api_rev,
                    each_api_type_data["export_dir"]
                )
                for each_api_type, each_api_type_data in api_revision_map.items()  # noqa
                for each_api, each_api_rev in each_api_type_data["proxies"].items()  # noqa
            )
            logger.info("Exporting proxy target servers")
            results = run_parallel(source_apigee.fetch_api_proxy_ts_parallel, parallel_args)  # noqa

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
            logger.info("Exporting proxy target servers done")

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
                each_host, each_port = get_row_host_port(each_row, default_port)  # noqa
                ts_csv_info = {}
                ts_csv_info["host"] = each_host
                ts_csv_info["port"] = each_port
                ts_csv_info["name"] = each_host
                ts_csv_info["info"] = "_NA_"
                ts_csv_info["env"] = "_NA_"
                ts_csv_info["extracted_from"] = "Input CSV"
                all_target_servers.append(ts_csv_info)

        scan_output = {
            "all_target_servers": all_target_servers,
            "proxy_targets": proxy_targets
        }

        # upload scan output
        if state_file.startswith("file"):
            file_path = state_file.replace("file://", "")
            write_json_to_file(file_path, scan_output)
        elif state_file.startswith("gs"):
            bucket_data = state_file.split('/')
            bucket_name = bucket_data[2]
            file_path = '/'.join(bucket_data[3:])

            gcs_upload_json(gcs_project_id, bucket_name, file_path, scan_output)  # noqa

    if args.monitor:

        # extract scan outout
        if state_file.startswith("file"):
            file_path = state_file.replace("file://", "")
            scan_output = read_json_from_file(file_path)
        elif state_file.startswith("gs"):
            bucket_data = state_file.split('/')
            bucket_name = bucket_data[2]
            file_path = '/'.join(bucket_data[3:])

            scan_output = download_json_from_gcs(gcs_project_id, bucket_name, file_path)  # noqa

        if not scan_output:
            return

        all_target_servers = scan_output["all_target_servers"]
        proxy_targets = scan_output["proxy_targets"]

        # Fetch API Northbound Endpoint
        logger.info(f"Fetching VHost with name {cfg['validation']['api_hostname']} !")  # noqa
        vhost_domain_name = cfg["validation"]["api_hostname"]
        vhost_ip = cfg["validation"].get("api_ip", "").strip()
        api_url = f"https://{vhost_domain_name}/validate-target-server"

        batch_size = 5
        batches = []
        new_structure = []

        for entry in all_target_servers:
            host = entry.get('host', '')
            port = entry.get('port', '')

            if host and port:
                new_entry = {
                    'host': host,
                    'port': str(port),
                    'name': entry.get('name', ''),
                    'env': entry.get('env', ''),
                    'extracted_from': entry.get('extracted_from', ''),
                    'info': entry.get('info', '')
                }

                new_structure.append(new_entry)

                if len(new_structure) == batch_size:
                    batches.append(new_structure)
                    new_structure = []

        if new_structure:
            batches.append(new_structure)

        validator_args = (
            (
                api_url,
                vhost_domain_name,
                vhost_ip,
                json.dumps(batch),
                allow_insecure,
                proxy_targets
            )
            for batch in batches
        )

        output_reports = run_parallel(source_apigee.call_validator_proxy_parallel, validator_args)  # noqa
        final_report = []
        for output in output_reports:
            if isinstance(output, list):
                final_report.extend(output)
            else:
                logger.error(output.get("error", "Unknown Error occured while calling proxy"))  # noqa

        if enable_gcp_metrics:
            logger.info("Dumping data to stack driver")
            # get metric descriptor
            descriptor = get_metric_descriptor(metrics_project_id, metric_name)
            if descriptor:
                report_metric(metrics_project_id, descriptor, final_report)
            else:
                logger.error("Couldn't push data to stackdriver because the the existing metric descriptor couldn't be fetched.")  # noqa

        elif report_format == "md":
            report_file = "report.md"
            logger.info(f"Dumping report to file {report_file}")
            write_md_report(report_file, final_report)

        # Write CSV Report
        # TODO: support relative report path
        elif report_format == "csv":
            report_file = "report.csv"
            logger.info(f"Dumping report to file {report_file}")
            write_csv_report(report_file, final_report)


if __name__ == "__main__":
    main()
