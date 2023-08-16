#!/usr/bin/python

# Copyright 2023 Google LLC
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
from apigee import Apigee
import utils


def main():
    cfg = utils.parse_config('input.properties')
    proxy_dir = cfg['common']['input_apis']
    proxy_dest_dir = cfg['common']['processed_apis']
    proxy_bundle_directory = cfg['common']['proxy_bundle_directory']
    export_debug_file = cfg.getboolean('common', 'debug')
    validation_enabled = cfg.getboolean('validate', 'enabled')
    utils.delete_folder(proxy_dest_dir)
    utils.delete_folder(proxy_bundle_directory)
    utils.create_dir(proxy_bundle_directory)
    proxy_endpoint_count = utils.get_proxy_endpoint_count(cfg)
    proxies = utils.list_dir(proxy_dir)

    final_dict = {}
    processed_dict = {}

    for each_dir in proxies:
        each_proxy_dict = utils.read_proxy_artifacts(
                        f"{proxy_dir}/{each_dir}",
                        utils.parse_proxy_root(f"{proxy_dir}/{each_dir}")
                            )
        if len(each_proxy_dict) > 0:
            each_proxy_rel = utils.get_proxy_objects_relationships(
                each_proxy_dict)
            final_dict[each_dir] = each_proxy_dict
            processed_dict[each_dir] = each_proxy_rel

    processing_final_dict = final_dict.copy()

    path_group_map = {}
    for each_api, each_api_info in processed_dict.items():
        path_group_map[each_api] = utils.get_api_path_groups(each_api_info)

    grouped_apis = {}
    for each_api, base_path_info in path_group_map.items():
        grouped_apis[each_api] = utils.group_paths_by_path(
            base_path_info, proxy_endpoint_count)

    bundled_group = {}
    for each_api, grouped_api in grouped_apis.items():
        bundled_group[each_api] = utils.bundle_path(grouped_api)

    merged_pes = {}
    merged_objects = {}
    for each_api, grouped_api in bundled_group.items():
        print(f'Processing API => {each_api} with {len(grouped_api)} groups')
        for index, each_group in enumerate(grouped_api):
            merged_objects[f"{each_api}_{index}"] = {
                'Policies': [],
                'TargetEndpoints': [],
                'ProxyEndpoints': []
            }
            for each_path, pes in each_group.items():
                each_pe = '-'.join(pes)
                merged_pes[each_pe] = utils.merge_proxy_endpoints(
                    processing_final_dict[each_api],
                    each_path,
                    pes
                )
                merged_objects[f"{each_api}_{index}"]['Name'] = f"{final_dict[each_api]['proxyName']}_{index}"  # noqa
                merged_objects[f"{each_api}_{index}"]['Policies'].extend(  # noqa
                    [ item for pe in pes for item in processed_dict[each_api][pe]['Policies']])  # noqa
                merged_objects[f"{each_api}_{index}"]['TargetEndpoints'].extend(  # noqa
                    [ item for pe in pes for item in processed_dict[each_api][pe]['TargetEndpoints']])  # noqa
                merged_objects[f"{each_api}_{index}"]['Policies'] = list(set(merged_objects[f"{each_api}_{index}"]['Policies']))  # noqa
                merged_objects[f"{each_api}_{index}"]['TargetEndpoints'] = list(set(merged_objects[f"{each_api}_{index}"]['TargetEndpoints']))  # noqa
                merged_objects[f"{each_api}_{index}"]['ProxyEndpoints'].append(each_pe)  # noqa

    for each_api, grouped_api in bundled_group.items():
        for index, each_group in enumerate(grouped_api):
            utils.clone_proxies(
                    f"{proxy_dir}/{each_api}",
                    f"{proxy_dest_dir}/{each_api}_{index}",
                    merged_objects[f"{each_api}_{index}"],
                    merged_pes,
                    proxy_bundle_directory
            )

    files = {
        'final_dict': final_dict,
        'processed_dict': processed_dict,
        'path_group_map': path_group_map,
        'grouped_apis': grouped_apis,
        'bundled_group': bundled_group,
        'merged_pes': merged_pes,
        'merged_objects': merged_objects,
    }
    if export_debug_file:
        utils.export_debug_log(files)

    if validation_enabled:
        errors = {}
        gcp_project_id = cfg['validate']['gcp_project_id']
        x = Apigee(gcp_project_id)
        x.set_auth_header(os.getenv('APIGEE_ACCESS_TOKEN'))
        result = {}
        bundled_proxies = utils.list_dir(proxy_bundle_directory)
        for each_bundle in bundled_proxies:
            validation = x.validate_api('apis',f"{proxy_bundle_directory}/{each_bundle}")  # noqa
            if not validation:
                errors[each_bundle] = validation
            result[each_bundle] = validation
            print(f"{each_bundle}  ==> Validation : {validation}")
        if len(errors) > 0:
            print('ERROR: Some Validations have failed')
            sys.exit(1)


if __name__ == '__main__':
    main()
