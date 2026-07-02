package main

import (
	"fmt"
	"net/url"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

// Config is the top-level YAML configuration.
type Config struct {
	Elasticsearch ESConfig      `yaml:"elasticsearch"`
	Resource      ResourceConfig `yaml:"resource"`
	LoadBalancers []LBConfig    `yaml:"load_balancers"`
	HealthCheck   HealthConfig  `yaml:"health_check"`
}

// ESConfig holds the Elasticsearch destination settings.
type ESConfig struct {
	URL                string `yaml:"url"`
	APIKey             string `yaml:"api_key"`
	LogsDatastream     string `yaml:"logs_datastream"`
	MetricsDatastream  string `yaml:"metrics_datastream"`
	InsecureSkipVerify bool   `yaml:"insecure_skip_verify"`
}

// ResourceConfig holds constant-per-run fields used in telemetry doc resource attributes.
type ResourceConfig struct {
	CloudAccountID    string   `yaml:"cloud_account_id"`
	CloudRegion       string   `yaml:"cloud_region"`
	AvailabilityZones []string `yaml:"availability_zones"`
	S3BucketName      string   `yaml:"s3_bucket_name"`
	S3BucketARN       string   `yaml:"s3_bucket_arn"`
	S3KeyPrefix       string   `yaml:"s3_key_prefix"`
}

// LBConfig describes a single load balancer instance.
type LBConfig struct {
	Name        string       `yaml:"name"`        // e.g. "app/tbekiares/02825fbca8b4ec33"
	TargetGroup string       `yaml:"target_group"` // e.g. "targetgroup/.../..."
	Port        int          `yaml:"port"`
	Backends    []string     `yaml:"backends"` // http/https URLs
	HealthCheck *HealthConfig `yaml:"health_check,omitempty"`
}

// HealthConfig controls active health checking of backends.
// Duration fields are parsed by gopkg.in/yaml.v3 natively (e.g. "10s").
type HealthConfig struct {
	Path     string        `yaml:"path"`
	Interval time.Duration `yaml:"interval"`
	Timeout  time.Duration `yaml:"timeout"`
}

// LoadConfig reads, env-expands, parses, and validates the YAML config file.
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading config %q: %w", path, err)
	}
	// Support ${VAR} and $VAR references in the YAML (mirrors recorder-go env-var style).
	expanded := os.ExpandEnv(string(data))

	var cfg Config
	if err := yaml.Unmarshal([]byte(expanded), &cfg); err != nil {
		return nil, fmt.Errorf("parsing config: %w", err)
	}
	applyDefaults(&cfg)
	if err := validateConfig(&cfg); err != nil {
		return nil, fmt.Errorf("invalid config: %w", err)
	}
	return &cfg, nil
}

func applyDefaults(cfg *Config) {
	// Global health check defaults.
	if cfg.HealthCheck.Path == "" {
		cfg.HealthCheck.Path = "/"
	}
	if cfg.HealthCheck.Interval == 0 {
		cfg.HealthCheck.Interval = 10 * time.Second
	}
	if cfg.HealthCheck.Timeout == 0 {
		cfg.HealthCheck.Timeout = 2 * time.Second
	}
	// Apply global defaults to each LB's health check config.
	for i := range cfg.LoadBalancers {
		if cfg.LoadBalancers[i].HealthCheck == nil {
			hc := cfg.HealthCheck
			cfg.LoadBalancers[i].HealthCheck = &hc
		} else {
			if cfg.LoadBalancers[i].HealthCheck.Path == "" {
				cfg.LoadBalancers[i].HealthCheck.Path = cfg.HealthCheck.Path
			}
			if cfg.LoadBalancers[i].HealthCheck.Interval == 0 {
				cfg.LoadBalancers[i].HealthCheck.Interval = cfg.HealthCheck.Interval
			}
			if cfg.LoadBalancers[i].HealthCheck.Timeout == 0 {
				cfg.LoadBalancers[i].HealthCheck.Timeout = cfg.HealthCheck.Timeout
			}
		}
		// Default LB name if omitted.
		if cfg.LoadBalancers[i].Name == "" {
			cfg.LoadBalancers[i].Name = fmt.Sprintf("app/elb-%d/unknown", i)
		}
	}
}

func validateConfig(cfg *Config) error {
	if cfg.Elasticsearch.URL == "" {
		return fmt.Errorf("elasticsearch.url is required")
	}
	if cfg.Elasticsearch.APIKey == "" {
		return fmt.Errorf("elasticsearch.api_key is required")
	}
	if cfg.Elasticsearch.LogsDatastream == "" {
		return fmt.Errorf("elasticsearch.logs_datastream is required")
	}
	if cfg.Elasticsearch.MetricsDatastream == "" {
		return fmt.Errorf("elasticsearch.metrics_datastream is required")
	}
	if len(cfg.LoadBalancers) == 0 {
		return fmt.Errorf("at least one load_balancer is required")
	}
	for i, lb := range cfg.LoadBalancers {
		if lb.Port == 0 {
			return fmt.Errorf("load_balancers[%d].port is required", i)
		}
		if len(lb.Backends) == 0 {
			return fmt.Errorf("load_balancers[%d].backends must have at least one entry", i)
		}
		for j, b := range lb.Backends {
			if _, err := url.ParseRequestURI(b); err != nil {
				return fmt.Errorf("load_balancers[%d].backends[%d]: invalid URL %q: %w", i, j, b, err)
			}
		}
	}
	return nil
}
