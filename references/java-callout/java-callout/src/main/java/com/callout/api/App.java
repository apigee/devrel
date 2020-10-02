// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.callout.api;

import com.apigee.flow.execution.ExecutionContext;
import com.apigee.flow.execution.ExecutionResult;
import com.apigee.flow.execution.spi.Execution;
import com.apigee.flow.message.MessageContext;

/** Hello world! */
public final class App implements Execution {
	/**
	 * Create the test case.
	 *
	 * @param messageContext   Context of the Message
	 * @param executionContext Context of the Execution
	 * @return Execution Result
	 */
	public ExecutionResult execute(final MessageContext messageContext, 
			final ExecutionContext executionContext) {

		try {

			// Your code here.
			messageContext.setVariable("request.header.x-debug", "true");

			return ExecutionResult.SUCCESS;

		} catch (Exception e) {
			return ExecutionResult.ABORT;
		}
	}
}
