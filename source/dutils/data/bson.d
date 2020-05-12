module dutils.data.bson;

import vibe.data.bson : Bson;

// TODO: support nested structs and arrays
void fromBson(T)(ref T object, ref Bson data) {
  import std.conv : to;
  import std.traits : isSomeFunction, hasMember;
  import dutils.validation.validate : validate, ValidationError, ValidationErrors;
  import dutils.validation.constraints : ValidationErrorTypes;

  ValidationError[] errors;

  static foreach (memberName; __traits(allMembers, T)) {
    static if (!isSomeFunction!(__traits(getMember, T, memberName))) {
      try {
        // static if (is(typeof(__traits(getMember, T, memberName)) == EventMeta)) {
        static if (hasMember!(typeof(__traits(getMember, T, memberName)),
            "fromBson") && isSomeFunction!(__traits(getMember,
            __traits(getMember, T, memberName), "fromBson"))) {
          __traits(getMember, object, memberName) = __traits(getMember,
              __traits(getMember, T, memberName), "fromBson")(data[memberName]);
        } else {
          if (data[memberName].type != Bson.Type.null_) {
            __traits(getMember, object, memberName) = data[memberName].get!(typeof(__traits(getMember,
                T, memberName)));
          }
        }
      } catch (Exception error) {
        errors ~= ValidationError(memberName, ValidationErrorTypes.type,
            "Value must be convertable to type " ~ typeof(__traits(getMember,
              T, memberName)).stringof ~ " but got " ~ data[memberName].type.to!string);
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
 * fromBson - ensure that deserialization works with valid BSON data
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

  auto data = Bson([
      "does not exists": Bson(true),
      "name": Bson("Anna"),
      "height": Bson(170.1),
      "email": Bson("anna@example.com"),
      "member": Bson(true)
      ]);

  Person person;
  fromBson(person, data);

  assert(person.name == "Anna", "expected name Anna");
  assert(person.height == 170.1, "expected height 170");
  assert(person.email == "anna@example.com", "expected email anna@example.com");
  assert(person.member == true, "expected member true");
}

/**
 * fromBson - ensure that validation errors are thrown with invalid BSON data
 */
unittest {
  import dutils.validation.validate : ValidationError, ValidationErrors;
  import dutils.validation.constraints : ValidationErrorTypes, ValidateMinimumLength,
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

  auto data = Bson([
      "does not exists": Bson(true),
      "name": Bson("Anna"),
      "height": Bson("not a number")
      ]);

  Person person;

  auto catched = false;
  try {
    fromBson(person, data);
  } catch (ValidationErrors validation) {
    import std.conv : to;

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

  auto data = Bson([
      "does not exists": Bson(true),
      "to": Bson("anna@example.com"),
      "body": Bson("Some text")
      ]);

  Email email;
  fromBson(email, data);

  assert(email.to == "anna@example.com", "expected to to be anna@example.com");
  assert(email.from == "", "expected from to be \"\"");
  assert(email.subject == "", "expected from to be \"\"");
  assert(email.body == "Some text", "expected from to be \"Some text\"");
}
