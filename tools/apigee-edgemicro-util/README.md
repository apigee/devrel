# Apigee Edge Micro Util

This tool has two main functions:

1. Lets you publish & Deploy and API Proxy to Apigee X by just passing the "Base Path", and "Target URL"  

2. Lets update an API Product in Apigee Edge to have a specific API Proxy included.

These two functions are useful when automating the management of API Proxies that are meant to be used with Apigee Edge MicroGateway

## How to Build The Tool Binary

There is a build script "build.sh" included, that packages a node module into a single binary. 

1. Make sure node, and NPM are in the path (at least Node.js  v12)
2. Then run the `build.sh` script within the same directory

Once the build completes, you will see a binary under the `dist/Linux` or `dist/Darwin` (MacOS), depending on your operating system.

## How to use the Tool

The tool exposes two commands "publish-proxy", and "update-product". 

```
Commands:
  emg-util publish-proxy   Add a new EMG API Proxy to Apigee Edge
  emg-util update-product  Adds a API Proxy to an existing Product

```

### Publish Proxy

This command is meant to allow to publish a simple API Proxy to Apigee Edge. The API Proxy has no policies. It's a simple pass-through to the specified "Target URL". This is on purpose, as that's how Apigee Edge MicroGateway API Proxies work.

```
emg-util publish-proxy

Add a new EMG API Proxy to Apigee Edge

Options:
  -h, --help, --help         Show help                                 [boolean]
  -n, --api-proxy-name       EMG API Proxy Name                       [required]
  -b, --api-proxy-base-path  EMG API Proxy Base Path                  [required]
  -t, --target-url           EMG API Proxy Target URL                 [required]
  -o, --apigee-org           Apigee Edge Org                          [required]
  -e, --apigee-env           Apigee Edge Env                          [required]
  -u, --apigee-user          Apigee Edge Username                     [required]
  -p, --apigee-pass          Apigee Edge Password                     [required]
  -d, --debug                Show debug messages      [boolean] [default: false]

```

Example:
```
emg-util publish-proxy -n edgemicro_foobar -b /foo/bar -t https://example.com -o demo1337 -e test -u yourusername@acme.com -p "SuperSecret123!"

```
Note, that the tool will not add the "edgemicro_" prefix to the API Proxy name. You have to explicitly put it in the API proxy name when invoking the command. 


### Update API Product

This command adds the specified API Proxy (by name) to the list of API Proxies under a specific API Product.
```
emg-util update-product

Adds a API Proxy to an existing Product

Options:
  -h, --help, --help      Show help                                    [boolean]
  -n, --api-product-name  EMG API Proxy Name                          [required]
  -a, --api-proxy-name    API Proxy Name                              [required]
  -o, --apigee-org        Apigee Edge Org                             [required]
  -e, --apigee-env        Apigee Edge Env                             [required]
  -u, --apigee-user       Apigee Edge Username                        [required]
  -p, --apigee-pass       Apigee Edge Password                        [required]
  -d, --debug             Show debug messages         [boolean] [default: false]
```