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

import java.util.Arrays;
import java.util.Map;

import com.apigee.flow.execution.Action;
import com.apigee.flow.execution.ExecutionContext;
import com.apigee.flow.execution.ExecutionResult;
import com.apigee.flow.execution.spi.Execution;
import com.apigee.flow.message.MessageContext;

public class VaultKeysToJwksCallout implements Execution {

    /**
     * Array for properties parameters passed from context.
     */
    private Map<String, String> properties;

    /**
     * Constructor.
     *
     * @param props properties
     */
    public VaultKeysToJwksCallout(final Map<String, String> props) {

        this.properties = props;
    }

    /**
     *
     * Implements callout logic.
     *
     */
    @Override
    public ExecutionResult execute(
            final MessageContext messageContext,
            final ExecutionContext executionContext) {

        String operation = null;

        VaultKeysToJwks vktj = new VaultKeysToJwks();

        try {
            operation = (this.properties.get("operation"));

            if (operation == null) {
                throw new RuntimeException(
                        "VaultKeysToJwks: operation is not set. "
                      + "Supported operations: keys|base64url-encode");
            }

            if (operation.equals("keys")) {

                String keys = null;

                String input = (this.properties.get("input"));
                String output = (this.properties.get("output"));

                keys = messageContext.getVariable(input);

                if (keys == null) {
                    throw new RuntimeException(
                        "VaultKeysToJwks: no keys json string is provided"
                    );
                }

                messageContext.setVariable(output, vktj.getJwks(keys));

            } else if (operation.equals("base64url-encode")) {

                String input = (this.properties.get("input"));
                String output = (this.properties.get("output"));

                String json = messageContext.getVariable(input);

                messageContext.setVariable(output, vktj.base64UrlEncode(json));

            } else {
                throw new RuntimeException(String.format(
                        "VaultKeysToJwks: Not supported operation: %s. "
                      + "Supported operations: keys|base64url-encode",
                        operation));
            }

            return ExecutionResult.SUCCESS;

        } catch (Exception e) {

            ExecutionResult executionResult = new ExecutionResult(
                    false, Action.ABORT);

            executionResult.setErrorResponse(e.getMessage());
            executionResult.addErrorResponseHeader("ExceptionClass",
                    e.getClass().getName());

            messageContext.setVariable("JAVA_ERROR", e.getMessage());
            messageContext.setVariable("JAVA_STACKTRACE",
                    Arrays.toString(Thread.currentThread().getStackTrace()));
            return executionResult;

        }
    }

}
