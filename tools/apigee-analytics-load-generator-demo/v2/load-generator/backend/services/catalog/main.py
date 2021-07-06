
import random

from catalog import *
from flask import Flask
import time

from flask import Flask
from flask import abort, jsonify
from flask import request
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.ext.stackdriver.trace_exporter import StackdriverExporter
from opencensus.trace import execution_context
from opencensus.trace.propagation import google_cloud_format
from opencensus.trace.samplers import AlwaysOnSampler


app = Flask(__name__)
#propagator = google_cloud_format.GoogleCloudFormatPropagator()

def createMiddleWare(exporter):
    # Configure a flask middleware that listens for each request and applies automatic tracing.
    # This needs to be set up before the application starts.
    middleware = FlaskMiddleware(
        app,
        exporter=exporter,
        propagator=propagator,
        sampler=AlwaysOnSampler())
    return middleware



#Catalog service
@app.route('/catalog',methods=['GET', 'POST'])
def catalog():
    return {}

@app.errorhandler(404)
def resource_not_found(e):
    return jsonify(error=str(e)), 404

@app.route('/catalog/<int:id>')
def product(id):
    obj=getCatalog(id)
    if obj == False:
        abort(404, description="Resource not found")
    else:
        return obj

if __name__ == '__main__':
    #createMiddleWare(StackdriverExporter())
    app.run(host='127.0.0.1', port=8080, debug=True)
