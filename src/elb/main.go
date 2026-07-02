package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"

	log "github.com/sirupsen/logrus"
)

func main() {
	configPath := flag.String("config", "config.yaml", "path to YAML configuration file")
	debug := flag.Bool("debug", false, "enable debug-level logging")
	flag.Parse()

	// Configure logrus to match the repo's JSON logging style (recorder-go convention).
	log.SetFormatter(&log.JSONFormatter{
		FieldMap: log.FieldMap{
			log.FieldKeyMsg:  "message",
			log.FieldKeyTime: "timestamp",
		},
	})
	log.SetOutput(os.Stdout)
	if *debug {
		log.SetLevel(log.DebugLevel)
	} else {
		log.SetLevel(log.InfoLevel)
	}

	cfg, err := LoadConfig(*configPath)
	if err != nil {
		log.WithError(err).Fatal("failed to load config")
	}

	log.WithFields(log.Fields{
		"config":              *configPath,
		"load_balancer_count": len(cfg.LoadBalancers),
		"es_url":              cfg.Elasticsearch.URL,
	}).Info("configuration loaded")

	app, err := NewApp(cfg)
	if err != nil {
		log.WithError(err).Fatal("failed to initialize application")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	app.Run(ctx)
}
