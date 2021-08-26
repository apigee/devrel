
import random

from catalog import *
from flask import Flask



# If `entrypoint` is not defined in app.yaml, App Engine will look for an app
# called `app` in `main.py`.
app = Flask(__name__)

#Catalog service
@app.route('/catalog',methods=['GET', 'POST'])
def catalog(): 
    return {}

@app.route('/catalog/<int:id>')
def product(id):
    # show the post with the given id, the id is an integer
    return getCatalog(id)


if __name__ == '__main__':
    # This is used when running locally only. When deploying to Google App
    # Engine, a webserver process such as Gunicorn will serve the app. This
    # can be configured by adding an `entrypoint` to app.yaml.
    app.run(host='127.0.0.1', port=8080, debug=True)
# [END gae_python37_app]
