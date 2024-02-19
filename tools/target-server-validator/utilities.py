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
import configparser
import zipfile
import csv
from urllib.parse import urlparse
import time
from google.api import label_pb2 as ga_label
from google.cloud import monitoring_v3
from google.api import metric_pb2 as ga_metric
import requests
import xmltodict
import urllib3
from forcediphttpsadapter.adapters import ForcedIPHTTPSAdapter
import concurrent.futures
from base_logger import logger


def parse_config(config_file):
    config = configparser.ConfigParser()
    config.read(config_file)
    return config


def zipdir(path, ziph):
    # ziph is zipfile handle
    for root, _, files in os.walk(path):
        for file in files:
            ziph.write(
                os.path.join(root, file),
                os.path.relpath(
                    os.path.join(root, file), os.path.join(path, "..")  # noqa
                ),
            )  # noqa


def create_proxy_bundle(proxy_bundle_directory, api_name, target_dir):  # noqa
    with zipfile.ZipFile(
        f"{proxy_bundle_directory}/{api_name}.zip", "w", zipfile.ZIP_DEFLATED
    ) as zipf:  # noqa
        zipdir(target_dir, zipf)


def run_validator_proxy(
    url, dns_host, vhost_ip, batch, allow_insecure=False):  # noqa
    headers = {
        "Host": dns_host,
        "Content-Type": "application/json"
    }
    if allow_insecure:
        logger.info("Skipping Certificate Verification & disabling warnings because 'allow_insecure' is set to true")  # noqa
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    session = requests.Session()
    if len(vhost_ip) > 0:
        session.mount(
            f"https://{dns_host}", ForcedIPHTTPSAdapter(dest_ip=vhost_ip)
        )  # noqa
    try:
        response = session.post(url, data=batch, verify=(not allow_insecure), headers=headers)  # noqa
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": f"{response.json().get('error','')}"}  # noqa
    except Exception as e:
        return {"error": f"{e}"}


def delete_file(file_name):
    try:
        os.remove(file_name)
    except FileNotFoundError:
        logger.warning(f"File {file_name} doesnt exist")


def write_csv_report(
    file_name,
    rows,
    header=["NAME", "TARGET_SOURCE", "HOST", "PORT", "ENV", "STATUS", "INFO"],
):  # noqa
    with open(file_name, "w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(header)
        for each_row in rows:
            writer.writerow(each_row)


def read_csv(file_name):
    read_rows = []
    try:
        with open(file_name) as file:
            rows = csv.reader(file)
            for each_row in rows:
                read_rows.append(each_row)
        if len(read_rows) != 0:
            read_rows.pop(0)
    except FileNotFoundError:
        logger.warning(f"File {file_name} not found ! ")
    return read_rows


def write_md_report(
    file_name,
    rows,
    header=["NAME", "TARGET_SOURCE", "HOST", "PORT", "ENV", "STATUS", "INFO"],
):  # noqa
    mded_rows = []
    for each_row in rows:
        mded_rows.append(" | ".join(each_row))
    mded_rows = "\n".join(mded_rows)
    data = f"""
# Apigee Target Server Health Report

{" | ".join(header)}
{" | ".join(['---' for i in range(len(header))])}
{mded_rows}
    """
    with open(file_name, "w") as file:
        file.write(data)


def create_dir(dir):
    try:
        os.makedirs(dir)
    except FileExistsError:
        logger.info(f"{dir} already exists")


def list_dir(dir, soft=False):
    try:
        return os.listdir(dir)
    except FileNotFoundError:
        if soft:
            return []
        logger.error(f"Directory '{dir}' not found")
        sys.exit(1)


def unzip_file(path_to_zip_file, directory_to_extract_to):
    with zipfile.ZipFile(path_to_zip_file, "r") as zip_ref:
        zip_ref.extractall(directory_to_extract_to)


def parse_xml(file):
    try:
        with open(file) as fl:
            doc = xmltodict.parse(fl.read())
        return doc
    except FileNotFoundError:
        logger.error(f"File '{file}' not found")
    return {}


def parse_http_target_connection(http_placement, http_placement_data):
    hosts = None
    if (
        "HTTPTargetConnection" in http_placement_data[http_placement]
        and "URL" in http_placement_data[http_placement]["HTTPTargetConnection"]  # noqa
    ):  # noqa
        url_data = urlparse(
            http_placement_data[http_placement]["HTTPTargetConnection"]["URL"]
        )  # noqa
        hosts = {
            "host": url_data.hostname,
            "port": str(url_data.port)
            if url_data.port is not None
            else ("443" if url_data.scheme == "https" else "80"),  # noqa
            "source": f"{http_placement} : {http_placement_data[http_placement]['@name']}",  # noqa
            "target_server": False,
        }
    if (
        "HTTPTargetConnection" in http_placement_data[http_placement]
        and "LoadBalancer"  # noqa
        in http_placement_data[http_placement]["HTTPTargetConnection"]
    ):  # noqa
        servers = http_placement_data[http_placement]["HTTPTargetConnection"][
            "LoadBalancer"
        ][
            "Server"
        ]  # noqa
        servers_list = servers if type(servers) is list else [servers]  # noqa
        target_servers = [ts["@name"] for ts in servers_list]  # noqa
        hosts = {
            "host": target_servers,
            "port": "",
            "source": f"{http_placement} : {http_placement_data[http_placement]['@name']}",  # noqa
            "target_server": True,
        }
    return hosts


def parse_proxy_hosts(proxy_path):
    policies_path = f"{proxy_path}/policies"
    targets_path = f"{proxy_path}/targets"
    policies = [i for i in list_dir(policies_path, True) if i.endswith(".xml")]  # noqa
    targets = [i for i in list_dir(targets_path, True) if i.endswith(".xml")]  # noqa
    hosts = []
    for each_policy in policies:
        each_policy_info = parse_xml(f"{policies_path}/{each_policy}")  # noqa
        if "ServiceCallout" in each_policy_info:
            host_data = parse_http_target_connection(
                "ServiceCallout", each_policy_info
            )  # noqa
            if host_data is not None:
                hosts.append(host_data)
    for each_target in targets:
        each_target_info = parse_xml(f"{targets_path}/{each_target}")  # noqa
        host_data = parse_http_target_connection(
            "TargetEndpoint", each_target_info
        )  # noqa
        if host_data is not None:
            hosts.append(host_data)
    return hosts


def has_templating(data):
    if "{" in data and "}" in data:
        return True
    else:
        return False


def get_tes(data):
    tes = []
    for each_host in data:
        if each_host["target_server"]:
            tes.extend(each_host["host"])
    return tes


def get_row_host_port(row, default_port=443):
    host, port = None, None
    if len(row) == 0:
        logger.warning("Input row has no host.")
    if len(row) == 1:
        host, port = row[0], default_port
    if len(row) > 1:
        host, port = row[0], row[1]
    return host, port


def run_parallel(func, args, workers=10):
    with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as executor:  # noqa
        future_list = {executor.submit(func, arg) for arg in args}

    data = []
    for future in concurrent.futures.as_completed(future_list):
        try:
            data.append(future.result())
        except Exception:
            exception_info = future.exception()
            if exception_info is not None:
                error_message = str(exception_info)
                logger.error(f"Error message: {error_message}")
            else:
                logger.info("No exception information available.")
            logger.error(f"{future} generated an exception")
    return data


def create_custom_metric(project_id, metric_name):
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/{project_id}"

    # Create metric descriptor
    descriptor = ga_metric.MetricDescriptor()
    descriptor.type = metric_name
    descriptor.metric_kind = ga_metric.MetricDescriptor.MetricKind.GAUGE
    descriptor.value_type = ga_metric.MetricDescriptor.ValueType.BOOL
    descriptor.labels.extend([
        ga_label.LabelDescriptor(key='hostname', value_type='STRING'),
        ga_label.LabelDescriptor(key='status', value_type='STRING')
    ])
    try:
        descriptor = client.create_metric_descriptor(name=project_name, metric_descriptor=descriptor)  # noqa
        return descriptor
    except Exception as e:
        logger.error(f"Error while creating the metric descriptor. ERROR-INFO: {e}")  # noqa
    return None


def report_metric(project_id, metric_descriptor, sample_data):
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/{project_id}"

    series = monitoring_v3.TimeSeries()

    # Check if metric descriptor exists
    if not metric_descriptor:
        logger.error("Error while pushing the data to stackdriver. ERROR-INFO: Metric descriptor does not exist.")  # noqa
        return

    series.metric.type = metric_descriptor.type
    series.resource.type = 'global'

    now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10 ** 9)
    interval = monitoring_v3.TimeInterval({'end_time': {'seconds': seconds, 'nanos': nanos}})  # noqa

    try:
        for data in sample_data:
            status = True if data[5] == 'REACHABLE' else False

            point = monitoring_v3.Point({'interval': interval, 'value': {'bool_value': status}})  # noqa
            series.metric.labels['hostname'] = data[2]
            series.metric.labels['status'] = data[5]
            series.points = [point]

            client.create_time_series(name=project_name, time_series=[series])
            logger.debug(f"Pushed to stackdriver - {data[2]} {data[5]}")

        logger.info("Successfully pushed data to stackdriver")
    except Exception as e:
        logger.error(f"Error while pushing the data to stackdriver. ERROR-INFO: {e}")  # noqa
