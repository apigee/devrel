# Southbound mTLS

Reference setup for configuring mTLS for connecting Apigee to a target service.
As a backend we use the chromium project's SSL testing bed [Badssl.com](https://badssl.com)`
 and the client certificate provided [there](https://badssl.com/certs/badssl.com-client.p12).

For more background on southbound connectivity patterns (including mTLS), please
 refer to [this](https://community.apigee.com/articles/85982/apigee-southbound-connectivity-patterns.html)
 article in the Apigee community.

## Content

* Apigee Maven Config Plugin [link](https://github.com/apigee/apigee-config-maven-plugin)
 to deploy:
  * 2 Target Servers
    * `badSSLWithoutClientCert` to show a missing client certificate
    * `badSSLWithClientCert` to show a valid client certificate
  * Keystore
  * Certificate in keystore
* Integration test to validate the deployment
