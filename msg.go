package main

import (
	"encoding/json"
	"strings"
)

type Message struct {
	User    User   `json:"user"`
	Message string `json:"message"`
}

type User struct {
	Name         string `json:"name"`
	Id           string `json:"id"`
	PasswordHash string `json:"password_hash"`
}

func MessageBytes(message string, user User) ([]byte, error) {
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
