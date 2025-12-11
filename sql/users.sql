-- name: CreateUser :one
INSERT INTO users (email, password_hash, first_name, last_name, is_active, is_superuser, thumbnail, date_joined)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
RETURNING id, email, password_hash, first_name, last_name, is_active, is_superuser, thumbnail, date_joined;

-- name: GetUserByID :one
SELECT id, email, password_hash, first_name, last_name, is_active, is_superuser, thumbnail, date_joined
FROM users
WHERE id = $1;

-- name: CreateUserProfile :one
INSERT INTO user_profile (user_id, phone_number, birth_date)
VALUES ($1,$2,$3)
RETURNING id, user_id, phone_number, birth_date;
