# Another Apigee Client

## Description

In order to perform administration on the Apigee platform, you call the Management API.

Maven is the most popular plugin, but installing Java just to orchestrate Apigee requests is very heavy. 
An alpine container with Maven and Java is 92.5MB.

NodeJS and apigeetool are also popular, but a container with Alpine, Node JS and NPM is 51MB.

The above methods don't teach you how the underlying Management API works. By simple templating `curl`, we 
can learn the Management API and run in an Alpine container that is just 3.09MB. 

