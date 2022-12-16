# chat-filter-grpc-plugin-server-go

> :warning: **If you are new to AccelByte Cloud Service Customization gRPC Plugin Architecture**: Start reading from `OVERVIEW.md` in `plugin-arch-grpc-dependencies` repository to get the full context.

## Prerequisites

1. Windows 10 WSL2 or Linux Ubuntu 20.04 with the following tools installed.

    a. bash

    b. docker

    c. docker-compose

    d. docker loki driver
        
       docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions

    e. make

    f. go 1.18

2. AccelByte Cloud demo environment.

    a. Base URL: https://demo.accelbyte.io.

    b. [Create a Game Namespace](https://docs.accelbyte.io/esg/uam/namespaces.html#tutorials) if you don't have one yet. Keep the `Namespace ID`.

    c. [Create an OAuth Client](https://docs.accelbyte.io/guides/access/iam-client.html) with confidential client type. If you want to enable permission authorization, give it `read` permission to resource `NAMESPACE:{namespace}:CHATGRPCSERVICE`. Keep the `Client ID` and `Client Secret`.

## Setup

Create a docker compose `.env` file based on `.env.template` file and fill in the required environment variables in `.env` file.

```
AB_BASE_URL=https://demo.accelbyte.io      # Base URL
AB_SECURITY_CLIENT_ID=xxxxxxxxxx           # Client ID
AB_SECURITY_CLIENT_SECRET=xxxxxxxxxx       # Client secret
AB_NAMESPACE=xxxxxxxxxx                    # Namespace ID
PLUGIN_GRPC_SERVER_AUTH_ENABLED=false      # Enable/disable permission authorization
```

> :exclamation: **For the server and client**: 
> 1. Use the same Base URL, Client ID, Client Secret, and Namespace ID.
> 2. Use the same permission authorization configuration, whether it is enabled or disabled.

## Building

To build the application, use the following command.

```
make build
```

To build and create a docker image of the application, use the following command.

```
make image
```

For more details about the command, see [Makefile](Makefile).

## Running

To run the docker image of the application which has been created beforehand, use the following command.

```
docker-compose up
```

OR

To build, create a docker image, and run the application in one go, use the following command.

```
docker-compose up --build
```
## Advanced

### Building Multi-Arch Docker Image

To create a multi-arch docker image of the project, use the following command.

```
make imagex
```

For more details about the command, see [Makefile](Makefile).
