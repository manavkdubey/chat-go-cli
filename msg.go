package main

import (
	"encoding/json"
	"strings"

	"github.com/manavkdubey/chatapp/user"
)

type Message struct {
	User    user.User `json:"user"`
	Message string    `json:"message"`
}

func MessageBytes(message string, user user.User) ([]byte, error) {
	msg := Message{Message: message, User: user}
	return json.Marshal(msg)
}
func BytesToMessage(data []byte) (Message, error) {
	var msg Message
	data = []byte(strings.TrimSpace(string(data)))
	if err := json.Unmarshal(data, &msg); err != nil {
		return Message{}, err
	}
	return msg, nil
}
