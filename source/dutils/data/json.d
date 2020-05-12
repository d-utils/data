module dutils.data.json;

import vibe.data.json : Json;

void fromJson(T)(ref T object, ref Json data) {
  fromJson(object, data, "");
}

void fromJson(T)(ref T object, ref Json data, string pathPrefix = "") {
  import std.conv : to;
  import std.datetime.systime : SysTime;
  import std.uuid : UUID;
  import std.traits : isSomeFunction, isNumeric, isSomeString, isBoolean; //, isArray, isBuiltinType;
  import dutils.validation.validate : validate, ValidationError, ValidationErrors;
  import dutils.validation.constraints : ValidationErrorTypes;

  ValidationError[] errors;

  static foreach (member; __traits(derivedMembers, T)) {
    static if (!isSomeFunction!(__traits(getMember, T, member))) {
      if (data[member].type != Json.Type.undefined) {
        auto jsonValue = data[member];
        auto jsonType = jsonValue.type;
        const path = pathPrefix == "" ? member : pathPrefix ~ "." ~ member;

        try {
          alias structType = typeof(__traits(getMember, T, member));

          if (isNumeric!(structType) && (jsonType == Json.Type.int_
              || jsonType == Json.Type.bigInt || jsonType == Json.Type.float_)) {
            __traits(getMember, object, member) = jsonValue.to!(structType);
          } else if ((isSomeString!(structType) || is(structType == UUID)
              || is(structType == SysTime)) && jsonType == Json.Type.string) {
            __traits(getMember, object, member) = jsonValue.to!(structType);
          } else if (isBoolean!(structType)) {
            __traits(getMember, object, member) = jsonValue.to!(structType);
          }  /*
          // TODO: support array recursion
          } else if (isArray!(structType)) {
              foreach (child; jsonValue) {
                  __traits(getMember, object, member) ~=
              }
          // TODO: support nested calls
          } else if (!isBuiltinType!(structType)) {
              fromJson( __traits(getMember, object, member), jsonValue, path);
          }
          */
          else {
            throw new Exception("Unsupported type");
          }
        } catch (Exception error) {
          errors ~= ValidationError(path, ValidationErrorTypes.type,
              "Value must be convertable to type " ~ typeof(__traits(getMember,
                T, member)).stringof ~ " but got " ~ data[member].type.to!string);
        }
      }
    }
  }

  try {
    validate(object);
  } catch (ValidationErrors validation) {
    errors ~= validation.errors;
  }

  if (errors.length > 0) {
    throw new ValidationErrors(errors);
  }
}

/**
 * fromJson - ensure that deserialization works with valid JSON data
 */
unittest {
  import dutils.validation.constraints : ValidateMinimumLength,
    ValidateMaximumLength, ValidateMinimum, ValidateEmail, ValidateRequired;

  struct Person {
    @ValidateMinimumLength(2)
    @ValidateMaximumLength(100)
    string name;

    @ValidateMinimum!double(20) double height;

    @ValidateEmail()
    @ValidateRequired()
    string email;

    @ValidateRequired()
    bool member;
  }

  auto data = Json([
      "does not exists": Json(true),
      "name": Json("Anna"),
      "height": Json(170.1),
      "email": Json("anna@example.com"),
      "member": Json(true)
      ]);

  Person person;
  fromJson(person, data);

  assert(person.name == "Anna", "expected name Anna");
  assert(person.height == 170.1, "expected height 170.1");
  assert(person.email == "anna@example.com", "expected email anna@example.com");
  assert(person.member == true, "expected member true");
}

/**
 * fromJson - ensure that validation errors are thrown with invalid JSON data
 */
unittest {
  import std.conv : to;
  import dutils.validation.validate : ValidationError, ValidationErrors;
  import dutils.validation.constraints : ValidationErrorTypes, ValidateMinimumLength,
    ValidateMaximumLength, ValidateMinimum, ValidateEmail, ValidateRequired;

  struct Person {
    @ValidateMinimumLength(2)
    @ValidateMaximumLength(100)
    string name;

    @ValidateMinimum!float(20) float height;

    @ValidateEmail()
    @ValidateRequired()
    string email;

    @ValidateRequired()
    bool member;
  }

  auto data = Json([
      "does not exists": Json(true),
      "name": Json("Anna"),
      "height": Json("not a number")
      ]);

  Person person;

  auto catched = false;
  try {
    fromJson(person, data);
  } catch (ValidationErrors validation) {
    catched = true;
    assert(validation.errors.length == 4,
        "expected 4 errors, got " ~ validation.errors.length.to!string
        ~ " with message: " ~ validation.msg);
    assert(validation.errors[0].type == "type", "expected minimumLength error");
    assert(validation.errors[0].path == "height", "expected error path to be height");
    assert(validation.errors[1].type == "minimum", "expected minimum error");
    assert(validation.errors[1].path == "height", "expected error path to be height");
    assert(validation.errors[2].type == "required", "expected required error");
    assert(validation.errors[2].path == "email", "expected error path to be email");
    assert(validation.errors[3].type == "required", "expected required error");
    assert(validation.errors[3].path == "member", "expected error path to be member");
  }

  assert(catched == true, "did not catch the expected errors");
}

/**
 * validate - Should return
 */
unittest {
  import dutils.validation.constraints : ValidateRequired, ValidateEmail;

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

  assert(email.to == "anna@example.com", "expected to to be anna@example.com");
  assert(email.from == "", "expected from to be \"\"");
  assert(email.subject == "", "expected from to be \"\"");
  assert(email.body == "Some text", "expected from to be \"Some text\"");
}
