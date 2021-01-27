# Decrypt Hybrid Assets

A rescue utility to decrypt proxies and shared flows taken directly 
from an apigee-runtime pod in an encrypted form.

## Description

Image, your trial Apigee hybrid organisation was deleted. The only 
thing that's left is a running runtime.

No need to panic. 

## To take a backup snapshot

1. Log into any apigee-runtime pod

2. Read the value of an $CONTRACT_ENCRYPT_KEY_PATH environment variable

```
echo $CONTRACT_ENCRYPT_KEY_PATH
```
It points to a file that contains base64-encoded artefact encryption key.

For 1.3.x and 1.4.x it will be `/etc/encryption/plainTextDEK`

3. Read the encoded key value
```
cat $CONTRACT_ENCRYPT_KEY_PATH
```
4. tar/gz contents of the `/opt/apigee/apigee-runtime/data/$XXX/config/` 
directory. 

## To recover assets

1. Clone the utility and add its directory to a PATH

2. Define the key as a variable so that you don't need to show it off during 
utility invocation
```
export KEY="<your-encoded-key>"
```

2. Untar the file to any working directory

3. In the working directory, execute

```
decrypt-folder-tree.sh $KEY <source-dir> <target-dir> &> log.log
```

The utility will traverse the <source-dir> directory and will replicate
the directory structure and decrypted files into the &lt;target-dir&gt; directory.


## Restore the status quo and Future-proof your SDLC process

1. Zip each folder and import/deploy them into an Apigee hybrid org.

2. Now it's time to reconsider your approach to using Apigee as a Version Control System.

3. Revisit every proxy folder and put it into a source control system of your choice.


## Bonus section 

How to decrypt a single file only

Assuming $KEY env variable contains the base64 encoded key, execute
```
# decode the encoded key to a steam of bytes
K=$(echo $KEY|base64 -d |hexdump -ve '1/1 "%.2x"')

# calculate the key length for a correct cypher invocation
KEYLENGTH=$(( $(echo -n $K | wc -m) / 2 * 8 ))

# Process the file output a result at stdout
openssl enc -d -aes-$KEYLENGTH-ecb -K $K -in <encrypted-file>
```
