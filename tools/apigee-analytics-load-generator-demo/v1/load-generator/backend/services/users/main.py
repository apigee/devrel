
import random

from user import *
from flask import Flask



# If `entrypoint` is not defined in app.yaml, App Engine will look for an app
# called `app` in `main.py`.
app = Flask(__name__)

#Customer service
@app.route('/user',methods=['GET', 'POST'])
def customers():
    """Return a friendly HTTP greeting."""
    return {}
@app.route('/user/<int:id>')
def customer(id):
    """Return a friendly HTTP greeting."""
    return getUsers(id)


if __name__ == '__main__':
    # This is used when running locally only. When deploying to Google App
    # Engine, a webserver process such as Gunicorn will serve the app. This
    # can be configured by adding an `entrypoint` to app.yaml.
    app.run(host='127.0.0.1', port=8080, debug=True)
# [END gae_python37_app]
