package main

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

var telegramHostPattern = regexp.MustCompile(`(?i)^[a-z0-9\-]+\.(?:web\.)?telegram\.org$`)

var upgrader = websocket.Upgrader{
	// tdweb/emscripten requires Sec-WebSocket-Protocol: binary; Chrome fails the
	// handshake if the client offers subprotocols but the server omits the header.
	Subprotocols:    []string{"binary"},
	CheckOrigin:     func(_ *http.Request) bool { return true },
	EnableCompression: false,
}

// Proxy serves health checks and WebSocket reverse proxy routes.
type Proxy struct {
	cfg             Config
	activeConns     atomic.Int64
	upstreamDialer  websocket.Dialer
}

func NewProxy(cfg Config) *Proxy {
	return &Proxy{
		cfg: cfg,
		upstreamDialer: websocket.Dialer{
			HandshakeTimeout: 15 * time.Second,
			Proxy:            http.ProxyFromEnvironment,
		},
	}
}

func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/")

	if path == "" || path == "health" {
		p.writeHealth(w)
		return
	}

	if r.Method == http.MethodOptions {
		p.writeCORS(w, http.StatusNoContent)
		return
	}

	targetHost, targetPath, ok := parseTargetPath(path)
	if !ok {
		p.writeJSON(w, http.StatusForbidden, map[string]any{
			"error": "forbidden: not a Telegram domain",
			"path":  path,
		})
		return
	}

	if p.cfg.AuthToken != "" && !p.isAuthorized(r) {
		p.writeJSON(w, http.StatusUnauthorized, map[string]any{
			"error": "unauthorized",
		})
		return
	}

	if !isWebSocketUpgrade(r) {
		p.proxyHTTP(w, r, targetHost, targetPath)
		return
	}

	p.proxyWebSocket(w, r, targetHost, targetPath)
}

func parseTargetPath(path string) (host string, targetPath string, ok bool) {
	path = strings.Trim(path, "/")
	if path == "" {
		return "", "", false
	}

	segments := strings.SplitN(path, "/", 2)
	host = segments[0]
	if !telegramHostPattern.MatchString(host) {
		return "", "", false
	}

	if len(segments) == 1 || segments[1] == "" {
		targetPath = "/apiws"
	} else {
		targetPath = "/" + segments[1]
	}

	return host, targetPath, true
}

func isWebSocketUpgrade(r *http.Request) bool {
	return strings.EqualFold(r.Header.Get("Upgrade"), "websocket")
}

func (p *Proxy) isAuthorized(r *http.Request) bool {
	auth := r.Header.Get("Authorization")
	if strings.HasPrefix(auth, "Bearer ") {
		return strings.TrimPrefix(auth, "Bearer ") == p.cfg.AuthToken
	}
	return r.Header.Get("X-RioGram-Proxy-Token") == p.cfg.AuthToken
}

func (p *Proxy) writeHealth(w http.ResponseWriter) {
	p.writeJSON(w, http.StatusOK, map[string]any{
		"status":      "ok",
		"service":     "riogram-wss-proxy",
		"type":        "WebSocket reverse proxy",
		"description": "Telegram WSS proxy for RioGram Web (§8.3)",
		"usage":       "wss://your-domain/{telegram_host}/apiws",
		"example":     "wss://your-domain/venus.web.telegram.org/apiws",
		"active":      p.activeConns.Load(),
	})
}

func (p *Proxy) writeCORS(w http.ResponseWriter, status int) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "*")
	w.Header().Set("Access-Control-Max-Age", "86400")
	w.WriteHeader(status)
}

func (p *Proxy) writeJSON(w http.ResponseWriter, status int, payload map[string]any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func (p *Proxy) proxyHTTP(w http.ResponseWriter, r *http.Request, targetHost, targetPath string) {
	targetURL := "https://" + targetHost + targetPath
	if r.URL.RawQuery != "" {
		targetURL += "?" + r.URL.RawQuery
	}

	req, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL, r.Body)
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	req.Header = r.Header.Clone()
	req.Header.Set("Host", targetHost)
	if p.cfg.UpstreamOriginHost != "" {
		req.Header.Set("Origin", "https://"+p.cfg.UpstreamOriginHost)
	} else {
		req.Header.Set("Origin", "https://"+targetHost)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func (p *Proxy) proxyWebSocket(w http.ResponseWriter, r *http.Request, targetHost, targetPath string) {
	clientConn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("client upgrade failed host=%s: %v", targetHost, err)
		return
	}

	upstreamURL := "wss://" + targetHost + targetPath
	if r.URL.RawQuery != "" {
		upstreamURL += "?" + r.URL.RawQuery
	}

	headers := http.Header{}
	headers.Set("Host", targetHost)
	headers.Set("Sec-WebSocket-Protocol", "binary")
	originHost := targetHost
	if p.cfg.UpstreamOriginHost != "" {
		originHost = p.cfg.UpstreamOriginHost
	}
	headers.Set("Origin", "https://"+originHost)

	upstreamConn, resp, err := p.upstreamDialer.Dial(upstreamURL, headers)
	if err != nil {
		status := 0
		if resp != nil {
			status = resp.StatusCode
		}
		log.Printf("upstream dial failed host=%s status=%d: %v", targetHost, status, err)
		_ = clientConn.WriteMessage(
			websocket.TextMessage,
			[]byte(`{"error":"upstream_failed","host":"`+targetHost+`"}`),
		)
		clientConn.Close()
		return
	}

	p.activeConns.Add(1)
	defer p.activeConns.Add(-1)
	defer upstreamConn.Close()
	defer clientConn.Close()

	log.Printf("proxy connected client=%s upstream=%s", r.RemoteAddr, targetHost)
	p.relay(clientConn, upstreamConn)
	log.Printf("proxy closed upstream=%s", targetHost)
}

func (p *Proxy) relay(clientConn, upstreamConn *websocket.Conn) {
	errc := make(chan error, 2)

	go func() {
		errc <- copyFrames(upstreamConn, clientConn)
	}()
	go func() {
		errc <- copyFrames(clientConn, upstreamConn)
	}()

	<-errc
}

func copyFrames(src, dst *websocket.Conn) error {
	for {
		messageType, payload, err := src.ReadMessage()
		if err != nil {
			if websocket.IsCloseError(err, websocket.CloseNormalClosure, websocket.CloseGoingAway) {
				return nil
			}
			if errors.Is(err, io.EOF) {
				return nil
			}
			return err
		}
		if err := dst.WriteMessage(messageType, payload); err != nil {
			return err
		}
	}
}
