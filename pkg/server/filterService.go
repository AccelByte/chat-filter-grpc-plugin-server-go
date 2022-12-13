// Copyright (c) 2022 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

package server

import (
	"context"
	"time"

	"chat-filter-grpc-plugin-server-go/pkg/pb"

	goaway "github.com/TwiN/go-away"
)

type FilterServiceServer struct {
	pb.UnimplementedFilterServiceServer
	detector *goaway.ProfanityDetector
}

func (s FilterServiceServer) Check(ctx context.Context, request *pb.HealthCheckRequest) (*pb.HealthCheckResponse, error) {
	return &pb.HealthCheckResponse{
		Status: pb.HealthCheckResponse_SERVING,
	}, nil
}

func (s FilterServiceServer) FilterBulk(ctx context.Context, chatMessages *pb.ChatMessageBulk) (*pb.MessageBatchResult, error) {
	result := &pb.MessageBatchResult{
		Data: make([]*pb.MessageResult, len(chatMessages.GetMessages())),
	}

	for index, chatMessage := range chatMessages.GetMessages() {
		action := pb.MessageResult_PASS
		timestamp := chatMessage.GetTimestamp()
		message := chatMessage.GetMessage()
		if s.detector.IsProfane(chatMessage.GetMessage()) {
			action = pb.MessageResult_CENSORED
			timestamp = time.Now().Unix()
			message = s.detector.Censor(message)
		}
		result.GetData()[index] = &pb.MessageResult{
			Id:             chatMessage.GetId(),
			Timestamp:      timestamp,
			Action:         action,
			Classification: []pb.MessageResult_Classification{},
			Message:        message,
		}
	}

	return result, nil
}

func (s FilterServiceServer) mustEmbedUnimplementedFilterServiceServer() {
}

func NewFilterServiceServer() (*FilterServiceServer, error) {
	return &FilterServiceServer{
		detector: goaway.NewProfanityDetector().WithCustomDictionary(
			[]string{"bad"},
			[]string{"ibad"},
			[]string{"yourbad"},
		),
	}, nil
}
