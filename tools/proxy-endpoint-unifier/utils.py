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

import configparser
import os
import sys
import xmltodict
import json
import shutil
import zipfile
import requests

APIGEE_PROXY_ENDPOINT_LIMIT=10

def is_token_valid(token):
    """Checks if an access token is valid.

    Args:
        token: The access token to validate.

    Returns:
        True if the token is valid, \
        False otherwise.
    """
    url = f"https://www.googleapis.com/oauth2/v1/tokeninfo?access_token={token}"  # noqa
    r = requests.get(url, timeout=5)
    if r.status_code == 200:
        response_json = r.json()
        if 'email' not in response_json:
            response_json['email'] = ''
        print(f"Token Validated for user {response_json['email']}")  # noqa pylint: disable=W1203
        return True
    print(f"Token expired or invalid. Please run export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)")
    sys.exit(1)

def parse_config(config_file):
    config = configparser.ConfigParser()
    config.read(config_file)
    return config

def get_proxy_endpoint_count(cfg):
    try:
        proxy_endpoint_count = cfg.getint('common', 'proxy_endpoint_count')
        if not (proxy_endpoint_count > 0 and proxy_endpoint_count <= APIGEE_PROXY_ENDPOINT_LIMIT):
            print(f'ERROR: Proxy Endpoints should be > Zero(0)  &  {APIGEE_PROXY_ENDPOINT_LIMIT}')
            sys.exit(1)
    except ValueError:
        print('proxy_endpoint_count should be a Number')
        sys.exit(1)
    return proxy_endpoint_count


def create_dir(dir):
    try:
        os.makedirs(dir)
    except FileExistsError:
        print(f"INFO: {dir} already exists")


def list_dir(dir, isok=False):
    try:
        return os.listdir(dir)
    except FileNotFoundError:
        if isok:
            print(f"Ignoring: Directory \"{dir}\" not found")
            return []
        print(f"ERROR: Directory \"{dir}\" not found")
        sys.exit(1)


def get_proxy_entrypoint(dir):
    files = list_dir(dir)
    ent = []
    for eachfile in files:
        if eachfile.endswith(".xml"):
            ent.append(eachfile)
    if len(ent) == 1:
        return os.path.join(dir, ent[0])
    else:
        if len(ent) > 1:
            print(f"ERROR: Directory \"{dir}\" contains multiple xml files at root")  # noqa
        else:
            print(f"ERROR: Directory \"{dir}\" has no xml file at root")  # noqa
    return None


def get_proxy_files(dir, file_type='proxies'):
    target_dir = os.path.join(dir, file_type)
    files = list_dir(target_dir)
    xml_files = []
    for eachfile in files:
        if eachfile.endswith(".xml"):
            xml_files.append(os.path.splitext(eachfile)[0])
    if len(xml_files) == 0:
        print(f"ERROR: Directory \"{target_dir}\" has no xml files")  # noqa
        return []
    else:
        return xml_files


def parse_json(file):
    try:
        with open(file) as fl:
            doc = json.loads(fl.read())
        return doc
    except FileNotFoundError:
        print(f"ERROR: File \"{file}\" not found")
    return {}


def parse_xml(file):
    try:
        with open(file) as fl:
            doc = xmltodict.parse(fl.read())
        return doc
    except FileNotFoundError:
        print(f"ERROR: File \"{file}\" not found")
    return {}


def write_json(file, data):
    try:
        with open(file, 'w') as fl:
            fl.write(json.dumps(data, indent=2))
    except FileNotFoundError:
        print(f"ERROR: File \"{file}\" not found")
        return False
    return True


def write_xml_from_dict(file, data):
    try:
        with open(file, 'w') as fl:
            fl.write(xmltodict.unparse(data, pretty=True))
    except FileNotFoundError:
        print(f"ERROR: File \"{file}\" not found")
        return False
    return True


def parse_proxy_root(dir):
    file = get_proxy_entrypoint(dir)
    if file is None:
        return {}
    doc = parse_xml(file)
    api_proxy = doc.get('APIProxy', {})
    proxy_endpoints = api_proxy.get('ProxyEndpoints', {}).get('ProxyEndpoint', {})  # noqa
    target_endpoints = api_proxy.get('TargetEndpoints', {}).get('TargetEndpoint', {})  # noqa
    policies = {} if api_proxy.get('Policies', {}) is None else api_proxy.get('Policies', {}).get('Policy', {})  # noqa
    if len(proxy_endpoints) == 0:
        print('Proceeding with Filesystem parse of ProxyEndpoints')
        doc['APIProxy']['ProxyEndpoints'] = {}
        proxies = get_proxy_files(dir)
        doc['APIProxy']['ProxyEndpoints']['ProxyEndpoint'] = proxies
    else:
        print('Skipping with Filesystem parse of ProxyEndpoints')
    if len(target_endpoints) == 0:
        print('Proceeding with Filesystem parse of TargetEndpoints')
        doc['APIProxy']['TargetEndpoints'] = {}
        targets = get_proxy_files(dir, 'targets')
        doc['APIProxy']['TargetEndpoints']['TargetEndpoint'] = targets
    else:
        print('Skipping with Filesystem parse of TargetEndpoints')
    if len(policies) == 0:
        print('Proceeding with Filesystem parse of Policies')
        doc['APIProxy']['Policies'] = {}
        policies_list = get_proxy_files(dir, 'policies')
        doc['APIProxy']['Policies']['Policy'] = policies_list
    else:
        print('Skipping with Filesystem parse of Policies')
    return doc


def read_proxy_artifacts(dir, entrypoint):
    APIProxy = entrypoint['APIProxy']
    # Check if proxy has multiple endpoints
    if isinstance(APIProxy['ProxyEndpoints']['ProxyEndpoint'], list):
        proxyName = entrypoint['APIProxy']['@name']
        proxy_dict = {
            'ProxyEndpoints': {},
            'TargetEndpoints': {},
            'proxyName': proxyName
        }
        ProxyEndpoints = APIProxy['ProxyEndpoints']['ProxyEndpoint']
        ProxyEndpoints = ([ProxyEndpoints] if isinstance(ProxyEndpoints,str) else ProxyEndpoints)  # noqa
        for each_pe in ProxyEndpoints:
            proxy_dict['ProxyEndpoints'][each_pe] = parse_xml(os.path.join(dir,'proxies',f"{each_pe}.xml"))  # noqa

        TargetEndpoints = APIProxy['TargetEndpoints']['TargetEndpoint']
        TargetEndpoints = ([TargetEndpoints] if isinstance(TargetEndpoints,str) else TargetEndpoints)  # noqa
        for each_te in TargetEndpoints:
            proxy_dict['TargetEndpoints'][each_te]=parse_xml(os.path.join(dir,'targets',f"{each_te}.xml"))  # noqa

    # Skip when proxy has one endpoints
    else:
        print(f"Skipping Proxy ==> {entrypoint['APIProxy']['@name']}")
        return {}
    return proxy_dict


def get_all_policies_from_step(Step):
    policies = []
    StepData = ([Step] if isinstance(Step, dict) else Step)
    for eachStep in StepData:
        policies.append(eachStep['Name'])
    return policies


def get_all_policies_from_flow(flow, fault_rule=False):  # noqa pylint: disable=R0912
    """Retrieves all policies from a flow.

    Args:
        Flow: Flow data dictionary.
        fault_rule: Boolean indicating \
        whether to
            process fault rules.

    Returns:
        A list of policy names.
    """
    policies = []

    if not fault_rule:
        if flow.get('Request'):
            if isinstance(flow['Request'], list) and len(flow['Request']) > 0:
                flow['Request'] = flow['Request'][0]
            request = ([] if flow['Request'] is None else (
                        [] if flow['Request'].get('Step') is None else
                        (
                            [flow['Request']['Step']] if isinstance(flow['Request']['Step'], dict)    # noqa pylint: disable=C0301
                            else flow['Request']['Step']
                        )))
        else:
            request = []
        if flow.get('Response'):
            if (isinstance(flow['Response'], list) and
                    len(flow['Response']) > 0):
                flow['Response'] = flow['Response'][0]
            response = ([] if flow['Response'] is None else (
                            [] if flow['Response'].get('Step') is None else
                            (
                            [flow['Response']['Step']] if isinstance(flow['Response']['Step'], dict)   # noqa pylint: disable=C0301
                                else flow['Response']['Step']
                            )))
        else:
            response = []
        for each_flow in request:
            policies.extend(get_all_policies_from_step(each_flow))
        for each_flow in response:
            policies.extend(get_all_policies_from_step(each_flow))
    else:
        if flow is None:
            fault_rules = []
        elif flow.get('FaultRule', None) is None:
            fault_rules = []
        else:
            fault_rules = (
                [flow['FaultRule'].get('Step')] if isinstance(flow['FaultRule'].get('Step'), dict)  # noqa
                else flow['FaultRule'].get('Step')
            )
        for each_step in fault_rules:
            policies.extend(get_all_policies_from_step(each_step))
    return policies



def get_all_policies_from_endpoint(endpointData, endpointType):
    policies = []
    policies.extend(
        get_all_policies_from_flow(
            endpointData[endpointType]['PreFlow']
        )
    )
    policies.extend(
        get_all_policies_from_flow(
            endpointData[endpointType]['PostFlow']
        )
    )

    if (endpointType == 'ProxyEndpoint' and
            'PostClientFlow' in endpointData[endpointType]):
        policies.extend(
            get_all_policies_from_flow(
                endpointData[endpointType]['PostClientFlow']
            )
        )

    Flows = (
            [] if endpointData[endpointType]['Flows'] is None else (
                [endpointData[endpointType]['Flows']['Flow']] if isinstance(
                    endpointData[endpointType]['Flows']['Flow'],
                    dict)
                else
                endpointData[endpointType]['Flows']['Flow']
            ))

    for eachFlow in Flows:
        policies.extend(
            get_all_policies_from_flow(
                eachFlow
            )
        )
    if 'DefaultFaultRule' in endpointData[endpointType]:
        policies.extend(
            get_all_policies_from_flow(endpointData[endpointType]['DefaultFaultRule'], True)  # noqa
        )
    if 'FaultRules' in endpointData[endpointType]:
        policies.extend(
            get_all_policies_from_flow(endpointData[endpointType]['FaultRules'], True)  # noqa
        )
    return policies


def get_target_endpoints(ProxyEndpointData):
    target_endpoints = []
    routes = (
            [ProxyEndpointData['RouteRule']]
            if isinstance(ProxyEndpointData['RouteRule'], dict)
            else ProxyEndpointData['RouteRule']
        )
    for eachRoute in routes:
        if 'TargetEndpoint' in eachRoute:
            target_endpoints.append(eachRoute['TargetEndpoint'])
    return target_endpoints


def get_proxy_objects_relationships(proxy_dict):
    proxy_object_map = {}
    ProxyEndpoints = proxy_dict['ProxyEndpoints']
    for ProxyEndpoint, ProxyEndpointData in ProxyEndpoints.items():
        proxy_object_map[ProxyEndpoint] = {}
        target_endpoints = get_target_endpoints(ProxyEndpointData['ProxyEndpoint'])  # noqa
        TargetEndpointsData = {te: proxy_dict['TargetEndpoints'][te] for te in target_endpoints}  # noqa
        policies = []
        policies.extend(get_all_policies_from_endpoint(ProxyEndpointData, 'ProxyEndpoint'))  # noqa
        for _, each_te in TargetEndpointsData.items():
            policies.extend(get_all_policies_from_endpoint(each_te, 'TargetEndpoint'))  # noqa
        proxy_object_map[ProxyEndpoint] = {
            'Policies': policies,
            'BasePath': ProxyEndpointData['ProxyEndpoint']['HTTPProxyConnection']['BasePath'],  # noqa
            'TargetEndpoints': target_endpoints,
        }
    return proxy_object_map


def get_api_path_groups(each_api_info):
    api_path_group_map = {}
    for pe, pe_info in each_api_info.items():
        if pe_info['BasePath'] is None:
            if '_null_' in api_path_group_map:
                api_path_group_map['_null_'].append({pe: None})
            else:
                api_path_group_map['_null_'] = [{pe: None}]
        else:
            base_path_split = [ i for i in pe_info['BasePath'].split('/') if i !=  ""]  # noqa
            if base_path_split[0] in api_path_group_map:
                api_path_group_map[base_path_split[0]].append(
                    {pe: base_path_split[0]})
            else:
                api_path_group_map[base_path_split[0]] = [{pe: base_path_split[0]}]  # noqa
    return api_path_group_map


def group_paths_by_path(api_info, pe_count_limit):
    result = []
    paths = list(api_info.keys())
    path_count = len(paths)
    if path_count > pe_count_limit:
        for i in range(0, path_count, pe_count_limit):
            each_result = []
            if i+pe_count_limit > path_count:
                for k in paths[i:path_count]:
                    each_result.extend(api_info[k])
            else:
                for k in paths[i:i+pe_count_limit]:
                    each_result.extend(api_info[k])
            result.append(each_result)
    else:
        each_result = []
        for _, v in api_info.items():
            each_result.extend(v)
        result.append(each_result)
    return result


def bundle_path(each_group_bundle):
    outer_group = []
    for each_group in each_group_bundle:
        subgroups = {}
        for each_pe in each_group:
            path = list(each_pe.values())[0]
            proxy_ep = list(each_pe.keys())[0]
            if path in subgroups:
                subgroups[path].append(proxy_ep)
            else:
                subgroups[path] = [proxy_ep]
        outer_group.append(subgroups)
    return outer_group


def apply_condition(step, condition):
    step_or_rule = step.copy()
    if 'Condition' in step_or_rule:
        if step_or_rule['Condition'] is None:
            step_or_rule['Condition'] = condition
        elif len(step_or_rule['Condition'].strip()) > 0:
            if step_or_rule['Condition'].strip().startswith('('):
                step_or_rule['Condition'] = f"{condition} and {step_or_rule['Condition']}"  # noqa
            else:
                step_or_rule['Condition'] = f"{condition} and {step_or_rule['Condition']}"  # noqa
        else:
            step_or_rule['Condition'] = condition
    else:
        step_or_rule['Condition'] = condition
    return step_or_rule


def process_steps(step, condition):
    processed_step = []
    if step is None:
        return processed_step
    elif isinstance(step['Step'], dict):
        processed_step = [apply_condition(step['Step'], condition)]
    elif isinstance(step['Step'], list):
        processed_step = [apply_condition(i, condition) for i in step['Step']]
    else:
        return processed_step
    return processed_step


def process_flow(flow, condition):
    """Processes flows with conditions.


    Args:
        flow (dict): flow dictionary
        condition (str): condition string

    Returns:
        dict: processed flow dictionary.
    """
    processed_flow = flow.copy()
    
    if flow.get('Request', None) is not None:
        Step = flow.get('Request', None).get('Step', None)
        if Step is not None: 
            processed_flow['Request']['Step'] = process_steps(flow['Request'],
                                                          condition)
    if flow.get('Response', None) is not None:
        Step = flow.get('Response', None).get('Step', None)
        if Step is not None:
            processed_flow['Response']['Step'] = process_steps(flow['Response'],
                                                           condition)
    processed_flow_with_condition = apply_condition(processed_flow,
                                                    condition)
    return processed_flow_with_condition


def process_route_rules(route_rules, condition):
    processed_rr = []
    for each_rr in (route_rules if isinstance(route_rules, list)
                    else [route_rules]):
        each_processed_rr = apply_condition(each_rr, condition)
        processed_rr.append(each_processed_rr)
    return processed_rr


def merge_proxy_endpoints(api_dict, basepath, pes):
    """Merges multiple proxy endpoints \
    into one.

    Args:
        api_dict (dict): The API \
        dictionary.
        basepath (str): The base path \
        for the merged
            endpoint.
        pes (list): List of proxy \
        endpoints to merge.

    Returns:
        dict: The merged proxy endpoint.
    """
    merged_pe = {'ProxyEndpoint': {}}
    for each_pe, each_pe_info in api_dict['ProxyEndpoints'].items():
        if each_pe in pes:
            original_basepath = each_pe_info['ProxyEndpoint']['HTTPProxyConnection']['BasePath']   # noqa pylint: disable=C0301
            # TODO : Build full Request path   # noqa pylint: disable=W0511
            condition = (original_basepath if original_basepath is None else f'(request.path Matches "{original_basepath}*")')   # noqa pylint: disable=C0301
            copied_flows = (
                None if each_pe_info['ProxyEndpoint']['Flows'] is None else each_pe_info['ProxyEndpoint']['Flows'].copy()   # noqa pylint: disable=C0301
            )
            original_flows = ([] if copied_flows is None else
                              ([copied_flows['Flow']] if isinstance(copied_flows['Flow'], dict) else copied_flows['Flow']))   # noqa pylint: disable=C0301

            if len(merged_pe['ProxyEndpoint']) == 0:
                merged_pe['ProxyEndpoint'] = {
                    '@name': [],
                    'Description': None,
                    'FaultRules': None,
                    'PreFlow': {
                        '@name': 'PreFlow',
                        'Request': {'Step': []},
                        'Response': {'Step': []},
                    },
                    'PostFlow': {
                        '@name': 'PostFlow',
                        'Request': {'Step': []},
                        'Response': {'Step': []},
                    },
                    'Flows': {'Flow': []},
                    'HTTPProxyConnection': {'BasePath': '',
                                            'Properties': {},
                                            'VirtualHost': ''},
                    'RouteRule': []
                }

                merged_pe['ProxyEndpoint']['Description'] = each_pe_info['ProxyEndpoint']['Description']   # noqa pylint: disable=C0301
                merged_pe['ProxyEndpoint']['FaultRules'] = each_pe_info['ProxyEndpoint']['FaultRules']   # noqa pylint: disable=C0301
                merged_pe['ProxyEndpoint']['HTTPProxyConnection']['BasePath'] = (basepath if basepath is None else f'/{basepath}')   # noqa pylint: disable=C0301
                if len(merged_pe['ProxyEndpoint']['HTTPProxyConnection']['Properties']) != 0:
                    merged_pe['ProxyEndpoint']['HTTPProxyConnection']['Properties'] = each_pe_info['ProxyEndpoint']['HTTPProxyConnection']['Properties']   # noqa pylint: disable=C0301
                merged_pe['ProxyEndpoint']['HTTPProxyConnection']['VirtualHost'] = each_pe_info['ProxyEndpoint']['HTTPProxyConnection']['VirtualHost']   # noqa pylint: disable=C0301

            merged_pe['ProxyEndpoint']['@name'].append(each_pe_info['ProxyEndpoint']['@name'])   # noqa pylint: disable=C0301
            merged_pe['ProxyEndpoint']['RouteRule'].extend(
                    process_route_rules(each_pe_info['ProxyEndpoint']['RouteRule'], condition)   # noqa pylint: disable=C0301
            )
            merged_pe['ProxyEndpoint']['PreFlow']['Request']['Step'].extend(
                process_steps(each_pe_info['ProxyEndpoint']['PreFlow']['Request'], condition)   # noqa pylint: disable=C0301
            )
            merged_pe['ProxyEndpoint']['PreFlow']['Response']['Step'].extend(
                process_steps(each_pe_info['ProxyEndpoint']['PreFlow']['Response'], condition)   # noqa pylint: disable=C0301
            )
            merged_pe['ProxyEndpoint']['PostFlow']['Request']['Step'].extend(
                process_steps(each_pe_info['ProxyEndpoint']['PostFlow']['Request'], condition)   # noqa pylint: disable=C0301
            )
            merged_pe['ProxyEndpoint']['PostFlow']['Response']['Step'].extend(
                process_steps(each_pe_info['ProxyEndpoint']['PostFlow']['Response'], condition)   # noqa pylint: disable=C0301
            )
            if 'PostClientFlow' in each_pe_info['ProxyEndpoint']:
                merged_pe['ProxyEndpoint']['PostClientFlow'] = {
                    '@name': 'PostClientFlow',
                    'Request': {'Step': []},
                    'Response': {'Step': []},
                }
                merged_pe['ProxyEndpoint']['PostClientFlow']['Response']['Step'].extend(  # noqa
                    process_steps(each_pe_info['ProxyEndpoint']['PostClientFlow']['Response'], None)   # noqa pylint: disable=C0301
                )
            for each_flow in original_flows:
                merged_pe['ProxyEndpoint']['Flows']['Flow'].append(
                    process_flow(each_flow, condition)
                )
    merged_pe['ProxyEndpoint']['@name'] = basepath.strip().replace('/','')
    return merged_pe

def copy_folder(src, dst):
    try:
        shutil.copytree(src, dst)
    except FileNotFoundError as e:
        print(e)
        sys.exit(1)


def delete_folder(src):
    try:
        shutil.rmtree(src)
    except FileNotFoundError as e:
        print(f'Ignoring : {e}')
        return


def delete_file(src):
    try:
        os.remove(src)
    except FileNotFoundError as e:
        print(f'Ignoring : {e}')
        return


def clean_up_artifacts(target_dir, artifacts_to_retains):
    for file in list_dir(target_dir, True):
        each_policy_file = file.split('.xml')[0]
        if each_policy_file not in artifacts_to_retains:
            delete_file(f"{target_dir}/{file}")


def filter_objects(obj_data, obj_type, targets):
    result = None
    if obj_data is None:
        return result
    elif isinstance(obj_data[obj_type], str):
        result = ({ obj_type: obj_data[obj_type] } if obj_data[obj_type] in targets else None )  # noqa
    elif isinstance(obj_data[obj_type], list):
        result = {obj_type: [v for v in obj_data[obj_type] if v in targets]}
    else:
        return result
    return result


def zipdir(path, ziph):
    # ziph is zipfile handle
    for root, dirs, files in os.walk(path):
        for file in files:
            ziph.write(os.path.join(root, file),
                       os.path.relpath(os.path.join(root, file),
                                       os.path.join(path, '..')))


def clone_proxies(source_dir, target_dir,
                  objects, merged_pes, proxy_bundle_directory):
    target_dir = f"{target_dir}/apiproxy"
    copy_folder(source_dir, target_dir)
    file = get_proxy_entrypoint(target_dir)
    # root = parse_xml(file)
    root = parse_proxy_root(target_dir)
    delete_file(file)
    root['APIProxy']['@name'] = objects['Name']
    root['APIProxy']['Policies'] = filter_objects(
        root['APIProxy']['Policies'], 'Policy', objects['Policies'])
    root['APIProxy']['TargetEndpoints'] = filter_objects(
        root['APIProxy']['TargetEndpoints'], 'TargetEndpoint', objects['TargetEndpoints'])  # noqa
    clean_up_artifacts(f"{target_dir}/policies", objects['Policies'])
    clean_up_artifacts(f"{target_dir}/targets", objects['TargetEndpoints'])
    for pe in objects['ProxyEndpoints']:
        write_xml_from_dict(f"{target_dir}/proxies/{pe}.xml", merged_pes[pe])
    clean_up_artifacts(f"{target_dir}/proxies", objects['ProxyEndpoints'])
    root['APIProxy']['ProxyEndpoints'] = {'ProxyEndpoint': (
        objects['ProxyEndpoints'] if len(objects['ProxyEndpoints']) > 1 else objects['ProxyEndpoints'][0] )}  # noqa
    transformed_file = file.split('/')
    transformed_file[-1] = f"{objects['Name']}.xml"
    write_xml_from_dict("/".join(transformed_file), root)
    delete_folder(f"{target_dir}/manifests")
    with zipfile.ZipFile(f"{proxy_bundle_directory}/{objects['Name']}.zip", 'w', zipfile.ZIP_DEFLATED) as zipf:  # noqa
        zipdir(target_dir, zipf)


def export_debug_log(files, log_path='logs'):
    create_dir(log_path)
    for file, data in files.items():
        file_name = f'{log_path}/{file}.json'
        write_json(file_name, data)
