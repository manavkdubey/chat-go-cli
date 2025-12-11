package user

type User struct {
	Name         string `json:"name"`
	Id           string `json:"id"`
	PasswordHash string `json:"password_hash"`
}
