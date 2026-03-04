# rails-interview / TodoApi

[![Open in Coder](https://dev.crunchloop.io/open-in-coder.svg)](https://dev.crunchloop.io/templates/fly-containers/workspace?param.Git%20Repository=git@github.com:crunchloop/rails-interview.git)

This is the API used to test integration. It implements the spec defined in [external-api.yaml](https://github.com/crunchloop/challenge-senior-engineer/blob/main/docs/external-api.yaml).

## Build

To build the application:

`bin/setup`

## Run the API

`bin/puma`

The API runs on port **3001** by default. Use `PORT=3000 bin/puma` to override.

## API

Base path: `/todolists` (JSON). Endpoints and request/response shapes follow the [external-api.yaml](https://github.com/crunchloop/challenge-senior-engineer/blob/main/docs/external-api.yaml) spec.

## Test

To run tests:

`bin/rspec`

Check integration tests at: (https://github.com/crunchloop/interview-tests)

## Contact

- Santiago Doldán (sdoldan@crunchloop.io)

## About Crunchloop

![crunchloop](https://s3.amazonaws.com/crunchloop.io/logo-blue.png)

We strongly believe in giving back :rocket:. Let's work together [`Get in touch`](https://crunchloop.io/#contact).
