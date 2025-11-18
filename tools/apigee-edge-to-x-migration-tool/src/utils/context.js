/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import dotenv from 'dotenv';

import ApigeeEdgeClient from "../gateway-clients/apigee-edge/ApigeeEdgeClient.js";
import ApigeeXClient from "../gateway-clients/apigee-x/ApigeeXClient.js";

dotenv.config();

const sourceGatewayId = process.env.source_gateway_type;
const destinationGatewayId = process.env.destination_gateway_type;

function getSourceClient() {
  switch (sourceGatewayId) {
    case 'apigee_edge':
      return new ApigeeEdgeClient(
        process.env.source_gateway_base_url,
        process.env.source_gateway_org,
        {
          username: process.env.source_gateway_username ?? null,
          password: process.env.source_gateway_password ?? null
        }
      );

    case 'apigee_x':
      return new ApigeeXClient(
        process.env.source_gateway_base_url,
        process.env.source_gateway_org,
        JSON.parse(Buffer.from(process.env.source_gateway_service_account, 'base64').toString('ascii'))
      );
  }

  throw new Error(`Unknown source gateway type ${sourceGatewayId}`);
}

function getDestinationClient() {
  switch (destinationGatewayId) {
    case 'apigee_edge':
      return new ApigeeEdgeClient(
        process.env.destination_gateway_base_url,
        process.env.destination_gateway_org,
        {
          username: process.env.destination_gateway_username ?? null,
          password: process.env.destination_gateway_password ?? null
        }
      );

    case 'apigee_x':
      return new ApigeeXClient(
        process.env.destination_gateway_base_url,
        process.env.destination_gateway_org,
        JSON.parse(Buffer.from(process.env.destination_gateway_service_account, 'base64').toString('ascii'))
      );
  }

  throw new Error(`Unknown destination gateway type ${destinationGatewayId}`);
}

const Context = {
  sourceGatewayId,
  sourceClient: getSourceClient(),
  destinationGatewayId,
  destinationClient: getDestinationClient()
}

export default Context;