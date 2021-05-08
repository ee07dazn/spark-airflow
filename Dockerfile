# BUILD: docker build --rm -t airflow .
# ORIGINAL SOURCE: https://github.com/puckel/docker-airflow

FROM gettyimages/spark
LABEL version="1.0"
LABEL maintainer="krewari"
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.9
ENV AIRFLOW_HOME=/usr/local/airflow/
ENV AIRFLOW_GPL_UNIDECODE=yes

# Celery config
ARG CELERY_REDIS_VERSION=4.2.0
ARG PYTHON_REDIS_VERSION=3.2.0

ARG TORNADO_VERSION=5.1.1

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        python3-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        build-essential \
        libblas-dev \
        liblapack-dev \
        libpq-dev \
        git \
        vim \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        ${buildDeps} \
        freetds-bin \
        build-essential \
        procps \
        sudo \
        python3-pip \
        telnet \
        python3-requests \
        default-mysql-client \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        jq \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && groupadd -g 666 airflow \
    && useradd -ms /bin/bash -d ${AIRFLOW_HOME} -u 666 -g 666 airflow \
    && pip install -U pip setuptools wheel \
    && pip install Cython \
    && pip install pytz \
    && pip install flask-bcrypt \
    && pip install werkzeug \
    && pip install asn1crypto==0.24.0 \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install SQLAlchemy==1.3.15 \
    && pip install marshmallow-sqlalchemy==0.18.0 \
    && pip install requests-oauthlib==1.1.0 \
    && pip install apache-airflow[github_enterprise,crypto,celery,postgres,password,s3,redis,slack,ssh]==${AIRFLOW_VERSION} \
    && pip install redis==${PYTHON_REDIS_VERSION} \
    && pip install celery[redis]==${CELERY_REDIS_VERSION} \
    && pip install flask_oauthlib \
    && pip install psycopg2-binary \
    && pip install tornado==${TORNADO_VERSION} \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY config/entrypoint.sh /entrypoint.sh
COPY ./config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
COPY ./jars ${AIRFLOW_HOME}/jars

RUN chmod +x /entrypoint.sh

RUN chown -R airflow: ${AIRFLOW_HOME}

USER airflow

ENV PYTHONPATH=${SPARK_HOME}/python:${AIRFLOW_HOME}
ENV HOME=${AIRFLOW_HOME}

EXPOSE 8080 5555 8793

WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ["/entrypoint.sh"]