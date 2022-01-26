#!/usr/bin/env node

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

const { publish_api_proxy, update_api_product } = require('./index.js');
const { logger } = require('./logger.js');
const yargs = require('yargs');
const { hideBin } = require('yargs/helpers');
const process = require('process');

const argv = yargs(hideBin(process.argv))
    .command('publish-proxy', 'Add a new EMG API Proxy to Apigee Edge',
        (yargs) => {
            return yargs
                .option('n', {
                    alias: 'api-proxy-name',
                    describe: 'EMG API Proxy Name',
                    required: true
                })
                .option('b', {
                    alias: 'api-proxy-base-path',
                    describe: 'EMG API Proxy Base Path',
                    required: true
                })
                .option('t', {
                    alias: 'target-url',
                    describe: 'EMG API Proxy Target URL',
                    required: true,
                })
                .option('o', {
                    alias: 'apigee-org',
                    describe: 'Apigee Edge Org',
                    required: true,
                })
                .option('e', {
                    alias: 'apigee-env',
                    describe: 'Apigee Edge Env',
                    required: true,
                })
                .option('u', {
                    alias: 'apigee-user',
                    describe: 'Apigee Edge Username',
                    required: true,
                })
                .option('p', {
                    alias: 'apigee-pass',
                    describe: 'Apigee Edge Password',
                    required: true,
                })
                .option('d', {
                    alias: 'debug',
                    describe: 'Show debug messages',
                    default: false,
                    type: "boolean",
                    required: false,
                })
                .option('h', {
                    alias: 'help'
                })
                .version(false)
                .help(true)
        },
        async ({
                   "api-proxy-name": api_proxy_name,
                   "api-proxy-base-path": api_proxy_base_path,
                   "target-url": target_url,
                   "apigee-org": apigee_org,
                   "apigee-env": apigee_env,
                   "apigee-user": apigee_user,
                   "apigee-pass": apigee_pass,
                   "debug": debug
               }) => {
            try {
                let result = await publish_api_proxy({
                    api_proxy_name,
                    api_proxy_base_path,
                    target_url,
                    apigee_org,
                    apigee_env,
                    apigee_user,
                    apigee_pass,
                    debug
                });
            } catch (ex) {
                logger.error(ex.stack);
                process.exit(1);
            }
        })
    .command('update-product', 'Adds a API Proxy to an existing Product',
        (yargs) => {
            return yargs
                .option('n', {
                    alias: 'api-product-name',
                    describe: 'EMG API Proxy Name',
                    required: true
                })
                .option('a', {
                    alias: 'api-proxy-name',
                    describe: 'API Proxy Name',
                    required: true
                })
                .option('o', {
                    alias: 'apigee-org',
                    describe: 'Apigee Edge Org',
                    required: true,
                })
                .option('e', {
                    alias: 'apigee-env',
                    describe: 'Apigee Edge Env',
                    required: true,
                })
                .option('u', {
                    alias: 'apigee-user',
                    describe: 'Apigee Edge Username',
                    required: true,
                })
                .option('p', {
                    alias: 'apigee-pass',
                    describe: 'Apigee Edge Password',
                    required: true,
                })
                .option('d', {
                    alias: 'debug',
                    describe: 'Show debug messages',
                    default: false,
                    type: "boolean",
                    required: false,
                })
                .option('h', {
                    alias: 'help'
                })
                .version(false)
                .help(true)
        },
        async ({
                   "api-product-name": api_product_name,
                   "api-proxy-name": api_proxy_name,
                   "apigee-org": apigee_org,
                   "apigee-env": apigee_env,
                   "apigee-user": apigee_user,
                   "apigee-pass": apigee_pass,
                   "debug": debug
               }) => {
            try {
                let result = await update_api_product({
                    api_product_name,
                    api_proxy_name,
                    apigee_org,
                    apigee_env,
                    apigee_user,
                    apigee_pass,
                    debug
                });
            } catch (ex) {
                logger.error(ex.stack);
                process.exit(1);
            }
        })
    .option('h', {
        alias: 'help'
    })
    .version(false)
    .help(true)
    .demandCommand()
    .parse();

module.exports = {argv}