package main

// Language-neutral messages.
//
// The native macOS UI owns every translation. This binary emits only a key
// plus its arguments, so the UI can re-render the entire log history when the
// user switches language — including messages produced minutes ago by the
// engine. `Text` is an English fallback used by the CLI and by the on-disk
// error report, neither of which can be re-rendered after being written.

import (
	"errors"
	"fmt"
	"strings"
)

// Msg is serialized to the UI as {"key": ..., "args": [...]}.
type Msg struct {
	Key  string   `json:"key"`
	Args []string `json:"args,omitempty"`
	Text string   `json:"-"`
}

// M builds a localizable message. key is the UI lookup key, fallback is the
// English text used by the CLI, and args fill the {0}, {1}, ... placeholders.
func M(key, fallback string, args ...string) Msg {
	return Msg{Key: key, Args: append([]string{}, args...), Text: fallback}
}

// localize resolves numbered placeholders in the English fallback.
func (m Msg) localize() string {
	t := m.Text
	for i, a := range m.Args {
		t = strings.ReplaceAll(t, fmt.Sprintf("{%d}", i), a)
	}
	return t
}

// A stringifies mixed values into placeholder arguments.
func A(v ...any) []string {
	out := make([]string, 0, len(v))
	for _, x := range v {
		out = append(out, fmt.Sprint(x))
	}
	return out
}

// MsgError carries a structured message through ordinary error returns, so
// fmt.Errorf wrapping and errors.Is/As keep working as before.
type MsgError struct {
	msg   Msg
	cause error
}

// Error returns the English fallback with placeholders resolved.
func (e *MsgError) Error() string { return e.msg.localize() }

// Unwrap exposes the wrapped cause so errors.Is / errors.As keep working.
func (e *MsgError) Unwrap() error { return e.cause }

// E returns an error that still carries its localization key.
func E(key, fallback string, args ...string) error {
	return &MsgError{msg: M(key, fallback, args...)}
}

// EW wraps cause with a localizable message, preserving the error chain.
func EW(key, fallback string, cause error, args ...string) error {
	return &MsgError{msg: M(key, fallback, args...), cause: cause}
}

func asMsg(err error) (Msg, bool) {
	var me *MsgError
	if errors.As(err, &me) {
		return me.msg, true
	}
	return Msg{}, false
}
