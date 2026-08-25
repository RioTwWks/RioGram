package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds runtime settings for the WSS reverse proxy.
type Config struct {
	ListenAddr string
	// AuthToken optionally protects the proxy (empty = no auth).
	AuthToken string
	// UpstreamOriginHost when set overrides Origin header sent to Telegram.
	UpstreamOriginHost string
}

func loadConfig() (Config, error) {
	cfg := Config{
		ListenAddr: envOrDefault("WSS_PROXY_LISTEN", "127.0.0.1:5001"),
		AuthToken:  strings.TrimSpace(os.Getenv("WSS_PROXY_TOKEN")),
	}

	if raw := strings.TrimSpace(os.Getenv("WSS_PROXY_UPSTREAM_ORIGIN")); raw != "" {
		cfg.UpstreamOriginHost = strings.TrimPrefix(strings.TrimPrefix(raw, "https://"), "http://")
	}

	if err := validateListenAddr(cfg.ListenAddr); err != nil {
		return Config{}, err
	}

	return cfg, nil
}

func envOrDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func validateListenAddr(addr string) error {
	host, portStr, err := splitHostPort(addr)
	if err != nil {
		return fmt.Errorf("invalid WSS_PROXY_LISTEN %q: %w", addr, err)
	}

	port, err := strconv.Atoi(portStr)
	if err != nil || port < 1 || port > 65535 {
		return fmt.Errorf("invalid port in WSS_PROXY_LISTEN %q", addr)
	}

	if host == "" {
		return fmt.Errorf("WSS_PROXY_LISTEN must include host (use 127.0.0.1 for EU backend)")
	}

	return nil
}

func splitHostPort(addr string) (string, string, error) {
	if strings.HasPrefix(addr, "[") {
		// IPv6: [::1]:5001
		idx := strings.LastIndex(addr, "]:")
		if idx == -1 {
			return "", "", fmt.Errorf("missing port")
		}
		return addr[:idx+1], addr[idx+2:], nil
	}

	parts := strings.Split(addr, ":")
	if len(parts) != 2 {
		return "", "", fmt.Errorf("expected host:port")
	}
	return parts[0], parts[1], nil
}
