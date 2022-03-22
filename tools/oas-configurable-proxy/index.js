const SwaggerParser = require("@apidevtools/swagger-parser");
const minimist = require('minimist')
const fs = require('fs')
const path = require('path');
const handlebars = require("handlebars");

/**
 *
 * @param {String} outFolder Path of configurable proxy archive
 * @param {*} oasPath Path to OAS file
 */
async function generateFromOAS(outFolder, oasPath) {
    try {
        const api = await SwaggerParser.validate(oasPath);
        const proxyName = api.info.title.replace(/ /g, '-').toLowerCase();
        const proxyFolder = path.join(outFolder, "src", "main", "apigee", "apiproxies", proxyName)
        _createFolderIfNotExists(proxyFolder)

        const template = handlebars.compile(fs.readFileSync("./proxy.yaml.handlebars").toString());

        const schema = Array.isArray(api.schemes) && api.schemes.includes('https') ? 'https' : 'http';
        const hostName = api.host || 'notfound.apigee.google.com # TODO replace me'
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
            basepath: '/foo',
            operations: operations,
            target: `${schema}://${hostName}`
        }
        const generatedProxyConfig = template(data)
        fs.writeFileSync(path.join(proxyFolder, "proxy.yaml"), generatedProxyConfig)
    }
    catch (err) {
        console.error(err);
    }
}

function _createFolderIfNotExists(folderPath) {
    if (!fs.existsSync(folderPath)) {
        fs.mkdirSync(folderPath, { recursive: true })
    }
}

function ensureFolderStructure(rootFolder) {
    _createFolderIfNotExists(rootFolder)
    _createFolderIfNotExists(path.join(rootFolder, "src", "main", "apigee", "environments"))
}

const argv = minimist(process.argv.slice(2));
const outFolder = argv['out'] || './generated'
ensureFolderStructure(outFolder);
generateFromOAS(outFolder, argv['oas']);