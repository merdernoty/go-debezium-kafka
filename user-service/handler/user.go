package handler

import (
	"context"
	"encoding/json"
	"github/merdernoty/go-debezium-kafka/user-service/model"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)



type UserHandler struct {
	db *pgxpool.Pool
}

func NewUserHandler(db *pgxpool.Pool) *UserHandler {
	return &UserHandler{
		db: db,
	}	
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	u := model.User{ID: uuid.New().String(), Name: req.Name, CreatedAt: time.Now().UTC()}
	_, err := h.db.Exec(context.Background(), "INSERT INTO users (id, name, created_at) VALUES ($1, $2, $3)", u.ID, u.Name, u.CreatedAt)
	if err != nil {
	http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}