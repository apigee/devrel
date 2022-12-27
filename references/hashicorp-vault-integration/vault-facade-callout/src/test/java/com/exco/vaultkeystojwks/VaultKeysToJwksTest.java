/*
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.exco.vaultkeystojwks;

import static org.junit.Assert.assertEquals;

import java.security.Provider;
import java.security.Security;

import org.junit.Test;

import com.nimbusds.jose.crypto.bc.BouncyCastleProviderSingleton;
//import com.nimbusds.jose.jwk.JWK;

/**
 * Unit test for Vault Keys to JWKs callout.
 */
public class VaultKeysToJwksTest {

    /**
     * Test base64UrlEncode.
     *
     * @throws Exception
     */
    @Test
    public void testBase64UrlEncode() throws Exception {

        VaultKeysToJwks vktj = new VaultKeysToJwks();

        //
        // base64UrlEncode
        //

        String str = "{\"kid\":\"key:1\","
                + "\"alg\":\"ES256\",\"typ\":\"JWT\",\"pad\":\".....\"}";

        String strencoded = vktj.base64UrlEncode(str);

        assertEquals(strencoded,
            "eyJraWQiOiJrZXk6MSIsImFsZyI6IkVTMjU2Ii"
            + "widHlwIjoiSldUIiwicGFkIjoiLi4uLi4ifQ");
    }

    /**
     * Test Keys to JWKs.
     *
     * @throws Exception
     */
    @Test
    public void testKeysToJWKs() throws Exception {

        Provider bc = BouncyCastleProviderSingleton.getInstance();
        Security.addProvider(bc);

        String keys = "{\n"
                + "  \"request_id\":"
                + " \"f5ed789c-d421-f39f-31cd-796ab5f2de0a\",\n"
                + "  \"lease_id\": \"\",\n"
                + "  \"lease_duration\": 0,\n"
                + "  \"renewable\": false,\n"
                + "  \"data\": {\n"
                + "    \"allow_plaintext_backup\": false,\n"
                + "    \"auto_rotate_period\": 0,\n"
                + "    \"deletion_allowed\": false,\n"
                + "    \"derived\": false,\n"
                + "    \"exportable\": true,\n"
                + "    \"imported_key\": false,\n"
                + "    \"keys\": {\n"
                + "      \"1\": {\n"
                + "        \"creation_time\":"
                + " \"2022-10-01T17:21:14.580334+01:00\",\n"
                + "        \"name\": \"P-256\",\n"
                + "        \"public_key\": \"-----BEGIN PUBLIC KEY-----\\nMFkw"
                + "EwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZdq4eql8uVh2L964iWA9pFBaFuS"
                + "e\\n449K6kPHmn55GVEbaBhKH4bulG3Ch++xY1NfuMZNUG/E9b6f672xwji"
                + "7rg==\\n-----END PUBLIC KEY-----\\n\"\n"
                + "      }\n"
                + "    },\n"
                + "    \"latest_version\": 1,\n"
                + "    \"min_available_version\": 0,\n"
                + "    \"min_decryption_version\": 1,\n"
                + "    \"min_encryption_version\": 0,\n"
                + "    \"name\": \"mykey\",\n"
                + "    \"supports_decryption\": false,\n"
                + "    \"supports_derivation\": false,\n"
                + "    \"supports_encryption\": false,\n"
                + "    \"supports_signing\": true,\n"
                + "    \"type\": \"ecdsa-p256\"\n"
                + "  },\n"
                + "  \"warnings\": null\n"
                + "}";

        // // public key pem <-> jwks format transformations:
        //
        // String publicKeyPEM= "-----BEGIN PUBLIC KEY-----\n"
        // + "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZdq4eql8uVh2L964iWA9pFBaFuSe
        // + "\n"
        // + "449K6kPHmn55GVEbaBhKH4bulG3Ch++xY1NfuMZNUG/E9b6f672xwji7rg==\n"
        // + "-----END PUBLIC KEY-----\n";

        // Convert to JWK format
        // JWK jwk = JWK.parseFromPEMEncodedObjects( publicKeyPEM );
        // String publicJWK = jwk.toPublicJWK().toJSONString();

        VaultKeysToJwks vktj = new VaultKeysToJwks();

        String jwks = vktj.getJwks(keys);

        assertEquals(jwks,
                  "{\n" + "  \"keys\": [\n"
                        + "    {\n"
                        + "      \"kid\": \"1\",\n"
                        + "      \"kty\": \"EC\",\n"
                        + "      \"crv\": \"P-256\",\n"
                        + "      \"x\":"
                        + " \"Zdq4eql8uVh2L964iWA9pFBaFuSe449K6kPHmn55GVE\",\n"
                        + "      \"y\":"
                        + " \"G2gYSh-G7pRtwofvsWNTX7jGTVBvxPW-n-u9scI4u64\"\n"
                        + "    }\n"
                        + "  ]\n"
                  + "}");
    }

}
