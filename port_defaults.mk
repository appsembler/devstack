# define external port default values here
# these can be overridden at the commandline
# (eg, `REDIS_PORT=16739 make tahoe.up`) or in a .env file
# this is useful to avoid port conflicts if you already
# have services running locally

POSTGRES_PORT ?= 5432
REDIS_PORT ?= 6379

export POSTGRES_PORT
export REDIS_PORT
