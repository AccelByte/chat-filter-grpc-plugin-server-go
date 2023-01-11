# chat-filter-grpc-plugin-server-go

> :warning: **If you are new to AccelByte Cloud Service Customization gRPC Plugin Architecture**: Start reading from `OVERVIEW.md` in `grpc-plugin-dependencies` repository to get the full context.

## Prerequisites

1. Windows 10 WSL2 or Linux Ubuntu 20.04 with the following tools installed.

    a. bash

    b. docker

    c. docker-compose v2

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

## Testing

### Test Functionality in Local Development Environment

The functionality of `gRPC server` methods can be tested in local development environment.

1. Make sure `dependency services` are running. Please read `README.md` in the `grpc-plugin-dependencies` repository on how to run it.

2. Make sure this sample `gRPC server` is also up and running.

3. Run the corresponding `gRPC client` as a stand in for the actual `gRPC client` in AccelByte Cloud, for example `chat-filter-grpc-plugin-client-go`.

   a. Clone `chat-filter-grpc-plugin-client-go` repository. 

   b. Follow the `README.md` inside to setup, build, and run it.

   c. Try it out! See the instruction in `README.md`.

> :exclamation: **Sample `gRPC server` and `gRPC client` does not have to be implemented in the same programming language**: As long as the gRPC proto is compatible, they should be able to communicate with each other.

### Test Integration with AccelByte Cloud

After testing functionality in local development environment, to allow the actual `gRPC client` in AccelByte Cloud demo environment to access `gRPC server` in local development environment without requiring a public IP address, we can use [ngrok](https://ngrok.com/).

1. Make sure `dependency services` and this sample `gRPC server` are up and running.

2. Sign-in/sign-up to [ngrok](https://ngrok.com/) and get your auth token in `ngrok` dashboard.

3. In `grpc-plugin-dependencies` repository, run the following command to expose `gRPC server` Envoy proxy port in local development environment to the internet. Take a note of the `ngrok` forwarding URL e.g. `tcp://0.tcp.ap.ngrok.io:xxxxx`.

   ```
   make ngrok NGROK_AUTHTOKEN=xxxxxxxxxxx
   ```

4. [Create an OAuth Client](https://docs.accelbyte.io/guides/access/iam-client.html) with confidential client type with the following permissions. Keep the `Client ID` and `Client Secret` for running the [demo.sh](demo.sh) script after this.

   - ADMIN:NAMESPACE:{namespace}:CHAT:CONFIG - READ, UPDATE
   
5. Run the [demo.sh](demo.sh) script to run user chat simulation which calls this sample `gRPC server` using the `Client ID` and `Client Secret` created in the previous step. The script will setup the necessary configuration and then give you instructions on how to send and receive chat using `wscat` and if it contains the word `bad`, it should get filtered.

   ```
   export AB_BASE_URL='https://demo.accelbyte.io'
   export AB_CLIENT_ID='xxxxxxxxxx'
   export AB_CLIENT_SECRET='xxxxxxxxxx'
   export AB_NAMESPACE='accelbyte'
   export NGROK_URL='tcp://0.tcp.ap.ngrok.io:xxxxx'
   bash demo.sh
   ```
 
> :warning: **Ngrok free plan has some limitations**: You may want to use paid plan if the traffic is high.

## Advanced

### Building Multi-Arch Docker Image

To create a multi-arch docker image of the project, use the following command.

```
make imagex
```

For more details about the command, see [Makefile](Makefile).
