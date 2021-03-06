// compatibility module for std.exception
module dutils.data.utils.exception;

static import std.exception;

static if (__VERSION__ >= 2079) {
	alias enforce = std.exception.enforce;
} else {
	alias enforce = std.exception.enforceEx;
}
