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

import java.util.Base64;
import java.util.Iterator;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.jwk.JWK;

public class VaultKeysToJwks {

    /**
     * Base 64 URL encoding.
     *
     * @param str
     * @return encoded string
     * @throws JOSEException
     */
    public String base64UrlEncode(final String str) throws JOSEException {

        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(str.getBytes());
    }

    /**
     * Transform to JWKS representation.
     *
     * @param keysJson
     * @return JWKS string
     * @throws JOSEException
     */
    public String getJwks(final String keysJson) throws JOSEException {

        JsonObject vaultKeysObject = JsonParser.parseString(keysJson)
                .getAsJsonObject();

        JsonObject dataObject = vaultKeysObject.getAsJsonObject("data");
        JsonObject keysObject = dataObject.getAsJsonObject("keys");

        JsonObject jwksObject = new JsonObject();

        JsonArray jwksArray = new JsonArray();

        Iterator<String> keys = keysObject.keySet().iterator();
        while (keys.hasNext()) {

            String key = keys.next();
            if (keysObject.get(key) instanceof JsonObject) {
                JsonObject jwk = (JsonObject) keysObject.get(key);

                String publicKey = jwk.get("public_key").getAsString();

                JsonObject jwkObject = new JsonObject();

                jwkObject.addProperty("kid", key);

                // public key
                JWK jwkPublicKey;
                jwkPublicKey = JWK.parseFromPEMEncodedObjects(publicKey);

                // Convert to JWK format
                String publicJwkJson = jwkPublicKey.toPublicJWK()
                        .toJSONString();

// todo: [] refactor/simplify after upgraded to 9.24.2;
//          version 9.24.2 (2022-08-19): JSON Smart -> GSON
                JsonObject publicJwk = JsonParser.parseString(publicJwkJson)
                        .getAsJsonObject();
                Iterator<String> keysPublicJwk = publicJwk.keySet().iterator();

                while (keysPublicJwk.hasNext()) {

                    String keyPublicJwk = keysPublicJwk.next();
                    if (keysObject.get(key) instanceof JsonObject) {

                        jwkObject.addProperty(keyPublicJwk,
                                publicJwk.get(keyPublicJwk).getAsString());

                    }

                }
                jwksArray.add(jwkObject);
            }
        }

        // jwk loop

        jwksObject.add("keys", jwksArray);

        Gson gson = new GsonBuilder().setPrettyPrinting()
                .disableHtmlEscaping()
                .create();

        return gson.toJson(jwksObject);
    }
}
