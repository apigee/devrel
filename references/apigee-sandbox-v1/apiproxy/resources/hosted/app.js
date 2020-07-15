const app = require('connect')()
const http = require('http')
const swaggerTools = require('swagger-tools')
const serverPort = process.env.PORT || 9000

// swaggerRouter configuration
const options = {
  useStubs: true
}

// The Swagger document (require it, build it programmatically, fetch it from a URL, ...)
const swaggerDoc = require('./swagger.json')

// Initialize the Swagger middleware
swaggerTools.initializeMiddleware(swaggerDoc, function(middleware) {
  // Interpret Swagger resources and attach metadata to request - must be first in swagger-tools middleware chain
  app.use(middleware.swaggerMetadata())

  // Validate Swagger requests
  app.use(middleware.swaggerValidator())

  // Error handling
  app.use((err, req, res, next) => {
    res.statusCode = 400
    res.end(JSON.stringify({
      error: err.paramName + ': ' + err.code
    }))
  })

  // Route validated requests to appropriate controller
  app.use(middleware.swaggerRouter(options))

  // Start the server
  http.createServer(app).listen(serverPort)
})
