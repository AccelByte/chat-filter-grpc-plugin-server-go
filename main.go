// Copyright (c) 2022 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/contrib/propagators/b3"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	"chat-filter-grpc-plugin-server-go/pkg/pb"
	"chat-filter-grpc-plugin-server-go/pkg/server"

	prometheusGrpc "github.com/grpc-ecosystem/go-grpc-prometheus"
	prometheusCollectors "github.com/prometheus/client_golang/prometheus/collectors"
)

var (
	environment     = "production"
	id              = int64(1)
	metricsEndpoint = "/metrics"
	metricsPort     = 8080
	port            = 6565
	serviceName     = server.GetEnv("OTEL_SERVICE_NAME", "CustomChatFilterServiceGoServerDocker")
)

func main() {
	logrus.Infof("starting app server..")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Create gRPC Server
	s := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			otelgrpc.UnaryServerInterceptor(),
			prometheusGrpc.UnaryServerInterceptor,
			server.EnsureValidToken,
		),
		grpc.ChainStreamInterceptor(
			otelgrpc.StreamServerInterceptor(),
			prometheusGrpc.StreamServerInterceptor,
		),
	)

	// Register Filter Service
	filterServiceServer, err := server.NewFilterServiceServer()
	if err != nil {
		logrus.Fatalf("unable to create filter service server: %v", err)
		return
	}
	pb.RegisterFilterServiceServer(s, filterServiceServer)

	// Enable gRPC Reflection
	reflection.Register(s)
	logrus.Infof("gRPC reflection enabled")

	// Register Prometheus Metrics
	prometheusRegistry := prometheus.NewRegistry()
	prometheusRegistry.MustRegister(
		prometheusCollectors.NewGoCollector(),
		prometheusCollectors.NewProcessCollector(prometheusCollectors.ProcessCollectorOpts{}),
	)

	grpcMetrics := prometheusGrpc.NewServerMetrics()
	grpcMetrics.InitializeMetrics(s)
	prometheusGrpc.Register(s)

	go func() {
		middleware := server.NewMetricsMiddleware(prometheusRegistry, nil)
		handlerFunc := middleware.WrapHandler(
			metricsEndpoint,
			promhttp.HandlerFor(prometheusRegistry, promhttp.HandlerOpts{}),
		)
		http.Handle(metricsEndpoint, handlerFunc)
		log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", metricsPort), nil))
	}()
	logrus.Infof("serving prometheus metrics at: (:%d%s)", metricsPort, metricsEndpoint)

	// Set Tracer Provider
	tracerProvider, err := server.NewTracerProvider(serviceName, environment, id)
	if err != nil {
		logrus.Fatalf("failed to create tracer provider: %v", err)
		return
	}
	otel.SetTracerProvider(tracerProvider)
	defer func(ctx context.Context) {
		if err := tracerProvider.Shutdown(ctx); err != nil {
			logrus.Fatal(err)
		}
	}(ctx)
	logrus.Infof("set tracer provider: (name: %s environment: %s id: %d)", serviceName, environment, id)

	// Set Text Map Propagator
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			b3.New(),
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)
	logrus.Infof("set text map propagator")

	// Start gRPC Server
	logrus.Infof("starting gRPC server..")
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		logrus.Fatalf("failed to listen to tcp:%d: %v", port, err)
		return
	}
	go func() {
		if err = s.Serve(lis); err != nil {
			logrus.Fatalf("failed to run gRPC server: %v", err)
			return
		}
	}()
	logrus.Infof("gRPC server started")
	logrus.Infof("app server started")

	ctx, _ = signal.NotifyContext(ctx, os.Interrupt)
	<-ctx.Done()
}
