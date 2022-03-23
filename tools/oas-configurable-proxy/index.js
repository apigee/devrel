const SwaggerParser = require('@apidevtools/swagger-parser');
const minimist = require('minimist')
const fs = require('fs')
const path = require('path');
const handlebars = require('handlebars');

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
        const proxyFolder = path.join(outFolder, 'src', 'main', 'apigee', 'apiproxies', proxyName)
        const basepath = config.basepath || `/${proxyName}/v1`
        createFolderIfNotExists(proxyFolder)

        const template = handlebars.compile(fs.readFileSync('./proxy.yaml.handlebars').toString());
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
                    requestPath: requestPath
                })
            }
        }
        data = {
            basepath,
            operations,
            targetService
        }
        const generatedProxyConfig = template(data)
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
            deployments.proxies = [ ...uniqueProxies ];
            fs.writeFileSync(envDeployments, JSON.stringify(deployments, null, 2));
        });
    }
    catch (err) {
        console.error(err);
    }
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

const argv = minimist(process.argv.slice(2));
console.log(argv)
const outFolder = argv['out'] || './generated'
const oasPath = argv['oas']
const basepath = argv['basepath']
const name = argv['name']
const envs = argv['envs']
createFolderIfNotExists(outFolder)
generateFromOAS({outFolder, oasPath, basepath, name, envs});