{
    "version": "1.0",
    "envConfig": {
        "$APIGEE_X_ENV": {
            "targetServers": [
              {
                "name": "VaultServer",
                "host": "$VAULT_HOSTNAME",
                "port": $VAULT_PORT,
                "isEnabled": true,
                $VAULT_SSL_INFO
                "protocol": "HTTP"
              }
            ],
            "kvms": [
                {
                    "name": "vault-config",
                    "encrypted": "true",
                    "entry": [
                        {
                            "name": "vault-token",
                            "value": "$VAULT_TOKEN"
                        }
                    ]
                }
            ]
        }
   }
}
