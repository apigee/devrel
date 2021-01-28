# Decrypt Hybrid Assets

A rescue utility to decrypt proxies and shared flows taken directly from
an apigee-runtime pod in an encrypted form.

## Description

Imagine, your trial Apigee hybrid organisation was deleted. The only thing that's
left is a running runtime.

No need to panic.

## To take a backup snapshot

1. Log into any apigee-runtime pod

1. Read the value of an $CONTRACT_ENCRYPT_KEY_PATH environment variable

    ```sh
    echo "$CONTRACT_ENCRYPT_KEY_PATH"
    ```

    It points to a file that contains base64-encoded artefact encryption key.

    For 1.3.x and 1.4.x it will be `/etc/encryption/plainTextDEK`

1. Read the encoded key value

    ```sh
    cat "$CONTRACT_ENCRYPT_KEY_PATH"
    ```

1. tar/gz contents of the `/opt/apigee/apigee-runtime/data/` directory.

    ```sh
    tar -czvf /tmp/data-backup.tar.gz -C /opt/apigee/apigee-runtime/data .
    ```

## To recover assets

1. Clone the utility and add its directory to a PATH

1. Define the key as a variable so that you don't need to show it off during
utility invocation

    ```sh
    export KEY="<your-encoded-key>"
    ```

1. Untar the file to any working directory

1. In the working directory, execute

    ```sh
    decrypt-folder-tree.sh "$KEY" <source-dir> <target-dir> &> log.log
    ```

The utility will traverse the &lt;source-dir&gt; directory and will replicate
the directory structure and decrypted files into the &lt;target-dir&gt;
directory.

## Restore the status quo and Future-proof your SDLC process

1. Zip each folder and import/deploy them into an Apigee hybrid org.

    [How to: manually zip up an API Proxy bundle into something that can be imported to Apigee Edge](https://community.apigee.com/articles/42221/how-to-manually-zip-up-an-api-proxy-bundle-into-so-1.html)

1. Now it's time to reconsider your approach to using Apigee as
a Version Control System.

    The following community articles are a good starting points:

    * [Source Control for API Proxy Development](https://community.apigee.com/articles/34868/source-control-for-api-proxy-development.html)

    * [Antipattern: Manage Edge resources without using source control management](https://docs.apigee.com/api-platform/antipatterns/no-source-control)

1. Revisit every proxy folder and put it into a source control system of
your choice.

## Bonus section

How to decrypt a single file only

Assuming $KEY env variable contains the base64 encoded key, execute

```sh
# decode the encoded key to a steam of bytes
K=$(echo "$KEY"|base64 -d |hexdump -ve '1/1 "%.2x"')

# calculate the key length for a correct cypher invocation
KEYLENGTH=$(( $(echo -n "$K" | wc -m) / 2 * 8 ))

# Process the file output a result at stdout
openssl enc -d -aes-$KEYLENGTH-ecb -K "$K" -in <encrypted-file>
```
