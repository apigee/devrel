/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


const SwaggerParser = require('@apidevtools/swagger-parser');
const minimist = require('minimist')
const fs = require('fs')
const path = require('path');
const handlebars = require('handlebars');

const argv = minimist(process.argv.slice(2));
const outFolder = argv['out']
const oasPath = argv['oas']
const basepath = argv['basepath']
const name = argv['name']
const envs = argv['envs']

generateFromOAS({ outFolder, oasPath, basepath, name, envs });

/**
 * Generate Proxy Config from OAS
 *
 * @param {Object} config OAS generator config
 */
async function generateFromOAS(config) {
    try {
        const api = await SwaggerParser.validate(config.oasPath);
        api.openapi
        const oasVersionString = api.openapi || api.swagger;
        const oasVersionSplit = oasVersionString.split(".");
        const oasVersionMajor = parseInt(oasVersionSplit[0], 10);
        const proxyName = config.name || api.info.title.replace(/ /g, '-').toLowerCase();
        const basepath = config.basepath || `/${proxyName}/v1`

        // target service
        let targetService = 'https://notfound.apigee.google.com # TODO replace me'
        if (oasVersionMajor === 2 && api.host) {
            const schema = Array.isArray(api.schemes) && api.schemes.includes('https') ? 'https' : 'http';
            const basePath = api.basePath || ''
            targetService = `${schema}://${api.host}${basePath}`
        } else if (oasVersionMajor === 3 && api.servers) {
            targetService = `${api.servers[0].url}`
        }

        const operations = [];
        for (const [requestPath, pathObject] of Object.entries(api.paths || {})) {
            for (const [method, pathItem] of Object.entries(pathObject || {})) {
                operations.push({
                    id: `${method}-${pathItem.operationId.replace(/ /g, '-').toLowerCase()}`,
                    httpMethod: method.toUpperCase(),
                    requestPath: requestPath,
                    consumerAuthorization: translateOasSecurity(pathItem.security, api.components)
                })
            }
        }

        // consumer auth
        if (oasVersionMajor === 3) {
            consumerAuthorization = translateOasSecurity(api.security, api.components)
        }

        data = {
            basepath,
            operations,
            targetService,
            consumerAuthorization
        }

        const template = handlebars.compile(fs.readFileSync('./proxy.yaml.handlebars').toString());
        const generatedProxyConfig = template(data)

        // Print to file or stdout
        if (config.outFolder) {
            const proxyFolder = path.join(outFolder, 'src', 'main', 'apigee', 'apiproxies', proxyName);
            createFolderIfNotExists(proxyFolder);
            fs.writeFileSync(path.join(proxyFolder, 'proxy.yaml'), generatedProxyConfig);
            const envs = (config.envs || '').split(',')
            envs.forEach(env => {
                const envFolder = path.join(outFolder, 'src', 'main', 'apigee', 'environments', env);
                createFolderIfNotExists(envFolder);
                const envDeployments = path.join(envFolder, "deployments.json");
                let deployments = { proxies: [] }
                if (fs.existsSync(envDeployments)) {
                    deployments = JSON.parse(fs.readFileSync(envDeployments))
                }
                const uniqueProxies = new Set(deployments.proxies);
                uniqueProxies.add(proxyName);
                deployments.proxies = [...uniqueProxies];
                fs.writeFileSync(envDeployments, JSON.stringify(deployments, null, 2));
            });
        } else {
            console.log(generatedProxyConfig);
        }
    }
    catch (err) {
        console.error(err);
    }
}

/**
 * Translate OAS security object to an apigee consumer authorization
 *
 * @param {any} security
 * @param {any} components
 * @return {any} apigee consumer authorization
 */
function translateOasSecurity(security, components) {
    consumerAuthorization = { enabled: false, locations: [] };
    (security || []).forEach(securityObject => {
        Object.keys(securityObject).forEach(securityObjectKey => {
            if (components && components.securitySchemes && components.securitySchemes[securityObjectKey]) {
                const securityScheme = components.securitySchemes[securityObjectKey]
                if (securityScheme.type.toLowerCase() === "apikey") {
                    consumerAuthorization.enabled = true
                    consumerAuthorization.locations.push({ in: securityScheme.in, name: securityScheme.name});
                }
            }

        });
    });
    return consumerAuthorization
}

/**
 * Create a folder recursively if it doesn't exist
 *
 * @param {string} folderPath
 */
function createFolderIfNotExists(folderPath) {
    if (!fs.existsSync(folderPath)) {
        fs.mkdirSync(folderPath, { recursive: true })
    }
}