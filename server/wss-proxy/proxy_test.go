package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/websocket"
)

func TestParseTargetPath(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		path       string
		wantHost   string
		wantTarget string
		wantOK     bool
	}{
		{
			name:       "venus apiws default",
			path:       "venus.web.telegram.org/apiws",
			wantHost:   "venus.web.telegram.org",
			wantTarget: "/apiws",
			wantOK:     true,
		},
		{
			name:       "pluto host only",
			path:       "pluto.web.telegram.org",
			wantHost:   "pluto.web.telegram.org",
			wantTarget: "/apiws",
			wantOK:     true,
		},
		{
			name:       "kws relay",
			path:       "kws1.web.telegram.org/apiws",
			wantHost:   "kws1.web.telegram.org",
			wantTarget: "/apiws",
			wantOK:     true,
		},
		{
			name:   "forbidden host",
			path:   "evil.example.com/apiws",
			wantOK: false,
		},
		{
			name:   "empty",
			path:   "",
			wantOK: false,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			host, targetPath, ok := parseTargetPath(tt.path)
			if ok != tt.wantOK {
				t.Fatalf("ok=%v want=%v host=%q target=%q", ok, tt.wantOK, host, targetPath)
			}
			if !tt.wantOK {
				return
			}
			if host != tt.wantHost {
				t.Fatalf("host=%q want=%q", host, tt.wantHost)
			}
			if targetPath != tt.wantTarget {
				t.Fatalf("targetPath=%q want=%q", targetPath, tt.wantTarget)
			}
		})
	}
}

func TestValidateListenAddr(t *testing.T) {
	t.Parallel()

	if err := validateListenAddr("127.0.0.1:5001"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if err := validateListenAddr(":5001"); err == nil {
		t.Fatalf("expected error for missing host")
	}
}

func TestHealthEndpoint(t *testing.T) {
	t.Parallel()

	proxy := NewProxy(Config{ListenAddr: "127.0.0.1:5001"})
	req := httptest.NewRequest(http.MethodGet, "http://127.0.0.1:5001/health", nil)
	rec := httptest.NewRecorder()
	proxy.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", rec.Code, rec.Body.String())
	}
}

func TestForbiddenHost(t *testing.T) {
	t.Parallel()

	proxy := NewProxy(Config{ListenAddr: "127.0.0.1:5001"})
	req := httptest.NewRequest(http.MethodGet, "http://127.0.0.1:5001/evil.example.com/apiws", nil)
	rec := httptest.NewRecorder()
	proxy.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status=%d want=403", rec.Code)
	}
}

func TestUpgraderNegotiatesBinarySubprotocol(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		defer conn.Close()
	}))
	t.Cleanup(server.Close)

	wsURL := "ws" + server.URL[len("http"):] + "/"
	dialer := websocket.Dialer{Subprotocols: []string{"binary"}}
	conn, resp, err := dialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	if resp.StatusCode != http.StatusSwitchingProtocols {
		t.Fatalf("status=%d want=101", resp.StatusCode)
	}
	if got := resp.Header.Get("Sec-WebSocket-Protocol"); got != "binary" {
		t.Fatalf("Sec-WebSocket-Protocol=%q want=binary", got)
	}
	if conn.Subprotocol() != "binary" {
		t.Fatalf("conn subprotocol=%q want=binary", conn.Subprotocol())
	}
}
