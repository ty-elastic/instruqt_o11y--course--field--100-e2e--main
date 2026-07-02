package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// ESClient sends documents to an Elasticsearch _bulk endpoint.
// Auth uses the ApiKey scheme, mirroring the pattern in utils/telemgen/telemgen.py.
type ESClient struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

// NewESClient creates a client targeting baseURL with the given API key.
func NewESClient(baseURL, apiKey string, insecureSkipVerify bool) *ESClient {
	transport := &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: insecureSkipVerify}, //nolint:gosec
		MaxIdleConnsPerHost: 4,
		IdleConnTimeout:     90 * time.Second,
	}
	return &ESClient{
		baseURL: strings.TrimRight(baseURL, "/"),
		apiKey:  apiKey,
		http: &http.Client{
			Timeout:   30 * time.Second,
			Transport: transport,
		},
	}
}

// bulkItemOp is the per-item result inside an ES bulk response.
type bulkItemOp struct {
	Status int `json:"status"`
	Error  *struct {
		Type   string `json:"type"`
		Reason string `json:"reason"`
	} `json:"error"`
}

// Bulk indexes the given pre-marshaled JSON docs into index using the create bulk action.
// The create action is required for Elasticsearch data streams (they reject index).
// No _id is included — Elasticsearch auto-generates one.
func (c *ESClient) Bulk(index string, docs [][]byte) error {
	if len(docs) == 0 {
		return nil
	}

	// Build NDJSON: action line + doc line for each document.
	// The action JSON string is built once and reused.
	action := fmt.Sprintf("{\"create\":{\"_index\":%q}}\n", index)
	var buf bytes.Buffer
	buf.Grow(len(action)*len(docs) + sumLen(docs))
	for _, doc := range docs {
		buf.WriteString(action)
		buf.Write(doc)
		buf.WriteByte('\n')
	}

	req, err := http.NewRequest(http.MethodPost, c.baseURL+"/_bulk", &buf)
	if err != nil {
		return fmt.Errorf("building bulk request: %w", err)
	}
	req.Header.Set("Authorization", "ApiKey "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("sending bulk request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("reading bulk response: %w", err)
	}

	if resp.StatusCode >= 300 {
		// Trim body for logging.
		preview := string(body)
		if len(preview) > 512 {
			preview = preview[:512] + "..."
		}
		return fmt.Errorf("bulk HTTP %d: %s", resp.StatusCode, preview)
	}

	// Inspect item-level errors even on a 200 response.
	var result struct {
		Errors bool                          `json:"errors"`
		Items  []map[string]bulkItemOp       `json:"items"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		// Non-fatal if we can't parse — the request succeeded at the HTTP level.
		return nil
	}
	if result.Errors {
		for _, item := range result.Items {
			for _, op := range item {
				if op.Status >= 300 && op.Error != nil {
					return fmt.Errorf("bulk item error (HTTP %d): %s: %s",
						op.Status, op.Error.Type, op.Error.Reason)
				}
			}
		}
	}
	return nil
}

// CloseIdleConnections releases idle keep-alive connections.
func (c *ESClient) CloseIdleConnections() {
	c.http.CloseIdleConnections()
}

func sumLen(docs [][]byte) int {
	n := 0
	for _, d := range docs {
		n += len(d) + 1
	}
	return n
}
