# data

[![DUB Package](https://img.shields.io/dub/v/dutils-data.svg)](https://code.dlang.org/packages/dutils-data)
[![Posix Build Status](https://travis-ci.org/d-utils/data.svg?branch=master)](https://travis-ci.org/d-utils/data)

Conversion between structs and BSON/JSON with validation

## example

    import std.stdio : writeln;

    import vibe.data.json : Json;

    import dutils.validation.constraints : ValidateRequired, ValidateEmail;
    import dutils.data.json : fromJson;

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

    auto data = Json([
      "does not exists": Json(true),
      "to": Json("anna@example.com"),
      "body": Json("Some text")
    ]);

    Email email;
    fromJson(email, data);

    writeln("email: ", email);
