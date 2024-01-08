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

import com.google.apigee.json.JavaxJson;
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
import java.util.Map;
import java.util.List;
import java.util.ArrayList;
import java.util.HashMap;
import javax.json.JsonArrayBuilder;
import javax.json.JsonObjectBuilder;
import javax.json.Json;

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
  private static String convertMapToJson(Map<String, List<Map<String, String>>> result) {
          JsonArrayBuilder jsonArrayBuilder = Json.createArrayBuilder();

          List<Map<String, String>> listMap = result.get("hostname_portnumbers_status");
          for (Map<String, String> map : listMap) {
              JsonObjectBuilder jsonObjectBuilder = Json.createObjectBuilder();
              for (Map.Entry<String, String> entry : map.entrySet()) {
                  jsonObjectBuilder.add(entry.getKey(), entry.getValue());
              }
              jsonArrayBuilder.add(jsonObjectBuilder);
          }

          return Json.createObjectBuilder()
                  .add("hostname_portnumbers_status", jsonArrayBuilder)
                  .build()
                  .toString();
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
        Map<String, List<Map<String, String>>> result = new HashMap<>();
        result.put("hostname_portnumbers_status", new ArrayList<>());
        Map<String,List<Map<String,String>>> outerMap  = JavaxJson.fromJson(payload,Map.class);
        for (Map.Entry<String, List<Map<String, String>>> entry : outerMap.entrySet()) {
            String hostname_portnumbers = entry.getKey();
            List<Map<String, String>> list_map_host_port = entry.getValue();

            for (Map<String, String> host_port : list_map_host_port) {
                String hostName = (String) host_port.get("host");
                String portNumber = (String) host_port.get("port");
                Integer portNumberint = Integer.parseInt(portNumber);
                String status = available(hostName, portNumberint);
                Map<String, String> newEntry = new HashMap<>();
                newEntry.put("status",status);
                newEntry.putAll(host_port);

                result.get("hostname_portnumbers_status").add(newEntry);
            }
        }
        String jsonResult = convertMapToJson(result);
        messageContext.setVariable("flow.result", jsonResult);
        return ExecutionResult.SUCCESS;
      } else {
        messageContext.setVariable("ERROR", "set payload");
        return ExecutionResult.ABORT;
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
