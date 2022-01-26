// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

'use strict';

const {apigee} = require('apigee-edge-js')
const copy = require('recursive-copy');
const {join} = require('path');
const {tmpdir} = require('os');
const {mkdtemp} = require('fs/promises');
const envsubh  = require('envsub/envsubh.js');
const zipdir = require('zip-dir');
const { logger } = require('./logger');

async function prepareZip(opts) {
    let staging_dir = await mkdtemp(join(tmpdir(), 'emg-util-'));
    let source_assets = join(__dirname, '..', 'assets', 'apiproxy').replace("file:", "");
    await copy(source_assets, join(staging_dir,'target', 'apiproxy'));

    process.env.EMG_BASEPATH = opts.basePath;
    process.env.EMG_TARGET_URL = opts.targetUrl;
    process.env.EMG_PROXY_NAME = opts.proxyName;

    let options = { all: false, diff: false, syntax: "handlebars", protect: true, system: false };
    let proxyEndpoint = join(staging_dir, 'target', 'apiproxy','proxies', 'default.xml');
    let targetEndpoint = join(staging_dir,'target', 'apiproxy', 'targets', 'default.xml');
    let mainProxy = join(staging_dir,'target', 'apiproxy', 'edgemicro_proxy.xml');

    await envsubh({templateFile:proxyEndpoint, outputFile:proxyEndpoint, options});
    await envsubh({templateFile:targetEndpoint, outputFile:targetEndpoint, options});
    await envsubh({templateFile:mainProxy, outputFile:mainProxy, options});

    let result_zip = join(staging_dir,'emg_proxy.zip');
    await zipdir(join(staging_dir,'target'), { saveTo: result_zip });

    return result_zip;
}
async function get_apigee_org(opts) {
    return apigee.connect({
        org: opts.apigee_org,
        user: opts.apigee_user,
        password: opts.apigee_pass,
        no_token: true,
        verbosity: opts.debug
    });
}

async function publish_api_proxy(opts) {
    let proxyName = opts.api_proxy_name;

    let zipFile = await prepareZip({
       basePath: opts.api_proxy_base_path,
       targetUrl: opts.target_url,
       proxyName
    });

    let org = await get_apigee_org(opts);

    let import_result = await org.proxies.import({
       name: proxyName,
       source: zipFile
    });

    let deploy_result = await org.proxies.deploy({
        name: import_result.name,
        revision: import_result.revision,
        environment: opts.apigee_env
    })

    return true;
}

async function update_api_product(opts) {
    let org = await get_apigee_org(opts);

    let api_product = await org.products.get({
        name: opts.api_product_name,
    });

    if (api_product.proxies && api_product.proxies.indexOf(opts.api_proxy_name) > 0 ) {
        return true;
    }

    api_product.proxies.push(opts.api_proxy_name);

    let update_result = await org.products.update(api_product);

    return true;
}


module.exports = { publish_api_proxy, update_api_product }