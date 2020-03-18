FROM continuumio/miniconda3

# Installing packages
#RUN apk update




RUN pip install mlflow \
    && pip install azure-storage \
    && pip install numpy \
    && pip install scipy \
    && pip install pandas \
    && pip install scikit-learn \
    && pip install cloudpickle \
    && pip install flask 


# Defining working directory and adding source code
WORKDIR /usr/src/app
COPY train.py ./
COPY predict.py ./
COPY model.pkl ./
COPY conda.yaml ./
Copy MLproject ./

#COPY requirements.txt ./
#COPY mypython ./mypython

#RUN pip install -r ./requirements.txt


# Start app
EXPOSE 5000
ENV ENVIRONMENT local
ENTRYPOINT python ./predict.py
