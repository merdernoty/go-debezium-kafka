package main

import (
	"context"
	"github/merdernoty/go-debezium-kafka/user-service/handler"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dsn := os.Getenv("DB_DSN")
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v\n", err)
	}
	defer pool.Close()


	_, err = pool.Exec(context.Background(), `
	CREATE TABLE IF NOT EXISTS users (
	  id TEXT PRIMARY KEY,
	  name TEXT NOT NULL,
	  created_at TIMESTAMPTZ NOT NULL 
	)
	`)
	if err != nil {
		log.Fatalf("schema init error : %v\n", err)
	}
	
	if _, err := pool.Exec(context.Background(), `
	CREATE PUBLICATION IF NOT EXISTS dbserver1_pub FOR TABLE users;
	`); err != nil {
		if pgErr, ok := err.(*pgconn.PgError); ok && pgErr.Code == "42710" {
			// Publication already exists, this is fine
			log.Println("Publication already exists")
		} else {
			log.Fatalf("failed to create publication: %v\n", err)
		}
	} else {
		log.Println("Publication created successfully")
	}
	mh := handler.NewUserHandler(pool)
	mux := http.NewServeMux()
	mux.HandleFunc("/users", mh.CreateUser)
	srv := &http.Server{Addr: ":8001", Handler: mux}
	go func() {
		log.Println("Starting user service on :8001")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("user service error : %v\n", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	log.Println("user-service stopped")
}	