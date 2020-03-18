from __future__ import print_function

import numpy as np
from sklearn.linear_model import LogisticRegression
import pickle
from flask import request
from flask import Flask
app = Flask(__name__)


@app.route("/models/predict")
def predict():

    #example of request url
    #http://localhost:5001/models/predict?x=1

    x_test = request.args.get('x', default = '1', type = str)
    x_test = np.fromstring(x_test, dtype=float, sep=' ')
    x_test = np.reshape(x_test, (-1, 1))

    print (x_test)

    # load the model from disk
    loaded_model = pickle.load(open('model.pkl', 'rb'))
    #X = np.array([-2, 10]).reshape(-1, 1)
    #result = loaded_model.predict(X)
    result = loaded_model.predict(x_test)
    result = np.array2string(result)
    
    return result

    
if __name__ == '__main__':
        app.run(port=5001,host='0.0.0.0')  
