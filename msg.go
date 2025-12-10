package main

type Message struct {
	User    User
	Message string
}
type User struct {
	name          string
	id            string
	password_hash string
}
