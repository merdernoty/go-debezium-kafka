package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/segmentio/kafka-go"
)

func main() {
	brokers := []string{os.Getenv("KAFKA_BROKERS")}
	topic := os.Getenv("CDC_TOPIC")
	groupID := os.Getenv("GROUP_ID")

	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  brokers,
		Topic:    topic,
		GroupID:  groupID,
	})
	defer reader.Close()

	go func() {
		for {
			m, err := reader.ReadMessage(context.Background())
			if err != nil {
				log.Println("read error:",err)
				time.Sleep(time.Second)
				continue
			}
			log.Printf("received message: key=%s value=%s at %s\n", m.Key, m.Value, m.Time)
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/ping", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"pong"}`))
	})

	srv := &http.Server{Addr: ":8002", Handler: mux}
	go func() {
		log.Println("Starting order service on :8002")
		log.Fatal(srv.ListenAndServe())
	}()
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("order service shutdown error: %v\n", err)
	}
	log.Println("order-service stopped")
}