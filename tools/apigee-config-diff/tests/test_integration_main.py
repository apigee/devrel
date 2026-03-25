# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from unittest.mock import patch, MagicMock
from apigee_config_diff.main import main
import json
import os


@patch(
    "sys.argv",
    [
        "main.py",
        "--commit-before",
        "previous_commit",
        "--current-commit",
        "current_commit",
        "--folder",
        "resources/",
        "--output",
        "./tmp/apigee",
    ],
)
@patch("apigee_config_diff.diff.check.GitClient.diff_hashes")
@patch("apigee_config_diff.diff.check.GitClient.read_file_contents")
@patch("subprocess.run")
def test_write_temporary_files_basic(
    mock_subprocess_run, mock_read_git_contents, mock_git_diff_hashes
):
    mock_subprocess_run.return_value.returncode = 0

    # Mock the diff files
    mock_git_diff_hashes.return_value = _mock_git_diff()

    # Mock the file contents
    mock_read_git_contents.side_effect = _mock_git_file_content

    main()

    # Check that update/delete directories were created and populated
    update_dir = "./tmp/apigee/update/resources/my-org/env/dev/"
    delete_dir = "./tmp/apigee/delete/resources/my-org/env/dev/"

    assert os.path.exists(os.path.join(update_dir, "flowhooks.json"))
    assert os.path.exists(os.path.join(update_dir, "flowhooks-added.json"))
    assert os.path.exists(os.path.join(delete_dir, "flowhooks-old.json"))

    # Validate content merging correctly
    with open(
        "./tmp/apigee/update/resources/my-org/org/developerApps.json"
    ) as f:
        dev_apps = json.load(f)
        assert "hugh@example.com" in dev_apps
        assert "hughnew@example.com" in dev_apps
        assert dev_apps["hugh@example.com"][0]["name"] == "hughapp"
        assert (
            dev_apps["hugh@example.com"][0]["callbackUrl"]
            == "http://weatherappModified.com"
        )

    with open(
        "./tmp/apigee/update/resources/my-org/env/dev/targetServers.json"
    ) as f:
        target_servers = json.load(f)
        assert len(target_servers) == 1
        assert target_servers[0]["name"] == "Enterprisetarget"
        assert target_servers[0]["isEnabled"] is False


def _mock_git_diff():
    mock_result = MagicMock()

    mock_result.stdout = (
        "M\tresources/my-org/env/dev/flowhooks.json\n"
        "A\tresources/my-org/env/dev/flowhooks-added.json\n"
        "D\tresources/my-org/env/dev/flowhooks-old.json\n"
        "M\tresources/my-org/env/dev/references.json\n"
        "A\tresources/my-org/env/dev/references-added.json\n"
        "D\tresources/my-org/env/dev/references-old.json\n"
        "M\tresources/my-org/env/dev/targetServers.json\n"
        "A\tresources/my-org/env/dev/targetServers-added.json\n"
        "D\tresources/my-org/env/dev/targetServers-old.json\n"
        "M\tresources/my-org/env/dev/keystores.json\n"
        "A\tresources/my-org/env/dev/keystores-added.json\n"
        "D\tresources/my-org/env/dev/keystores-old.json\n"
        "M\tresources/my-org/env/dev/aliases.json\n"
        "A\tresources/my-org/env/dev/aliases-added.json\n"
        "D\tresources/my-org/env/dev/aliases-old.json\n"
        "M\tresources/my-org/org/apiProducts.json\n"
        "A\tresources/my-org/org/apiProducts-added.json\n"
        "D\tresources/my-org/org/apiProducts-old.json\n"
        "M\tresources/my-org/org/developers.json\n"
        "A\tresources/my-org/org/developers-added.json\n"
        "D\tresources/my-org/org/developers-old.json\n"
        "M\tresources/my-org/org/developerApps.json\n"
        "A\tresources/my-org/org/developerApps-added.json\n"
        "D\tresources/my-org/org/developerApps-old.json"
    )

    return mock_result


file_contents = {
    "previous_commit": {
        "resources/my-org/env/dev/flowhooks.json": """
        [
            {
                "flowHookPoint":"PreProxyFlowHook",
                "sharedFlow":"test"
            }
        ]
        """,
        "resources/my-org/env/dev/flowhooks-old.json": """
        [
            {
                "flowHookPoint":"PreTargetFlowHook",
                "sharedFlow":"test"
            }
        ]
        """,
        "resources/my-org/env/dev/references.json": """
        [
            {
                "name" : "sampleReference",
                "refers": "testKeyStorename",
                "resourceType": "KeyStore"
            }
        ]
        """,
        "resources/my-org/env/dev/references-old.json": """
        [
            {
                "name" : "oldReference",
                "refers": "testKeyStorename",
                "resourceType": "KeyStore"
            }
        ]
        """,
        "resources/my-org/env/dev/targetServers.json": """
        [
            {
                "name": "Enterprisetarget",
                "host": "example.com",
                "isEnabled": true,
                "port": 8080
            },
            {
                "name": "ESBTarget",
                "host": "enterprise.com",
                "isEnabled": true,
                "port": 8080,
                "sSLInfo": {
                    "clientAuthEnabled": "false",
                    "enabled": "true",
                    "ignoreValidationErrors": "false",
                    "keyAlias": "key_alias",
                    "keyStore": "keystore_name",
                    "trustStore": "truststore_name"
                }
            }
        ]
        """,
        "resources/my-org/env/dev/targetServers-old.json": """
        [
            {
                "name": "oldTarget",
                "host": "old.example.com",
                "isEnabled": true,
                "port": 1111
            }
        ]
        """,
        "resources/my-org/env/dev/keystores.json": """
        [
            {
                "name" : "testKeyStorename"
            }
        ]
        """,
        "resources/my-org/env/dev/keystores-old.json": """
        [
            {
                "name" : "oldKeyStorename"
            }
        ]
        """,
        "resources/my-org/env/dev/aliases.json": """
        [
            {
                "alias":"testSelfSignedCert",
                "keystorename": "testKeyStorename",
                "format": "selfsignedcert",
                "keySize":"2048",
                "sigAlg":"SHA256withRSA",
                "subject":{
                    "commonName":"testcommonName"
                },
                "certValidityInDays":"90"
            },
            {
                "alias":"testAliasCertFile",
                "keystorename": "testKeyStorename",
                "ignoreExpiryValidation": true,
                "format": "keycertfile",
                "certFilePath":"./tmp/certs/keystore.pem"
            },
            {
                "alias":"testAliasKeyCertFileAndKey",
                "keystorename": "testKeyStorename",
                "ignoreExpiryValidation": true,
                "format": "keycertfile",
                "certFilePath":"./tmp/certs/keystore.pem",
                "keyFilePath":"./tmp/certs/keystore.key",
                "password":"dummy"
            },
            {
                "alias":"testAliasPKCS12",
                "keystorename": "testKeyStorename",
                "ignoreExpiryValidation": true,
                "format": "pkcs12",
                "filePath":"./tmp/certs/myKeystore.p12",
                "password":"dummy"
            }
        ]
        """,
        "resources/my-org/env/dev/aliases-old.json": """
        [
            {
                "alias":"oldSelfSignedCert",
                "keystorename": "testKeyStorename",
                "format": "selfsignedcert",
                "keySize":"2048",
                "sigAlg":"SHA256withRSA",
                "subject":{
                    "commonName":"testcommonName"
                },
                "certValidityInDays":"90"
            }
        ]
        """,
        "resources/my-org/org/apiProducts.json": """
        [
            {
            "name":"weatherProduct",
            "displayName":"weatherProduct",
            "description":"weatherProduct",
            "approvalType":"auto",
            "environments":[
                "test"
            ],
            "attributes": [
                {
                    "name": "access",
                    "value": "public"
                }
            ],
            "quota":"10000",
            "quotaInterval":"1",
            "quotaTimeUnit":"month",
            "operationGroup":{
                "operationConfigs":[
                    {
                        "apiSource":"forecastweatherapi",
                        "operations":[
                        {
                            "resource":"/",
                            "methods":[
                                "GET"
                            ]
                        }
                        ],
                        "quota":{
                        "limit":"1000",
                        "interval":"1",
                        "timeUnit":"month"
                        },
                        "attributes":[
                        {
                            "name":"foo",
                            "value":"bar"
                        }
                        ]
                    }
                ]
            }
            },
            {
            "name":"weatherProduct-legacy",
            "displayName":"weatherProduct-legacy",
            "description":"weatherProduct-legacy",
            "apiResources":[
                "/**",
                "/"
            ],
            "approvalType":"auto",
            "attributes":[
                {
                    "name":"description",
                    "value":"weatherProduct-legacy"
                },
                {
                    "name": "access",
                    "value": "public"
                },
                {
                    "name":"developer.quota.limit",
                    "value":"10000"
                },
                {
                    "name":"developer.quota.interval",
                    "value":"1"
                },
                {
                    "name":"developer.quota.timeunit",
                    "value":"month"
                }
            ],
            "environments":[
                "test"
            ],
            "proxies":[
                "forecastweatherapi"
            ],
            "quota":"10000",
            "quotaInterval":"1",
            "quotaTimeUnit":"month",
            "scopes":[]
            }
        ]
        """,
        "resources/my-org/org/apiProducts-old.json": """
        [
            {
            "name":"oldWeatherProduct-legacy",
            "displayName":"weatherProduct-old",
            "description":"weatherProduct-old",
            "apiResources":[
                "/**",
                "/"
            ],
            "approvalType":"auto",
            "attributes":[
                {
                    "name":"description",
                    "value":"weatherProduct-legacy"
                },
                {
                    "name": "access",
                    "value": "public"
                },
                {
                    "name":"developer.quota.limit",
                    "value":"10000"
                },
                {
                    "name":"developer.quota.interval",
                    "value":"1"
                },
                {
                    "name":"developer.quota.timeunit",
                    "value":"month"
                }
            ],
            "environments":[
                "old"
            ],
            "proxies":[
                "oldproxy"
            ],
            "quota":"10000",
            "quotaInterval":"1",
            "quotaTimeUnit":"month",
            "scopes":[]
            }
        ]
        """,
        "resources/my-org/org/developers.json": """
        [
            {
                "attributes": [],
                "email": "hugh@example.com",
                "firstName": "Hugh",
                "lastName": "Jack",
                "userName": "hughexample"
            }
        ]
        """,
        "resources/my-org/org/developers-old.json": """
        [
            {
                "attributes": [],
                "email": "old@example.com",
                "firstName": "Hugh",
                "lastName": "Old",
                "userName": "hughold"
            }
        ]
        """,
        "resources/my-org/org/developerApps.json": """
        {
            "hugh@example.com": [
                {
                    "apiProducts": [
                        "weatherProduct"
                    ],
                    "callbackUrl": "http://weatherapp.com",
                    "name": "hughapp",
                    "scopes": []
                }
            ]
        }
        """,
        "resources/my-org/org/developerApps-old.json": """
       {
            "hughold@example.com": [
                {
                    "apiProducts": [
                        "weatherProductOld"
                    ],
                    "callbackUrl": "http://weatherapp.com",
                    "name": "hughappold",
                    "scopes": []
                }
            ]
        }
        """,
    },
    "current_commit": {
        "resources/my-org/env/dev/flowhooks.json": """
        [
            {
                "flowHookPoint":"PreProxyFlowHook",
                "sharedFlow":"test-modified"
            }
        ]
        """,
        "resources/my-org/env/dev/flowhooks-added.json": """
        [
            {
                "flowHookPoint":"PostTargetFlowHook",
                "sharedFlow":"test-added"
            }
        ]
        """,
        "resources/my-org/env/dev/references.json": """
        [
            {
                "name" : "sampleReference",
                "refers": "anotherKeyStorename",
                "resourceType": "KeyStore"
            }
        ]
        """,
        "resources/my-org/env/dev/references-added.json": """
        [
            {
                "name" : "NewReference",
                "refers": "newKeyStorename",
                "resourceType": "KeyStore"
            }
        ]
        """,
        "resources/my-org/env/dev/targetServers.json": """
        [
            {
                "name": "Enterprisetarget",
                "host": "example.com",
                "isEnabled": false,
                "port": 8081
            },
            {
                "name": "ESBTarget",
                "host": "enterprise.com",
                "isEnabled": true,
                "port": 8080,
                "sSLInfo": {
                    "clientAuthEnabled": "false",
                    "enabled": "true",
                    "ignoreValidationErrors": "false",
                    "keyAlias": "key_alias",
                    "keyStore": "keystore_name",
                    "trustStore": "truststore_name"
                }
            }
        ]
        """,
        "resources/my-org/env/dev/targetServers-added.json": """
        [
            {
                "name": "NewTarget",
                "host": "new.com",
                "isEnabled": true,
                "port": 8080
            }
        ]
        """,
        "resources/my-org/env/dev/keystores.json": """
        [
            {
                "name" : "modifiedKeyStorename"
            }
        ]
        """,
        "resources/my-org/env/dev/keystores-added.json": """
        [
            {
                "name" : "newKeyStorename"
            }
        ]
        """,
        "resources/my-org/env/dev/aliases.json": """
        [
            {
                "alias":"testSelfSignedCert",
                "keystorename": "modifiedKeyStorename",
                "format": "selfsignedcert",
                "keySize":"2048",
                "sigAlg":"SHA256withRSA",
                "subject":{
                    "commonName":"testcommonName"
                },
                "certValidityInDays":"90"
            },
            {
                "alias":"testAliasCertFile",
                "keystorename": "testKeyStorename",
                "ignoreExpiryValidation": true,
                "format": "keycertfile",
                "certFilePath":"./tmp/certs/keystore.pem"
            },
            {
                "alias":"testAliasKeyCertFileAndKey",
                "keystorename": "anotherModifiedKeyStorename",
                "ignoreExpiryValidation": true,
                "format": "keycertfile",
                "certFilePath":"./tmp/certs/keystore.pem",
                "keyFilePath":"./tmp/certs/keystore.key",
                "password":"dummy"
            },
            {
                "alias":"testAliasPKCS12",
                "keystorename": "testKeyStorename",
                "ignoreExpiryValidation": true,
                "format": "pkcs12",
                "filePath":"./tmp/certs/myKeystore.p12",
                "password":"dummy"
            }
        ]
        """,
        "resources/my-org/env/dev/aliases-added.json": """
        [
            {
                "alias":"newSelfSignedCert",
                "keystorename": "testKeyStorename",
                "format": "selfsignedcert",
                "keySize":"2048",
                "sigAlg":"SHA256withRSA",
                "subject":{
                    "commonName":"testcommonName"
                },
                "certValidityInDays":"90"
            }
        ]
        """,
        "resources/my-org/org/apiProducts.json": """
        [
            {
            "name":"weatherProduct",
            "displayName":"modifiedWeatherProduct",
            "description":"weatherProduct",
            "approvalType":"auto",
            "environments":[
                "test"
            ],
            "attributes": [
                {
                    "name": "access",
                    "value": "public"
                }
            ],
            "quota":"7000",
            "quotaInterval":"1",
            "quotaTimeUnit":"month",
            "operationGroup":{
                "operationConfigs":[
                    {
                        "apiSource":"forecastweatherapi",
                        "operations":[
                        {
                            "resource":"/",
                            "methods":[
                                "GET"
                            ]
                        }
                        ],
                        "quota":{
                        "limit":"1000",
                        "interval":"1",
                        "timeUnit":"month"
                        },
                        "attributes":[
                        {
                            "name":"foo",
                            "value":"bar"
                        }
                        ]
                    }
                ]
            }
            },
            {
            "name":"weatherProduct-legacy",
            "displayName":"weatherProduct-legacy",
            "description":"weatherProduct-legacy",
            "apiResources":[
                "/**",
                "/"
            ],
            "approvalType":"auto",
            "attributes":[
                {
                    "name":"description",
                    "value":"weatherProduct-legacy"
                },
                {
                    "name": "access",
                    "value": "public"
                },
                {
                    "name":"developer.quota.limit",
                    "value":"10000"
                },
                {
                    "name":"developer.quota.interval",
                    "value":"1"
                },
                {
                    "name":"developer.quota.timeunit",
                    "value":"month"
                }
            ],
            "environments":[
                "test"
            ],
            "proxies":[
                "forecastweatherapi"
            ],
            "quota":"10000",
            "quotaInterval":"1",
            "quotaTimeUnit":"month",
            "scopes":[]
            }
        ]
        """,
        "resources/my-org/org/apiProducts-added.json": """
        [
            {
            "name":"aNewProduct",
            "displayName":"newProduct",
            "description":"aNewProduct",
            "apiResources":[
                "/**",
                "/"
            ],
            "approvalType":"auto",
            "attributes":[
                {
                    "name":"description",
                    "value":"weatherProduct-legacy"
                },
                {
                    "name": "access",
                    "value": "public"
                },
                {
                    "name":"developer.quota.limit",
                    "value":"10000"
                },
                {
                    "name":"developer.quota.interval",
                    "value":"1"
                },
                {
                    "name":"developer.quota.timeunit",
                    "value":"month"
                }
            ],
            "environments":[
                "test"
            ],
            "proxies":[
                "forecastweatherapi"
            ],
            "quota":"10000",
            "quotaInterval":"1",
            "quotaTimeUnit":"month",
            "scopes":[]
            }
        ]
        """,
        "resources/my-org/org/developers.json": """
        [
            {
                "attributes": [],
                "email": "hugh@example.com",
                "firstName": "Hugh",
                "lastName": "Jack Modified",
                "userName": "hughexample"
            }
        ]
        """,
        "resources/my-org/org/developers-added.json": """
        [
            {
                "attributes": [],
                "email": "new@example.com",
                "firstName": "New",
                "lastName": "Dev",
                "userName": "newexample"
            }
        ]
        """,
        "resources/my-org/org/developerApps.json": """
        {
            "hugh@example.com": [
                {
                    "apiProducts": [
                        "weatherProductModified"
                    ],
                    "callbackUrl": "http://weatherappModified.com",
                    "name": "hughapp",
                    "scopes": []
                }
            ],

            "hughnew@example.com": [
                {
                    "apiProducts": [
                        "weatherProductNew"
                    ],
                    "callbackUrl": "http://weatherappNew.com",
                    "name": "hughappNew",
                    "scopes": []
                }
            ]
        }
        """,
        "resources/my-org/org/developerApps-added.json": """
        {
            "hughadded@example.com": [
                {
                    "apiProducts": [
                        "weatherProductNew"
                    ],
                    "callbackUrl": "http://weatherappNew.com",
                    "name": "hughappAdded",
                    "scopes": []
                }
            ]
        }
        """,
    },
}


def _mock_git_file_content(commit_hash, f_path):
    return file_contents[commit_hash][f_path]
