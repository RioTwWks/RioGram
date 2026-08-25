package main

import (
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	proxy := NewProxy(cfg)
	server := &http.Server{
		Addr:    cfg.ListenAddr,
		Handler: proxy,
	}

	go func() {
		log.Printf("riogram-wss-proxy listening on http://%s", cfg.ListenAddr)
		log.Printf("health: http://%s/health", cfg.ListenAddr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	log.Printf("shutting down")
	_ = server.Close()
}
