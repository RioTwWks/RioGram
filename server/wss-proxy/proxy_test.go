package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
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
