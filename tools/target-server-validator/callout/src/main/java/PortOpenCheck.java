// Copyright 2023 Google LLC

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//      http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


package com.apigee.devrel.apigee_target_server_validator;

import com.apigee.flow.execution.ExecutionContext;
import com.apigee.flow.execution.ExecutionResult;
import com.apigee.flow.execution.spi.Execution;
import com.apigee.flow.message.MessageContext;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import com.apigee.flow.execution.Action;
import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonElement;

/**
 * A callout that checks if a particular port is open on a specified host.
 */
public class PortOpenCheck implements Execution {

  /**
   * Checks if the specified host and port are available.
   *
   * @param host The host name or IP address to check.
   * @param port The port number to check.
   * @return A string indicating whether the host and port are available
   */
  private static String available(final String host, final int port) {
    Socket socket = new Socket();
    final int sockettimeout = 1000;
    try {
      socket.connect(new InetSocketAddress(host, port), sockettimeout);
      return "REACHABLE";
    } catch (SocketTimeoutException e) {
      return "NOT_REACHABLE";
    } catch (UnknownHostException e) {
      return "UNKNOWN_HOST";
    } catch (IOException e) {
      return "NOT_REACHABLE";
    } finally {
      if (socket != null) {
        try {
          socket.close();
        } catch (IOException e) {
          throw new RuntimeException("Exception occured", e);
        }
      }
    }
  }

  /**
   * Executes the callout.
   *
   * @param messageContext The message context.
   * @param executionContext The execution context.
   * @return The execution result.
   */
  public ExecutionResult execute(final MessageContext messageContext,
    final ExecutionContext executionContext) {
    try {
      String payload = (String) messageContext.getVariable("request.content");
      if (payload != null) {
        Gson gson = new Gson();
        JsonArray hostPortArray = gson.fromJson(payload, JsonArray.class);
        for (JsonElement jsonElement : hostPortArray) {
            JsonObject hostPortEntry = jsonElement.getAsJsonObject();
            String host = hostPortEntry.get("host").getAsString();
            Integer port = hostPortEntry.get("port").getAsInt();
            String status = available(host, port);
            hostPortEntry.addProperty("status", status);
        }
        String results =  gson.toJson(hostPortArray);
        messageContext.setVariable("flow.result", results);
        return ExecutionResult.SUCCESS;
      } else {
        ExecutionResult executionResult = new ExecutionResult(false,
         Action.ABORT);
        executionResult.setErrorResponse("No payload received");
        return executionResult;
      }
    } catch (Exception e) {
      ExecutionResult executionResult = new ExecutionResult(false,
        Action.ABORT);
      //--Returns custom error message and header
      executionResult.setErrorResponse(e.getMessage());
      executionResult.addErrorResponseHeader("ExceptionClass",
        e.getClass().getName());
      //--Set flow variables -- may be useful for debugging.
      messageContext.setVariable("JAVA_ERROR", e.getMessage());
    return executionResult;
    }
  }
}
