// Copyright (c) 2022 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

package server

// ProfanityCustomDictionary holds information about go-away custom profanities
type ProfanityCustomDictionary struct {
	Profanities    []string `json:"profanities"`
	FalsePositives []string `json:"falsePositives"`
	FalseNegatives []string `json:"falseNegatives"`
}
