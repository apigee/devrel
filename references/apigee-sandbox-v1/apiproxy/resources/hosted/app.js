/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const app = require("connect")();
const http = require("http");
const swaggerTools = require("swagger-tools");
const serverPort = process.env.PORT || 9000;

// swaggerRouter configuration
const options = {
  useStubs: true,
};

// The Swagger document
const swaggerDoc = require("./swagger.json");

// Initialize the Swagger middleware
swaggerTools.initializeMiddleware(swaggerDoc, function (middleware) {
  app.use(middleware.swaggerMetadata());

  // Validate Swagger requests
  app.use(middleware.swaggerValidator());

  // Error handling
  app.use((err, req, res, next) => {
    res.statusCode = 400;
    res.end(
      JSON.stringify({
        error: err.paramName + ": " + err.code,
      })
    );
  });

  // Route validated requests to appropriate controller
  app.use(middleware.swaggerRouter(options));

  // Start the server
  http.createServer(app).listen(serverPort);
});
