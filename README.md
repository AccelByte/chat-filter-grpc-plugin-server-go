# chat-filter-grpc-plugin-server-go

```mermaid
flowchart LR
   subgraph AccelByte Gaming Services
   CL[gRPC Client]
   end
   subgraph gRPC Server Deployment
   SV["gRPC Server\n(YOU ARE HERE)"]
   DS[Dependency Services]
   CL --- DS
   end
   DS --- SV
```

`AccelByte Gaming Services` capabilities can be extended using custom functions implemented in a `gRPC server`. If configured, custom functions in the `gRPC server` will be called by `AccelByte Gaming Services` instead of the default function.

The `gRPC server` and the `gRPC client` can actually communicate directly. However, additional services are necessary to provide **security**, **reliability**, **scalability**, and **observability**. We call these services as `dependency services`. The [grpc-plugin-dependencies](https://github.com/AccelByte/grpc-plugin-dependencies) repository is provided as an example of what these `dependency services` may look like. It
contains a docker compose which consists of these `dependency services`.

> :warning: **grpc-plugin-dependencies is provided as example for local development purpose only:** The dependency services in the actual gRPC server deployment may not be exactly the same.

## Overview

This repository contains a `sample chat filter gRPC server app` written in `Go`. It provides a simple custom chat filtering function for chat service in AccelByte Gaming Services. It will filter certain words in chat which have been listed to be filtered.  

This sample app also shows how this `gRPC server` can be instrumented for better observability. 
It is configured by default to send metrics, traces, and logs to the observability `dependency services` in [grpc-plugin-dependencies](https://github.com/AccelByte/grpc-plugin-dependencies).

## Prerequisites

Before starting, you will need the following.

1. Windows 10 WSL2 or Linux Ubuntu 20.04 with the following installed.

   a. bash

   b. curl

   c. docker

   d. docker-compose v2.x

   e. docker loki driver
        
       docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions

   f. make

   g. go v1.18

   h. git

   i. jq

   j. [ngrok](https://ngrok.com/)

   k. [postman](https://www.postman.com/)

   l. [wscat](https://www.npmjs.com/package/wscat)

2. A local copy of [grpc-plugin-dependencies](https://github.com/AccelByte/grpc-plugin-dependencies) repository.

   ```
   git clone https://github.com/AccelByte/grpc-plugin-dependencies.git
   ```

2. Access to `AccelByte Gaming Services` demo environment.

    a. Base URL: https://demo.accelbyte.io.

    b. [Create a Game Namespace](https://docs.accelbyte.io/esg/uam/namespaces.html#tutorials) if you don't have one yet. Keep the `Namespace ID`.

    c. [Create an OAuth Client](https://docs.accelbyte.io/guides/access/iam-client.html) with `confidential` client type. Keep the `Client ID` and `Client Secret`.

## Setup

To be able to run this sample app, you will need to follow these setup steps.

1. Create a docker compose `.env` file by copying the content of [.env.template](.env.template) file. 
2. Fill in the required environment variables in `.env` file as shown below.

   ```
   AB_BASE_URL=https://demo.accelbyte.io      # Base URL of AccelByte Gaming Services demo environment
   AB_CLIENT_ID='xxxxxxxxxx'                  # Use Client ID from the Setup section
   AB_CLIENT_SECRET='xxxxxxxxxx'              # Use Client Secret from the Setup section
   AB_NAMESPACE='xxxxxxxxxx'                  # Use Namespace ID from the Setup section
   PLUGIN_GRPC_SERVER_AUTH_ENABLED=false      # Enable or disable access token and permission verification
   ```

   > :warning: **Keep PLUGIN_GRPC_SERVER_AUTH_ENABLED=false for now**: It is currently not
   supported by AccelByte Gaming Services but it will be enabled later on to improve security. If it is
   enabled, the gRPC server will reject any calls from gRPC clients without proper authorization
   metadata.

## Building

To build this sample app, use the following command.

```
make build
```

To build and create a docker image of this sample app, use the following command.

```
make image
```

For more details about these commands, see [Makefile](Makefile).

## Running

To run the existing docker image of this sample app which has been built before, use the following command.

```
docker-compose up
```

OR

To build, create a docker image, and run the this sample app in one go, use the following command.

```
docker-compose up --build
```

## Testing

### Functional Test in Local Development Environment

The custom functions in this sample app can be tested locally using `postman`.

1. Start the `dependency services` by following the `README.md` in the [grpc-plugin-dependencies](https://github.com/AccelByte/grpc-plugin-dependencies) repository.

   > :warning: **Make sure to start dependency services with mTLS disabled for now**: It is currently not supported by AccelByte Gaming Services but it will be enabled later on to improve security. If it is enabled, the gRPC client calls without mTLS will be rejected by Envoy proxy.

2. Start this `gRPC server` sample app.

3. Open `postman`, create a new `gRPC request`, and enter `localhost:10000` as server URL. 

   > :exclamation: We are essentially accessing the `gRPC server` through an `Envoy` proxy which is a part of `dependency services`.

4. Still in `postman`, continue by selecting `FilterBulk` method and invoke it with the sample message below.

   ```json
   {
      "messages": [
         {
               "timestamp": "1675158486",
               "userId": "fc9ccf985546435ba3af00a07d02e837",
               "id": "d11c6eb58ca847009c9058189531af5f",
               "message": "you are so good"
         },
         {
               "timestamp": "1675158486",
               "userId": "7b772495ac8d4400b6fc2a4154477d6e",
               "id": "0e48058de6284b308536cf3c97b78546",
               "message": "you are so bad"
         }
      ]
   }
   ```

5. If successful, you will see in the response that the word `bad` will be filtered.

   ```json
   {
      "data": [
         {
               "classification": [],
               "cencoredWords": [],
               "id": "d11c6eb58ca847009c9058189531af5f",
               "timestamp": "1675158486",
               "action": "PASS",
               "message": "you are so good",
               "referenceId": ""
         },
         {
               "classification": [],
               "cencoredWords": [],
               "id": "0e48058de6284b308536cf3c97b78546",
               "timestamp": "1675158565",
               "action": "CENSORED",
               "message": "you are so ***",
               "referenceId": ""
         }
      ]
   }
   ```

### Integration Test with AccelByte Gaming Services

After passing functional test in local development environment, you may want to perform
integration test with `AccelByte Gaming Services`. Here, we are going to expose the `gRPC server`
in local development environment to the internet so that it can be called by
`AccelByte Gaming Services`. To do this without requiring public IP, we can use [ngrok](https://ngrok.com/)


1. Start the `dependency services` by following the `README.md` in the [grpc-plugin-dependencies](https://github.com/AccelByte/grpc-plugin-dependencies) repository.

   > :warning: **Make sure to start dependency services with mTLS disabled for now**: It is currently not supported by AccelByte Gaming Services but it will be enabled later on to improve security. If it is enabled, the gRPC client calls without mTLS will be rejected by Envoy proxy.


2. Start this `gRPC server` sample app.

3. Sign-in/sign-up to [ngrok](https://ngrok.com/) and get your auth token in `ngrok` dashboard.

4. In [grpc-plugin-dependencies](https://github.com/AccelByte/grpc-plugin-dependencies) repository folder, run the following command to expose the `Envoy` proxy port connected to the `gRPC server` in local development environment to the internet. Take a note of the `ngrok` forwarding URL e.g. `tcp://0.tcp.ap.ngrok.io:xxxxx`.

   ```
   make ngrok NGROK_AUTHTOKEN=xxxxxxxxxxx    # Use your ngrok auth token
   ```

4. [Create an OAuth Client](https://docs.accelbyte.io/guides/access/iam-client.html) with `confidential` client type with the following permissions. Keep the `Client ID` and `Client Secret`. This is different from the Oauth Client from the Setup section and it is required by [demo.sh](demo.sh) script after this register the `gRPC Server` URL and also to create and delete test users.

   - ADMIN:NAMESPACE:{namespace}:CHAT:CONFIG - READ, UPDATE
   - ADMIN:NAMESPACE:{namespace}:INFORMATION:USER:* - DELETE

   > :warning: **Oauth Client created in this step is different from the one from Setup section:** It is required by [demo.sh](demo.sh) script in the next step to register the `gRPC Server` URL and also to create and delete test users.
   
5. Set the necessary environment variables and run the [demo.sh](demo.sh) script. The script will setup the necessary configuration and then give you instructions on how to send and receive chat using `wscat` between test users. If successful, the word `bad` in any chat will be filtered.

   ```
   export AB_BASE_URL='https://demo.accelbyte.io'
   export AB_CLIENT_ID='xxxxxxxxxx'       # Use Client ID from the previous step
   export AB_CLIENT_SECRET='xxxxxxxxxx'   # Use Client secret from the previous step
   export AB_NAMESPACE='xxxxxxxxxx'       # Use your Namespace ID
   export GRPC_SERVER_URL='tcp://0.tcp.ap.ngrok.io:xxxxx'   # Use your ngrok forwarding URL
   bash demo.sh
   ```
 
> :warning: **Ngrok free plan has some limitations**: You may want to use paid plan if the traffic is high.

## Advanced

### Building Multi-Arch Docker Image

To create a multi-arch docker image of this sample app, use the following command.

```
make imagex
```

For more details about this command, see [Makefile](Makefile).
