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


package com.apigeesample;

import com.apigee.flow.execution.ExecutionContext;
import com.apigee.flow.execution.ExecutionResult;
import com.apigee.flow.execution.spi.Execution;
import com.apigee.flow.message.MessageContext;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
 

public class PortOpenCheck implements Execution {

        private static String available(String host,int port) {
            Socket socket = new Socket();
            try {
                socket.connect(new InetSocketAddress(host, port), 1000);
                return "REACHABLE";
            } catch (SocketTimeoutException e) {
                return "NOT_REACHABLE";
            } catch (UnknownHostException e) {
                return "UNKNOWN_HOST";
            }
            catch (IOException e) {
                return "NOT_REACHABLE";
            } finally {
                if (socket != null) {
                    try {
                        socket.close();
                    } catch (IOException e) {
                        throw new RuntimeException("You should handle this error.", e);
                    }
                }
            }
        }

        public ExecutionResult execute(MessageContext messageContext, ExecutionContext executionContext) {

                try {
                    String host_name = messageContext.getMessage().getHeader("host_name");
                    String port = messageContext.getMessage().getHeader("port_number");
                    int port_number = Integer.parseInt(port);
                    String Status = available(host_name,port_number);
                    // messageContext.getMessage().setContent(Status);
                    messageContext.setVariable("REACHABLE_STATUS", Status);
                    return ExecutionResult.SUCCESS;

                } catch (Exception e) {
                        return ExecutionResult.ABORT;
                }
        }

}
