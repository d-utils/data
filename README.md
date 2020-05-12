# data

[![DUB Package](https://img.shields.io/dub/v/dutils-data.svg)](https://code.dlang.org/packages/dutils-data)
[![Posix Build Status](https://travis-ci.org/d-utils/data.svg?branch=master)](https://travis-ci.org/d-utils/data)

Conversion between structs and BSON/JSON with validation.

The repo contains a minified and changed version of the vibe.d JSON/BSON data module.

## example

    import std.stdio : writeln;

    import dutils.validation.constraints : ValidateRequired, ValidateEmail;
    import dutils.data.json : JSON, populateFromJSON, serializeToJSON;

    struct Email {
      @ValidateRequired()
      @ValidateEmail()
      string to;

      @ValidateEmail()
      string from;

      string subject;

      @ValidateRequired()
      string body;
    }

    void main() {
      auto data = JSON([
          "does not exists": JSON(true),
          "to": JSON("anna@example.com"),
          "body": JSON("Some text")
          ]);

      Email email;
      populateFromJSON(email, data);

      writeln("email: ", email);

      auto json = serializeToJSON(email);

      writeln("json: ", json);
    }
