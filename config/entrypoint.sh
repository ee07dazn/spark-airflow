#!/usr/bin/env bash

TRY_LOOP="20"

: "${REDIS_HOST:="redis"}"
: "${REDIS_PORT:="6379"}"
: "${REDIS_PASSWORD:=""}"

: "${POSTGRES_HOST:="postgres"}"
: "${POSTGRES_PORT:="5432"}"
: "${AIRFLOW__CORE__FERNET_KEY:=$FERNET_KEY}"
: "${AIRFLOW__CORE__REMOTE_LOGGING:=$ENABLE_REMOTE_LOGGING}"
: "${AIRFLOW__CORE__REMOTE_BASE_LOG_FOLDER:=$LOGS_S3_BUCKET}"

export \
AIRFLOW__CORE__FERNET_KEY \
AIRFLOW__CORE__REMOTE_LOGGING \
AIRFLOW__CORE__REMOTE_BASE_LOG_FOLDER \
# Enable the section below for local development
#########################################################
: "${AIRFLOW__CORE__EXECUTOR:=${EXECUTOR:-Local}Executor}"
: "${AIRFLOW__CORE__REMOTE_LOG_CONN_ID:=$REMOTE_LOGIN_CONN_ID}"

export \
  AIRFLOW__CORE__EXECUTOR \
  AIRFLOW__CORE__SQL_ALCHEMY_CONN \
  AIRFLOW__CORE__REMOTE_LOG_CONN_ID \
#########################################################

Install custom python package if requirements.txt is present
if [ -e "/requirements.txt" ]; then
    $(command -v pip) install --user -r /requirements.txt
fi

if [ -n "$REDIS_PASSWORD" ]; then
    REDIS_PREFIX=:${REDIS_PASSWORD}@
else
    REDIS_PREFIX=
fi

wait_for_port() {
  local name="$1" host="$2" port="$3"
  local j=0
  while ! nc -z "$host" "$port" >/dev/null 2>&1 < /dev/null; do
    j=$((j+1))
    if [ $j -ge $TRY_LOOP ]; then
      echo >&2 "$(date) - $host:$port still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for $name... $j/$TRY_LOOP"
    sleep 5
  done
}

if [ "$AIRFLOW__CORE__EXECUTOR" = "CeleryExecutor" ]; then
  wait_for_port "Postgres" "$POSTGRES_HOST" "$POSTGRES_PORT"
  wait_for_port "Redis" "$REDIS_HOST" "$REDIS_PORT"
fi

# Enable the section below for local development
#########################################################
if [ "$AIRFLOW__CORE__EXECUTOR" != "SequentialExecutor" ]; then
  AIRFLOW__CORE__SQL_ALCHEMY_CONN="postgresql+psycopg2://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
  AIRFLOW__CELERY__RESULT_BACKEND="db+postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
  wait_for_port "Postgres" "$POSTGRES_HOST" "$POSTGRES_PORT"
  printenv | grep AIRFLOW | awk '{ print "export " $1 }' > ~/.bashrc
fi
#########################################################

case "$1" in
  webserver)
    airflow initdb
    sleep 5
    # python /airflow_user.py
    # Enable the section below for local development
    #########################################################
    if [ "$AIRFLOW__CORE__EXECUTOR" = "LocalExecutor" ]; then
      airflow scheduler &
    fi
    #########################################################
    airflow connections -a --conn_id "my_postgres" --conn_type "postgres" --conn_host $POSTGRES_HOST --conn_login $POSTGRES_USER --conn_password $POSTGRES_PASSWORD --conn_port $POSTGRES_PORT
    # airflow variables -s starttime '2020-08-19 00:00:00'
    # airflow variables -s endtime '2020-08-19 12:00:00'
    exec airflow webserver
    ;;
  worker)
    sleep 15
    exec airflow "$@"
    ;;
  scheduler)
    sleep 15
    $echo
    exec airflow "$@"
    ;;
  flower)
    sleep 15
    exec airflow "$@"
    ;;
  version)
    exec airflow "$@"
    ;;
  *)
    exec "$@"
    ;;
esac