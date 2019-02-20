SHELL=/bin/bash

export PGPASSWORD ?= $(DB_PASSWORD)

export DB_ENTRY ?= psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER)

run:
	@npm run start:service

build:
	@npm run build

test:
	@npm test

setup:
	@linklocal -r
	@test -n "`ls -A ../code/common/dist/common-compiled`"\
		|| just-wait -t 300 -d 1000 -p ../code/common/dist/common-compiled
	@yarn install --pure-lockfile

dev: setup
	@npm run start

wait-for-postgres:
	while ! nc -zv ${DB_HOST} ${DB_PORT}; do echo waiting for postgresql ..; sleep 1; done;

wait-for-db: wait-for-postgres
	while ! $(DB_ENTRY) ${DB_NAME} -c "select 1"; do echo postgresql starting ..; sleep 1; done;

create-db: wait-for-postgres
	$(DB_ENTRY) ${DEFAULT_DB} -c 'CREATE DATABASE "${DB_NAME}"';

migrate-db:
	@npm run db:migrate

seed-db:
	@npm run db:seed

setup-db: wait-for-postgres create-db migrate-db seed-db

drop-db: wait-for-postgres
	$(DB_ENTRY) ${DEFAULT_DB} -c 'DROP DATABASE "${DB_NAME}"';

.PHONY: run postgresql
