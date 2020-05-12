module dutils.data.bson;

// TODO: support nested structs and arrays
void populateFromBSON(T)(ref T object, ref BSON data) {
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
            "fromBSON") && isSomeFunction!(__traits(getMember,
            __traits(getMember, T, memberName), "fromBSON"))) {
          __traits(getMember, object, memberName) = __traits(getMember,
              __traits(getMember, T, memberName), "fromBSON")(data[memberName]);
        } else {
          if (data[memberName].type != BSON.Type.null_) {
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
 * populateFromBSON - ensure that population works with valid BSON data
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

  auto data = BSON([
      "does not exists": BSON(true),
      "name": BSON("Anna"),
      "height": BSON(170.1),
      "email": BSON("anna@example.com"),
      "member": BSON(true)
      ]);

  Person person;
  populateFromBSON(person, data);

  assert(person.name == "Anna", "expected name Anna");
  assert(person.height == 170.1, "expected height 170");
  assert(person.email == "anna@example.com", "expected email anna@example.com");
  assert(person.member == true, "expected member true");
}

/**
 * populateFromBSON - ensure that validation errors are thrown with invalid BSON data
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

  auto data = BSON([
      "does not exists": BSON(true),
      "name": BSON("Anna"),
      "height": BSON("not a number")
      ]);

  Person person;

  auto catched = false;
  try {
    populateFromBSON(person, data);
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
 * populateFromBSON - should populate
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

  auto data = BSON([
      "does not exists": BSON(true),
      "to": BSON("anna@example.com"),
      "body": BSON("Some text")
      ]);

  Email email;
  populateFromBSON(email, data);

  assert(email.to == "anna@example.com", "expected to to be anna@example.com");
  assert(email.from == "", "expected from to be \"\"");
  assert(email.subject == "", "expected from to be \"\"");
  assert(email.body == "Some text", "expected from to be \"Some text\"");
}

/**
	BSON serialization and value handling.

	Copyright: © 2012-2015 Sönke Ludwig
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/

import dutils.data.json;

///
unittest {
  void manipulateBSON(BSON b) {
    import std.stdio;

    // retrieving the values is done using get()
    assert(b["name"].get!string == "Example");
    assert(b["id"].get!int == 1);

    // semantic conversions can be done using to()
    assert(b["id"].to!string == "1");

    // prints:
    // name: "Example"
    // id: 1
    foreach (string key, value; b)
      writefln("%s: %s", key, value);

    // print out with JSON syntax: {"name": "Example", "id": 1}
    writefln("BSON: %s", b.toString());
  }
}

/// Constructing `BSON` objects
unittest {
  // construct a BSON object {"field1": "foo", "field2": 42, "field3": true}

  // using the constructor
  BSON b1 = BSON([
      "field1": BSON("foo"),
      "field2": BSON(42),
      "field3": BSON(true)
      ]);

  // using piecewise construction
  BSON b2 = BSON.emptyObject;
  b2["field1"] = "foo";
  b2["field2"] = 42;
  b2["field3"] = true;

  // using serialization
  struct S {
    string field1;
    int field2;
    bool field3;
  }

  BSON b3 = S("foo", 42, true).serializeToBSON();
}

import std.algorithm;
import std.array;
import std.base64;
import std.bitmanip;
import std.conv;
import std.datetime;
import std.uuid : UUID;
import std.exception;
import std.range;
import std.traits;
import std.typecons : Tuple, tuple;

alias bdata_t = immutable(ubyte)[];

/**
	Represents a BSON value.


*/
struct BSON {
@safe:

  /// Represents the type of a BSON value
  enum Type : ubyte {
    end = 0x00, /// End marker - should never occur explicitly
    double_ = 0x01, /// A 64-bit floating point value
    string = 0x02, /// A UTF-8 string
    object = 0x03, /// An object aka. dictionary of string to BSON
    array = 0x04, /// An array of BSON values
    binData = 0x05, /// Raw binary data (ubyte[])
    undefined = 0x06, /// Deprecated
    objectID = 0x07, /// BSON Object ID (96-bit)
    bool_ = 0x08, /// Boolean value
    date = 0x09, /// Date value (UTC)
    null_ = 0x0A, /// Null value
    regex = 0x0B, /// Regular expression
    dbRef = 0x0C, /// Deprecated
    code = 0x0D, /// JaveScript code
    symbol = 0x0E, /// Symbol/variable name
    codeWScope = 0x0F, /// JavaScript code with scope
    int_ = 0x10, /// 32-bit integer
    timestamp = 0x11, /// Timestamp value
    long_ = 0x12, /// 64-bit integer
    minKey = 0xff, /// Internal value
    maxKey = 0x7f, /// Internal value
  }

  /// Returns a new, empty BSON value of type Object.
  static @property BSON emptyObject() {
    return BSON(cast(BSON[string]) null);
  }

  /// Returns a new, empty BSON value of type Array.
  static @property BSON emptyArray() {
    return BSON(cast(BSON[]) null);
  }

  private {
    Type m_type = Type.undefined;
    bdata_t m_data;
  }

  /**
		Creates a new BSON value using raw data.

		A slice of the first bytes of `data` is stored, containg the data related to the value. An
		exception is thrown if `data` is too short.
	*/
  this(Type type, bdata_t data) {
    m_type = type;
    m_data = data;
    final switch (type) {
    case Type.end:
      m_data = null;
      break;
    case Type.double_:
      m_data = m_data[0 .. 8];
      break;
    case Type.string:
      m_data = m_data[0 .. 4 + fromBSONData!int(m_data)];
      break;
    case Type.object:
      m_data = m_data[0 .. fromBSONData!int(m_data)];
      break;
    case Type.array:
      m_data = m_data[0 .. fromBSONData!int(m_data)];
      break;
    case Type.binData:
      m_data = m_data[0 .. 5 + fromBSONData!int(m_data)];
      break;
    case Type.undefined:
      m_data = null;
      break;
    case Type.objectID:
      m_data = m_data[0 .. 12];
      break;
    case Type.bool_:
      m_data = m_data[0 .. 1];
      break;
    case Type.date:
      m_data = m_data[0 .. 8];
      break;
    case Type.null_:
      m_data = null;
      break;
    case Type.regex:
      auto tmp = m_data;
      tmp.skipCString();
      tmp.skipCString();
      m_data = m_data[0 .. $ - tmp.length];
      break;
    case Type.dbRef:
      m_data = m_data[0 .. 0];
      assert(false, "Not implemented.");
    case Type.code:
      m_data = m_data[0 .. 4 + fromBSONData!int(m_data)];
      break;
    case Type.symbol:
      m_data = m_data[0 .. 4 + fromBSONData!int(m_data)];
      break;
    case Type.codeWScope:
      m_data = m_data[0 .. 0];
      assert(false, "Not implemented.");
    case Type.int_:
      m_data = m_data[0 .. 4];
      break;
    case Type.timestamp:
      m_data = m_data[0 .. 8];
      break;
    case Type.long_:
      m_data = m_data[0 .. 8];
      break;
    case Type.minKey:
      m_data = null;
      break;
    case Type.maxKey:
      m_data = null;
      break;
    }
  }

  /**
		Initializes a new BSON value from the given D type.
	*/
  this(double value) {
    opAssign(value);
  }
  /// ditto
  this(string value, Type type = Type.string) {
    assert(type == Type.string || type == Type.code || type == Type.symbol);
    opAssign(value);
    m_type = type;
  }
  /// ditto
  this(in BSON[string] value) {
    opAssign(value);
  }
  /// ditto
  this(in BSON[] value) {
    opAssign(value);
  }
  /// ditto
  this(in BSONBinData value) {
    opAssign(value);
  }
  /// ditto
  this(in BSONObjectID value) {
    opAssign(value);
  }
  /// ditto
  this(bool value) {
    opAssign(value);
  }
  /// ditto
  this(in BSONDate value) {
    opAssign(value);
  }
  /// ditto
  this(typeof(null)) {
    opAssign(null);
  }
  /// ditto
  this(in BSONRegex value) {
    opAssign(value);
  }
  /// ditto
  this(int value) {
    opAssign(value);
  }
  /// ditto
  this(in BSONTimestamp value) {
    opAssign(value);
  }
  /// ditto
  this(long value) {
    opAssign(value);
  }
  /// ditto
  this(in JSON value) {
    opAssign(value);
  }
  /// ditto
  this(in UUID value) {
    opAssign(value);
  }

  /**
		Assigns a D type to a BSON value.
	*/
  void opAssign(in BSON other) {
    m_data = other.m_data;
    m_type = other.m_type;
  }
  /// ditto
  void opAssign(double value) {
    m_data = toBSONData(value).idup;
    m_type = Type.double_;
  }
  /// ditto
  void opAssign(string value) {
    import std.utf;

    debug std.utf.validate(value);
    auto app = appender!bdata_t();
    app.put(toBSONData(cast(int) value.length + 1));
    app.put(cast(bdata_t) value);
    app.put(cast(ubyte) 0);
    m_data = app.data;
    m_type = Type.string;
  }
  /// ditto
  void opAssign(in BSON[string] value) {
    auto app = appender!bdata_t();
    foreach (k, ref v; value) {
      app.put(cast(ubyte) v.type);
      putCString(app, k);
      app.put(v.data);
    }

    auto dapp = appender!bdata_t();
    dapp.put(toBSONData(cast(int) app.data.length + 5));
    dapp.put(app.data);
    dapp.put(cast(ubyte) 0);
    m_data = dapp.data;
    m_type = Type.object;
  }
  /// ditto
  void opAssign(in BSON[] value) {
    auto app = appender!bdata_t();
    foreach (i, ref v; value) {
      app.put(v.type);
      putCString(app, to!string(i));
      app.put(v.data);
    }

    auto dapp = appender!bdata_t();
    dapp.put(toBSONData(cast(int) app.data.length + 5));
    dapp.put(app.data);
    dapp.put(cast(ubyte) 0);
    m_data = dapp.data;
    m_type = Type.array;
  }
  /// ditto
  void opAssign(in BSONBinData value) {
    auto app = appender!bdata_t();
    app.put(toBSONData(cast(int) value.rawData.length));
    app.put(value.type);
    app.put(value.rawData);

    m_data = app.data;
    m_type = Type.binData;
  }
  /// ditto
  void opAssign(in BSONObjectID value) {
    m_data = value.m_bytes.idup;
    m_type = Type.objectID;
  }
  /// ditto
  void opAssign(bool value) {
    m_data = [value ? 0x01 : 0x00];
    m_type = Type.bool_;
  }
  /// ditto
  void opAssign(in BSONDate value) {
    m_data = toBSONData(value.m_time).idup;
    m_type = Type.date;
  }
  /// ditto
  void opAssign(typeof(null)) {
    m_data = null;
    m_type = Type.null_;
  }
  /// ditto
  void opAssign(in BSONRegex value) {
    auto app = appender!bdata_t();
    putCString(app, value.expression);
    putCString(app, value.options);
    m_data = app.data;
    m_type = type.regex;
  }
  /// ditto
  void opAssign(int value) {
    m_data = toBSONData(value).idup;
    m_type = Type.int_;
  }
  /// ditto
  void opAssign(in BSONTimestamp value) {
    m_data = toBSONData(value.m_time).idup;
    m_type = Type.timestamp;
  }
  /// ditto
  void opAssign(long value) {
    m_data = toBSONData(value).idup;
    m_type = Type.long_;
  }
  /// ditto
  void opAssign(in JSON value) @trusted {
    auto app = appender!bdata_t();
    m_type = writeBSON(app, value);
    m_data = app.data;
  }
  /// ditto
  void opAssign(in UUID value) {
    opAssign(BSONBinData(BSONBinData.Type.uuid, value.data.idup));
  }

  /**
		Returns the BSON type of this value.
	*/
  @property Type type() const {
    return m_type;
  }

  bool isNull() const {
    return m_type == Type.null_;
  }

  /**
		Returns the raw data representing this BSON value (not including the field name and type).
	*/
  @property bdata_t data() const {
    return m_data;
  }

  /**
		Converts the BSON value to a D value.

		If the BSON type of the value does not match the D type, an exception is thrown.

		See_Also: `deserializeBSON`, `opt`
	*/
  T opCast(T)() const {
    return get!T();
  }
  /// ditto
  @property T get(T)() const {
    static if (is(T == double)) {
      checkType(Type.double_);
      return fromBSONData!double(m_data);
    } else static if (is(T == string)) {
      checkType(Type.string, Type.code, Type.symbol);
      return cast(string) m_data[4 .. 4 + fromBSONData!int(m_data) - 1];
    } else static if (is(Unqual!T == BSON[string]) || is(Unqual!T == const(BSON)[string])) {
      checkType(Type.object);
      BSON[string] ret;
      auto d = m_data[4 .. $];
      while (d.length > 0) {
        auto tp = cast(Type) d[0];
        if (tp == Type.end)
          break;
        d = d[1 .. $];
        auto key = skipCString(d);
        auto value = BSON(tp, d);
        d = d[value.data.length .. $];

        ret[key] = value;
      }
      return cast(T) ret;
    } else static if (is(Unqual!T == BSON[]) || is(Unqual!T == const(BSON)[])) {
      checkType(Type.array);
      BSON[] ret;
      auto d = m_data[4 .. $];
      while (d.length > 0) {
        auto tp = cast(Type) d[0];
        if (tp == Type.end)
          break;
        /*auto key = */
        skipCString(d); // should be '0', '1', ...
        auto value = BSON(tp, d);
        d = d[value.data.length .. $];

        ret ~= value;
      }
      return cast(T) ret;
    } else static if (is(T == BSONBinData)) {
      checkType(Type.binData);
      auto size = fromBSONData!int(m_data);
      auto type = cast(BSONBinData.Type) m_data[4];
      return BSONBinData(type, m_data[5 .. 5 + size]);
    } else static if (is(T == BSONObjectID)) {
      checkType(Type.objectID);
      return BSONObjectID(m_data[0 .. 12]);
    } else static if (is(T == bool)) {
      checkType(Type.bool_);
      return m_data[0] != 0;
    } else static if (is(T == BSONDate)) {
      checkType(Type.date);
      return BSONDate(fromBSONData!long(m_data));
    } else static if (is(T == BSONRegex)) {
      checkType(Type.regex);
      auto d = m_data[0 .. $];
      auto expr = skipCString(d);
      auto options = skipCString(d);
      return BSONRegex(expr, options);
    } else static if (is(T == int)) {
      checkType(Type.int_);
      return fromBSONData!int(m_data);
    } else static if (is(T == BSONTimestamp)) {
      checkType(Type.timestamp);
      return BSONTimestamp(fromBSONData!long(m_data));
    } else static if (is(T == long)) {
      checkType(Type.long_);
      return fromBSONData!long(m_data);
    } else static if (is(T == JSON)) {
      pragma(msg,
          "BSON.get!JSON() and BSON.opCast!JSON() will soon be removed. Please use BSON.toJSON() instead.");
      return this.toJSON();
    } else static if (is(T == UUID)) {
      checkType(Type.binData);
      auto bbd = this.get!BSONBinData();
      enforce(bbd.type == BSONBinData.Type.uuid,
          "BSONBinData value is type '" ~ to!string(bbd.type) ~ "', expected to be uuid");
      const ubyte[16] b = bbd.rawData;
      return UUID(b);
    } else static if (is(T == SysTime)) {
      checkType(Type.date);
      return BSONDate(fromBSONData!long(m_data)).toSysTime();
    } else
      static assert(false, "Cannot cast " ~ typeof(this).stringof ~ " to '" ~ T.stringof ~ "'.");
  }

  /** Returns the native type for this BSON if it matches the current runtime type.

		If the runtime type does not match the given native type, the 'def' parameter is returned
		instead.
	*/
  T opt(T)(T def = T.init) {
    if (isNull())
      return def;
    try
      return cast(T) this;
    catch (Exception e)
      return def;
  }
  /// ditto
  const(T) opt(T)(const(T) def = const(T).init) const {
    if (isNull())
      return def;
    try
      return cast(T) this;
    catch (Exception e)
      return def;
  }

  /** Returns the length of a BSON value of type String, Array, Object or BinData.
	*/
  @property size_t length() const {
    switch (m_type) {
    default:
      enforce(false, "BSON objects of type " ~ to!string(m_type) ~ " do not have a length field.");
      break;
    case Type.string, Type.code, Type.symbol:
      return (cast(string) this).length;
    case Type.array:
      return byValue.walkLength;
    case Type.object:
      return byValue.walkLength;
    case Type.binData:
      assert(false); //return (cast(BSONBinData)this).length; break;
    }
    assert(false);
  }

  /** Converts a given JSON value to the corresponding BSON value.
	*/
  static BSON fromJSON(in JSON value) @trusted {
    auto app = appender!bdata_t();
    auto tp = writeBSON(app, value);
    return BSON(tp, app.data);
  }

  /** Converts a BSON value to a JSON value.

		All BSON types that cannot be exactly represented as JSON, will
		be converted to a string.
	*/
  JSON toJSON() const {
    switch (this.type) {
    default:
      assert(false);
    case BSON.Type.double_:
      return JSON(get!double());
    case BSON.Type.string:
      return JSON(get!string());
    case BSON.Type.object:
      JSON[string] ret;
      foreach (k, v; this.byKeyValue)
        ret[k] = v.toJSON();
      return JSON(ret);
    case BSON.Type.array:
      auto ret = new JSON[this.length];
      foreach (i, v; this.byIndexValue)
        ret[i] = v.toJSON();
      return JSON(ret);
    case BSON.Type.binData:
      return JSON(() @trusted {
        return cast(string) Base64.encode(get!BSONBinData.rawData);
      }());
    case BSON.Type.objectID:
      return JSON(get!BSONObjectID().toString());
    case BSON.Type.bool_:
      return JSON(get!bool());
    case BSON.Type.date:
      return JSON(get!BSONDate.toString());
    case BSON.Type.null_:
      return JSON(null);
    case BSON.Type.regex:
      assert(false, "TODO");
    case BSON.Type.dbRef:
      assert(false, "TODO");
    case BSON.Type.code:
      return JSON(get!string());
    case BSON.Type.symbol:
      return JSON(get!string());
    case BSON.Type.codeWScope:
      assert(false, "TODO");
    case BSON.Type.int_:
      return JSON(get!int());
    case BSON.Type.timestamp:
      return JSON(get!BSONTimestamp().m_time);
    case BSON.Type.long_:
      return JSON(get!long());
    case BSON.Type.undefined:
      return JSON();
    }
  }

  /** Returns a string representation of this BSON value in JSON format.
	*/
  string toString() const {
    return toJSON().toString();
  }

  import std.typecons : Nullable;

  /**
		Check whether the BSON object contains the given key.
	*/
  Nullable!BSON tryIndex(string key) const {
    checkType(Type.object);
    foreach (string idx, v; this.byKeyValue)
      if (idx == key)
        return Nullable!BSON(v);
    return Nullable!BSON.init;
  }

  /** Allows accessing fields of a BSON object using `[]`.

		Returns a null value if the specified field does not exist.
	*/
  inout(BSON) opIndex(string idx) inout {
    foreach (string key, v; this.byKeyValue)
      if (key == idx)
        return v;
    return BSON(null);
  }
  /// ditto
  void opIndexAssign(T)(in T value, string idx) {
    auto newcont = appender!bdata_t();
    checkType(Type.object);
    auto d = m_data[4 .. $];
    while (d.length > 0) {
      auto tp = cast(Type) d[0];
      if (tp == Type.end)
        break;
      d = d[1 .. $];
      auto key = skipCString(d);
      auto val = BSON(tp, d);
      d = d[val.data.length .. $];

      if (key != idx) {
        // copy to new array
        newcont.put(cast(ubyte) tp);
        putCString(newcont, key);
        newcont.put(val.data);
      }
    }

    static if (is(T == BSON))
      alias bval = value;
    else
      auto bval = BSON(value);

    newcont.put(cast(ubyte) bval.type);
    putCString(newcont, idx);
    newcont.put(bval.data);

    auto newdata = appender!bdata_t();
    newdata.put(toBSONData(cast(uint)(newcont.data.length + 5)));
    newdata.put(newcont.data);
    newdata.put(cast(ubyte) 0);
    m_data = newdata.data;
  }

  ///
  unittest {
    BSON value = BSON.emptyObject;
    value["a"] = 1;
    value["b"] = true;
    value["c"] = "foo";
    assert(value["a"] == BSON(1));
    assert(value["b"] == BSON(true));
    assert(value["c"] == BSON("foo"));
  }

  ///
  unittest {
    auto srcUuid = UUID("00010203-0405-0607-0809-0a0b0c0d0e0f");

    BSON b = srcUuid;
    auto u = b.get!UUID();

    assert(b.type == BSON.Type.binData);
    assert(b.get!BSONBinData().type == BSONBinData.Type.uuid);
    assert(u == srcUuid);
  }

  /** Allows index based access of a BSON array value.

		Returns a null value if the index is out of bounds.
	*/
  inout(BSON) opIndex(size_t idx) inout {
    foreach (size_t i, v; this.byIndexValue)
      if (i == idx)
        return v;
    return BSON(null);
  }

  ///
  unittest {
    BSON[] entries;
    entries ~= BSON(1);
    entries ~= BSON(true);
    entries ~= BSON("foo");

    BSON value = BSON(entries);
    assert(value[0] == BSON(1));
    assert(value[1] == BSON(true));
    assert(value[2] == BSON("foo"));
  }

  /** Removes an entry from a BSON obect.

		If the key doesn't exit, this function will be a no-op.
	*/
  void remove(string key) {
    checkType(Type.object);
    auto d = m_data[4 .. $];
    while (d.length > 0) {
      size_t start_remainder = d.length;
      auto tp = cast(Type) d[0];
      if (tp == Type.end)
        break;
      d = d[1 .. $];
      auto ekey = skipCString(d);
      auto evalue = BSON(tp, d);
      d = d[evalue.data.length .. $];

      if (ekey == key) {
        m_data = m_data[0 .. $ - start_remainder] ~ d;
        break;
      }
    }
  }

  unittest {
    auto o = BSON.emptyObject;
    o["a"] = BSON(1);
    o["b"] = BSON(2);
    o["c"] = BSON(3);
    assert(o.length == 3);
    o.remove("b");
    assert(o.length == 2);
    assert(o["a"] == BSON(1));
    assert(o["c"] == BSON(3));
    o.remove("c");
    assert(o.length == 1);
    assert(o["a"] == BSON(1));
    o.remove("c");
    assert(o.length == 1);
    assert(o["a"] == BSON(1));
    o.remove("a");
    assert(o.length == 0);
  }

  /**
		Allows foreach iterating over BSON objects and arrays.
	*/
  int opApply(scope int delegate(BSON obj) del) const @system {
    foreach (value; byValue)
      if (auto ret = del(value))
        return ret;
    return 0;
  }
  /// ditto
  int opApply(scope int delegate(size_t idx, BSON obj) del) const @system {
    foreach (index, value; byIndexValue)
      if (auto ret = del(index, value))
        return ret;
    return 0;
  }
  /// ditto
  int opApply(scope int delegate(string idx, BSON obj) del) const @system {
    foreach (key, value; byKeyValue)
      if (auto ret = del(key, value))
        return ret;
    return 0;
  }

  /// Iterates over all values of an object or array.
  auto byValue() const {
    checkType(Type.array, Type.object);
    return byKeyValueImpl().map!(t => t[1]);
  }
  /// Iterates over all index/value pairs of an array.
  auto byIndexValue() const {
    checkType(Type.array);
    return byKeyValueImpl().map!(t => Tuple!(size_t, "key", BSON, "value")(t[0].to!size_t, t[1]));
  }
  /// Iterates over all key/value pairs of an object.
  auto byKeyValue() const {
    checkType(Type.object);
    return byKeyValueImpl();
  }

  private auto byKeyValueImpl() const {
    checkType(Type.object, Type.array);

    alias T = Tuple!(string, "key", BSON, "value");

    static struct Rng {
      private {
        immutable(ubyte)[] data;
        string key;
        BSON value;
      }

      @property bool empty() const {
        return data.length == 0;
      }

      @property T front() {
        return T(key, value);
      }

      @property Rng save() const {
        return this;
      }

      void popFront() {
        auto tp = cast(Type) data[0];
        data = data[1 .. $];
        if (tp == Type.end)
          return;
        key = skipCString(data);
        value = BSON(tp, data);
        data = data[value.data.length .. $];
      }
    }

    auto ret = Rng(m_data[4 .. $]);
    ret.popFront();
    return ret;
  }

  ///
  bool opEquals(ref const BSON other) const {
    if (m_type != other.m_type)
      return false;
    if (m_type != Type.object)
      return m_data == other.m_data;

    if (m_data == other.m_data)
      return true;
    // Similar objects can have a different key order, but they must have a same length
    if (m_data.length != other.m_data.length)
      return false;

    foreach (k, ref v; this.byKeyValue) {
      if (other[k] != v)
        return false;
    }

    return true;
  }
  /// ditto
  bool opEquals(const BSON other) const {
    if (m_type != other.m_type)
      return false;

    return opEquals(other);
  }

  private void checkType(in Type[] valid_types...) const {
    foreach (t; valid_types)
      if (m_type == t)
        return;
    throw new Exception("BSON value is type '" ~ to!string(
        m_type) ~ "', expected to be one of " ~ to!string(valid_types));
  }
}

/**
	Represents a BSON binary data value (BSON.Type.binData).
*/
struct BSONBinData {
@safe:

  enum Type : ubyte {
    generic = 0x00,
    function_ = 0x01,
    binaryOld = 0x02,
    uuid = 0x04,
    md5 = 0x05,
    userDefined = 0x80,

    Generic = generic, /// Compatibility alias - will be deprecated soon
    Function = function_, /// Compatibility alias - will be deprecated soon
    BinaryOld = binaryOld, /// Compatibility alias - will be deprecated soon
    UUID = uuid, /// Compatibility alias - will be deprecated soon
    MD5 = md5, /// Compatibility alias - will be deprecated soon
    UserDefined = userDefined, /// Compatibility alias - will be deprecated soon
  }

  private {
    Type m_type;
    bdata_t m_data;
  }

  this(Type type, immutable(ubyte)[] data) {
    m_type = type;
    m_data = data;
  }

  @property Type type() const {
    return m_type;
  }

  @property bdata_t rawData() const {
    return m_data;
  }
}

/**
	Represents a BSON object id (BSON.Type.binData).
*/
struct BSONObjectID {
@safe:

  private {
    ubyte[12] m_bytes;
    static immutable uint MACHINE_ID;
    static immutable int ms_pid;
    static uint ms_inc = 0;
  }

  shared static this() {
    import std.process;
    import std.random;

    MACHINE_ID = uniform(0, 0xffffff);
    ms_pid = thisProcessID;
  }

  static this() {
    import std.random;

    ms_inc = uniform(0, 0xffffff);
  }

  /** Constructs a new object ID from the given raw byte array.
	*/
  this(in ubyte[] bytes) {
    assert(bytes.length == 12);
    m_bytes[] = bytes[];
  }

  /** Creates an on object ID from a string in standard hexa-decimal form.
	*/
  static BSONObjectID fromString(string str) {
    import std.conv : ConvException;

    static const lengthex = new ConvException("BSON Object ID string must be 24 characters.");
    static const charex = new ConvException("Not a valid hex string.");

    if (str.length != 24)
      throw lengthex;
    BSONObjectID ret = void;
    uint b = 0;
    foreach (i, ch; str) {
      ubyte n;
      if (ch >= '0' && ch <= '9')
        n = cast(ubyte)(ch - '0');
      else if (ch >= 'a' && ch <= 'f')
        n = cast(ubyte)(ch - 'a' + 10);
      else if (ch >= 'A' && ch <= 'F')
        n = cast(ubyte)(ch - 'F' + 10);
      else
        throw charex;
      b <<= 4;
      b += n;
      if (i % 8 == 7) {
        auto j = i / 8;
        ret.m_bytes[j * 4 .. (j + 1) * 4] = toBigEndianData(b)[];
        b = 0;
      }
    }
    return ret;
  }
  /// ditto
  alias fromHexString = fromString;

  /** Generates a unique object ID.
	 *
	 *   By default it will use `Clock.currTime(UTC())` as the timestamp
	 *   which guarantees that `BSONObjectID`s are chronologically
	 *   sorted.
	*/
  static BSONObjectID generate(in SysTime time = Clock.currTime(UTC())) {
    import std.datetime;

    BSONObjectID ret = void;
    ret.m_bytes[0 .. 4] = toBigEndianData(cast(uint) time.toUnixTime())[];
    ret.m_bytes[4 .. 7] = toBSONData(MACHINE_ID)[0 .. 3];
    ret.m_bytes[7 .. 9] = toBSONData(cast(ushort) ms_pid)[];
    ret.m_bytes[9 .. 12] = toBigEndianData(ms_inc++)[1 .. 4];
    return ret;
  }

  /** Creates a pseudo object ID that matches the given date.

		This kind of ID can be useful to query a database for items in a certain
		date interval using their ID. This works using the property of standard BSON
		object IDs that they store their creation date as part of the ID. Note that
		this date part is only 32-bit wide and is limited to the same timespan as a
		32-bit Unix timestamp.
	*/
  static BSONObjectID createDateID(in SysTime time) {
    BSONObjectID ret;
    ret.m_bytes[0 .. 4] = toBigEndianData(cast(uint) time.toUnixTime())[];
    return ret;
  }

  /** Returns true for any non-zero ID.
	*/
  @property bool valid() const {
    foreach (b; m_bytes)
      if (b != 0)
        return true;
    return false;
  }

  /** Extracts the time/date portion of the object ID.

		For IDs created using the standard generation algorithm or using createDateID
		this will return the associated time stamp.
	*/
  @property SysTime timeStamp() const {
    ubyte[4] tm = m_bytes[0 .. 4];
    return SysTime(unixTimeToStdTime(bigEndianToNative!uint(tm)));
  }

  /** Allows for relational comparison of different IDs.
	*/
  int opCmp(ref const BSONObjectID other) const {
    import core.stdc.string;

    return () @trusted {
      return memcmp(m_bytes.ptr, other.m_bytes.ptr, m_bytes.length);
    }();
  }

  /** Converts the ID to its standard hexa-decimal string representation.
	*/
  string toString() const pure {
    enum hexdigits = "0123456789abcdef";
    auto ret = new char[24];
    foreach (i, b; m_bytes) {
      ret[i * 2 + 0] = hexdigits[(b >> 4) & 0x0F];
      ret[i * 2 + 1] = hexdigits[b & 0x0F];
    }
    return ret;
  }

  inout(ubyte)[] opCast() inout {
    return m_bytes;
  }
}

unittest {
  auto t0 = SysTime(Clock.currTime(UTC()).toUnixTime.unixTimeToStdTime);
  auto id = BSONObjectID.generate();
  auto t1 = SysTime(Clock.currTime(UTC()).toUnixTime.unixTimeToStdTime);
  assert(t0 <= id.timeStamp);
  assert(id.timeStamp <= t1);

  id = BSONObjectID.generate(t0);
  assert(id.timeStamp == t0);

  id = BSONObjectID.generate(t1);
  assert(id.timeStamp == t1);

  immutable dt = DateTime(2014, 07, 31, 19, 14, 55);
  id = BSONObjectID.generate(SysTime(dt, UTC()));
  assert(id.timeStamp == SysTime(dt, UTC()));
}

unittest {
  auto b = BSON(true);
  assert(b.opt!bool(false) == true);
  assert(b.opt!int(12) == 12);
  assert(b.opt!(BSON[])(null).length == 0);

  const c = b;
  assert(c.opt!bool(false) == true);
  assert(c.opt!int(12) == 12);
  assert(c.opt!(BSON[])(null).length == 0);
}

/**
	Represents a BSON date value (`BSON.Type.date`).

	BSON date values are stored in UNIX time format, counting the number of
	milliseconds from 1970/01/01.
*/
struct BSONDate {
@safe:

  private long m_time; // milliseconds since UTC unix epoch

  /** Constructs a BSONDate from the given date value.

		The time-zone independent Date and DateTime types are assumed to be in
		the local time zone and converted to UTC if tz is left to null.
	*/
  this(in Date date, immutable TimeZone tz = null) {
    this(SysTime(date, tz));
  }
  /// ditto
  this(in DateTime date, immutable TimeZone tz = null) {
    this(SysTime(date, tz));
  }
  /// ditto
  this(in SysTime date) {
    this(fromStdTime(date.stdTime()).m_time);
  }

  /** Constructs a BSONDate from the given UNIX time.

		unix_time needs to be given in milliseconds from 1970/01/01. This is
		the native storage format for BSONDate.
	*/
  this(long unix_time) {
    m_time = unix_time;
  }

  /** Constructs a BSONDate from the given date/time string in ISO extended format.
	*/
  static BSONDate fromString(string iso_ext_string) {
    return BSONDate(SysTime.fromISOExtString(iso_ext_string));
  }

  /** Constructs a BSONDate from the given date/time in standard time as defined in `std.datetime`.
	*/
  static BSONDate fromStdTime(long std_time) {
    enum zero = unixTimeToStdTime(0);
    return BSONDate((std_time - zero) / 10_000L);
  }

  /** The raw unix time value.

		This is the native storage/transfer format of a BSONDate.
	*/
  @property long value() const {
    return m_time;
  }
  /// ditto
  @property void value(long v) {
    m_time = v;
  }

  /** Returns the date formatted as ISO extended format.
	*/
  string toString() const {
    return toSysTime().toISOExtString();
  }

  /* Converts to a SysTime using UTC timezone.
	*/
  SysTime toSysTime() const {
    return toSysTime(UTC());
  }

  /* Converts to a SysTime with a given timezone.
	*/
  SysTime toSysTime(immutable TimeZone tz) const {
    auto zero = unixTimeToStdTime(0);
    return SysTime(zero + m_time * 10_000L, tz);
  }

  /** Allows relational and equality comparisons.
	*/
  bool opEquals(ref const BSONDate other) const {
    return m_time == other.m_time;
  }
  /// ditto
  int opCmp(ref const BSONDate other) const {
    if (m_time == other.m_time)
      return 0;
    if (m_time < other.m_time)
      return -1;
    else
      return 1;
  }
}

/**
	Represents a BSON timestamp value `(BSON.Type.timestamp)`.
*/
struct BSONTimestamp {
@safe:

  private long m_time;

  this(long time) {
    m_time = time;
  }
}

/**
	Represents a BSON regular expression value `(BSON.Type.regex)`.
*/
struct BSONRegex {
@safe:

  private {
    string m_expr;
    string m_options;
  }

  this(string expr, string options) {
    m_expr = expr;
    m_options = options;
  }

  @property string expression() const {
    return m_expr;
  }

  @property string options() const {
    return m_options;
  }
}

/**
	Serializes the given value to BSON.

	The following types of values are supported:

	$(DL
		$(DT `BSON`)            $(DD Used as-is)
		$(DT `JSON`)            $(DD Converted to BSON)
		$(DT `BSONBinData`)     $(DD Converted to `BSON.Type.binData`)
		$(DT `BSONObjectID`)    $(DD Converted to `BSON.Type.objectID`)
		$(DT `BSONDate`)        $(DD Converted to `BSON.Type.date`)
		$(DT `BSONTimestamp`)   $(DD Converted to `BSON.Type.timestamp`)
		$(DT `BSONRegex`)       $(DD Converted to `BSON.Type.regex`)
		$(DT `null`)            $(DD Converted to `BSON.Type.null_`)
		$(DT `bool`)            $(DD Converted to `BSON.Type.bool_`)
		$(DT `float`, `double`)   $(DD Converted to `BSON.Type.double_`)
		$(DT `short`, `ushort`, `int`, `uint`, `long`, `ulong`) $(DD Converted to `BSON.Type.long_`)
		$(DT `string`)          $(DD Converted to `BSON.Type.string`)
		$(DT `ubyte[]`)         $(DD Converted to `BSON.Type.binData`)
		$(DT `T[]`)             $(DD Converted to `BSON.Type.array`)
		$(DT `T[string]`)       $(DD Converted to `BSON.Type.object`)
		$(DT `struct`)          $(DD Converted to `BSON.Type.object`)
		$(DT `class`)           $(DD Converted to `BSON.Type.object` or `BSON.Type.null_`)
	)

	All entries of an array or an associative array, as well as all R/W properties and
	all fields of a struct/class are recursively serialized using the same rules.

	Fields ending with an underscore will have the last underscore stripped in the
	serialized output. This makes it possible to use fields with D keywords as their name
	by simply appending an underscore.

	The following methods can be used to customize the serialization of structs/classes:

	---
	BSON toBSON() const;
	static T fromBSON(BSON src);

	JSON toJSON() const;
	static T fromJSON(JSON src);

	string toString() const;
	static T fromString(string src);
	---

	The methods will have to be defined in pairs. The first pair that is implemented by
	the type will be used for serialization (i.e. `toBSON` overrides `toJSON`).

	See_Also: `deserializeBSON`
*/
import dutils.data.utils.serialization;

BSON serializeToBSON(T)(auto ref T value, ubyte[] buffer = null) {
  return serialize!BSONSerializer(value, buffer);
}

template deserializeBSON(T) {
  /**
		Deserializes a BSON value into the destination variable.

		The same types as for `serializeToBSON()` are supported and handled inversely.

		See_Also: `serializeToBSON`
	*/
  void deserializeBSON(ref T dst, BSON src) {
    dst = deserializeBSON!T(src);
  }
  /// ditto
  T deserializeBSON(BSON src) {
    return deserialize!(BSONSerializer, T)(src);
  }
}

unittest {
  import std.stdio;

  enum Foo : string {
    k = "test"
  }

  enum Boo : int {
    l = 5
  }

  static struct S {
    float a;
    double b;
    bool c;
    int d;
    string e;
    byte f;
    ubyte g;
    long h;
    ulong i;
    float[] j;
    Foo k;
    Boo l;
  }

  immutable S t = {
    1.5, -3.0, true, int.min, "Test", -128, 255, long.min, ulong.max, [
      1.1, 1.2, 1.3
    ], Foo.k, Boo.l,};
    S u;
    deserializeBSON(u, serializeToBSON(t));
    assert(t.a == u.a);
    assert(t.b == u.b);
    assert(t.c == u.c);
    assert(t.d == u.d);
    assert(t.e == u.e);
    assert(t.f == u.f);
    assert(t.g == u.g);
    assert(t.h == u.h);
    assert(t.i == u.i);
    assert(t.j == u.j);
    assert(t.k == u.k);
    assert(t.l == u.l);
  }

  unittest {
    assert(uint.max == serializeToBSON(uint.max).deserializeBSON!uint);
    assert(ulong.max == serializeToBSON(ulong.max).deserializeBSON!ulong);
  }

  unittest {
    assert(deserializeBSON!SysTime(serializeToBSON(SysTime(0))) == SysTime(0));
    assert(deserializeBSON!SysTime(serializeToBSON(SysTime(0, UTC()))) == SysTime(0, UTC()));
    assert(deserializeBSON!Date(serializeToBSON(Date.init)) == Date.init);
    assert(deserializeBSON!Date(serializeToBSON(Date(2001, 1, 1))) == Date(2001, 1, 1));
  }

  @safe unittest {
    static struct A {
      int value;
      static A fromJSON(JSON val) @safe {
        return A(val.get!int);
      }

      JSON toJSON() const @safe {
        return JSON(value);
      }

      BSON toBSON() {
        return BSON();
      }
    }

    static assert(!isStringSerializable!A && isJSONSerializable!A && !isBSONSerializable!A);
    static assert(!isStringSerializable!(const(A))
        && isJSONSerializable!(const(A)) && !isBSONSerializable!(const(A)));
    //	assert(serializeToBSON(const A(123)) == BSON(123));
    //	assert(serializeToBSON(A(123))       == BSON(123));

    static struct B {
      int value;
      static B fromBSON(BSON val) @safe {
        return B(val.get!int);
      }

      BSON toBSON() const @safe {
        return BSON(value);
      }

      JSON toJSON() {
        return JSON();
      }
    }

    static assert(!isStringSerializable!B && !isJSONSerializable!B && isBSONSerializable!B);
    static assert(!isStringSerializable!(const(B))
        && !isJSONSerializable!(const(B)) && isBSONSerializable!(const(B)));
    assert(serializeToBSON(const B(123)) == BSON(123));
    assert(serializeToBSON(B(123)) == BSON(123));

    static struct C {
      int value;
      static C fromString(string val) @safe {
        return C(val.to!int);
      }

      string toString() const @safe {
        return value.to!string;
      }

      JSON toJSON() {
        return JSON();
      }
    }

    static assert(isStringSerializable!C && !isJSONSerializable!C && !isBSONSerializable!C);
    static assert(isStringSerializable!(const(C))
        && !isJSONSerializable!(const(C)) && !isBSONSerializable!(const(C)));
    assert(serializeToBSON(const C(123)) == BSON("123"));
    assert(serializeToBSON(C(123)) == BSON("123"));

    static struct D {
      int value;
      string toString() const {
        return "";
      }
    }

    static assert(!isStringSerializable!D && !isJSONSerializable!D && !isBSONSerializable!D);
    static assert(!isStringSerializable!(const(D))
        && !isJSONSerializable!(const(D)) && !isBSONSerializable!(const(D)));
    assert(serializeToBSON(const D(123)) == serializeToBSON(["value": 123]));
    assert(serializeToBSON(D(123)) == serializeToBSON(["value": 123]));

    // test if const(class) is serializable
    static class E {
      int value;
      this(int v) @safe {
        value = v;
      }

      static E fromBSON(BSON val) @safe {
        return new E(val.get!int);
      }

      BSON toBSON() const @safe {
        return BSON(value);
      }

      JSON toJSON() {
        return JSON();
      }
    }

    static assert(!isStringSerializable!E && !isJSONSerializable!E && isBSONSerializable!E);
    static assert(!isStringSerializable!(const(E))
        && !isJSONSerializable!(const(E)) && isBSONSerializable!(const(E)));
    assert(serializeToBSON(new const E(123)) == BSON(123));
    assert(serializeToBSON(new E(123)) == BSON(123));
  }

  @safe unittest {
    static struct E {
      ubyte[4] bytes;
      ubyte[] more;
    }

    auto e = E([1, 2, 3, 4], [5, 6]);
    auto eb = serializeToBSON(e);
    assert(eb["bytes"].type == BSON.Type.binData);
    assert(eb["more"].type == BSON.Type.binData);
    assert(e == deserializeBSON!E(eb));
  }

  @safe unittest {
    static class C {
    @safe:
      int a;
      private int _b;
      @property int b() const {
        return _b;
      }

      @property void b(int v) {
        _b = v;
      }

      @property int test() const @safe {
        return 10;
      }

      void test2() {
      }
    }

    C c = new C;
    c.a = 1;
    c.b = 2;

    C d;
    deserializeBSON(d, serializeToBSON(c));
    assert(c.a == d.a);
    assert(c.b == d.b);

    const(C) e = c; // serialize const class instances (issue #653)
    deserializeBSON(d, serializeToBSON(e));
    assert(e.a == d.a);
    assert(e.b == d.b);
  }

  unittest {
    static struct C {
    @safe:
      int value;
      static C fromString(string val) {
        return C(val.to!int);
      }

      string toString() const {
        return value.to!string;
      }
    }

    enum Color {
      Red,
      Green,
      Blue
    }

    {
      static class T {
      @safe:
        string[Color] enumIndexedMap;
        string[C] stringableIndexedMap;
        this() {
          enumIndexedMap = [Color.Red: "magenta", Color.Blue: "deep blue"];
          stringableIndexedMap = [C(42): "forty-two"];
        }
      }

      T original = new T;
      original.enumIndexedMap[Color.Green] = "olive";
      T other;
      deserializeBSON(other, serializeToBSON(original));
      assert(serializeToBSON(other) == serializeToBSON(original));
    }
    {
      static struct S {
        string[Color] enumIndexedMap;
        string[C] stringableIndexedMap;
      }

      S original;
      original.enumIndexedMap = [Color.Red: "magenta", Color.Blue: "deep blue"];
      original.enumIndexedMap[Color.Green] = "olive";
      original.stringableIndexedMap = [C(42): "forty-two"];
      S other;
      deserializeBSON(other, serializeToBSON(original));
      assert(serializeToBSON(other) == serializeToBSON(original));
    }
  }

  unittest {
    ubyte[] data = [1, 2, 3];
    auto BSON = serializeToBSON(data);
    assert(BSON.type == BSON.Type.binData);
    assert(deserializeBSON!(ubyte[])(BSON) == data);
  }

  unittest { // issue #709
    ulong[] data = [2354877787627192443, 1, 2354877787627192442];
    auto BSON = BSON.fromJSON(serializeToBSON(data).toJSON);
    assert(deserializeBSON!(ulong[])(BSON) == data);
  }

  unittest { // issue #709
    uint[] data = [1, 2, 3, 4];
    auto BSON = BSON.fromJSON(serializeToBSON(data).toJSON);
    //	assert(deserializeBSON!(uint[])(BSON) == data);
    assert(deserializeBSON!(ulong[])(BSON).equal(data));
  }

  unittest {
    import std.typecons;

    Nullable!bool x;
    auto BSON = serializeToBSON(x);
    assert(BSON.type == BSON.Type.null_);
    deserializeBSON(x, BSON);
    assert(x.isNull);
    x = true;
    BSON = serializeToBSON(x);
    assert(BSON.type == BSON.Type.bool_ && BSON.get!bool == true);
    deserializeBSON(x, BSON);
    assert(x == true);
  }

  unittest { // issue #793
    char[] test = "test".dup;
    auto BSON = serializeToBSON(test);
    //assert(BSON.type == BSON.Type.string);
    //assert(BSON.get!string == "test");
    assert(BSON.type == BSON.Type.array);
    assert(BSON[0].type == BSON.Type.string && BSON[0].get!string == "t");
  }

  @safe unittest { // issue #2212
    auto bsonRegex = BSON(BSONRegex(".*", "i"));
    auto parsedRegex = bsonRegex.get!BSONRegex;
    assert(bsonRegex.type == BSON.Type.regex);
    assert(parsedRegex.expression == ".*");
    assert(parsedRegex.options == "i");
  }

  unittest {
    UUID uuid = UUID("35399104-fbc9-4c08-bbaf-65a5efe6f5f2");

    auto bson = BSON(uuid);
    assert(bson.get!UUID == uuid);
    assert(bson.deserializeBSON!UUID == uuid);

    bson = BSON([BSON(uuid)]);
    assert(bson.deserializeBSON!(UUID[]) == [uuid]);

    bson = [uuid].serializeToBSON();
    assert(bson.deserializeBSON!(UUID[]) == [uuid]);
  }

  /**
	Serializes to an in-memory BSON representation.

	See_Also: `vibe.data.serialization.serialize`, `vibe.data.serialization.deserialize`, `serializeToBSON`, `deserializeBSON`
*/
  struct BSONSerializer {
    import dutils.data.utils.array : AllocAppender;

    private {
      AllocAppender!(ubyte[]) m_dst;
      size_t[] m_compositeStack;
      BSON.Type m_type = BSON.Type.null_;
      BSON m_inputData;
      string m_entryName;
      size_t m_entryIndex = size_t.max;
    }

    this(BSON input) @safe {
      m_inputData = input;
    }

    this(ubyte[] buffer) @safe {
      import dutils.data.utils.utilallocator;

      m_dst = () @trusted {
        return AllocAppender!(ubyte[])(vibeThreadAllocator(), buffer);
      }();
    }

    @disable this(this);

    template isSupportedValueType(T) {
      enum isSupportedValueType = is(typeof(getBSONTypeID(T.init)));
    }

    //
    // serialization
    //
    BSON getSerializedResult() @safe {
      auto ret = BSON(m_type, () @trusted { return cast(immutable) m_dst.data; }());
      () @trusted { m_dst.reset(); }();
      m_type = BSON.Type.null_;
      return ret;
    }

    void beginWriteDictionary(Traits)() {
      writeCompositeEntryHeader(BSON.Type.object);
      m_compositeStack ~= m_dst.data.length;
      m_dst.put(toBSONData(cast(int) 0));
    }

    void endWriteDictionary(Traits)() {
      m_dst.put(BSON.Type.end);
      auto sh = m_compositeStack[$ - 1];
      m_compositeStack.length--;
      m_dst.data[sh .. sh + 4] = toBSONData(cast(uint)(m_dst.data.length - sh))[];
    }

    void beginWriteDictionaryEntry(Traits)(string name) {
      m_entryName = name;
    }

    void endWriteDictionaryEntry(Traits)(string name) {
    }

    void beginWriteArray(Traits)(size_t) {
      writeCompositeEntryHeader(BSON.Type.array);
      m_compositeStack ~= m_dst.data.length;
      m_dst.put(toBSONData(cast(int) 0));
    }

    void endWriteArray(Traits)() {
      endWriteDictionary!Traits();
    }

    void beginWriteArrayEntry(Traits)(size_t idx) {
      m_entryIndex = idx;
    }

    void endWriteArrayEntry(Traits)(size_t idx) {
    }

    void writeValue(Traits, T)(auto ref T value) {
      writeValueH!(T, true)(value);
    }

    private void writeValueH(T, bool write_header)(auto ref T value) {
      alias UT = Unqual!T;
      static if (write_header)
        writeCompositeEntryHeader(getBSONTypeID(value));

      static if (is(UT == BSON)) {
        m_dst.put(value.data);
      } else static if (is(UT == JSON)) {
        m_dst.put(BSON(value).data);
      }  // FIXME: use .writeBSONValue
      else static if (is(UT == typeof(null))) {
      } else static if (is(UT == string)) {
        m_dst.put(toBSONData(cast(uint) value.length + 1));
        m_dst.putCString(value);
      } else static if (is(UT == BSONBinData)) {
        m_dst.put(toBSONData(cast(int) value.rawData.length));
        m_dst.put(value.type);
        m_dst.put(value.rawData);
      } else static if (is(UT == BSONObjectID)) {
        m_dst.put(value.m_bytes[]);
      } else static if (is(UT == BSONDate)) {
        m_dst.put(toBSONData(value.m_time));
      } else static if (is(UT == SysTime)) {
        m_dst.put(toBSONData(BSONDate(value).m_time));
      } else static if (is(UT == BSONRegex)) {
        m_dst.putCString(value.expression);
        m_dst.putCString(value.options);
      } else static if (is(UT == BSONTimestamp)) {
        m_dst.put(toBSONData(value.m_time));
      } else static if (is(UT == bool)) {
        m_dst.put(cast(ubyte)(value ? 0x01 : 0x00));
      } else static if (is(UT : int) && isIntegral!UT) {
        m_dst.put(toBSONData(cast(int) value));
      } else static if (is(UT : long) && isIntegral!UT) {
        m_dst.put(toBSONData(value));
      } else static if (is(UT : double) && isFloatingPoint!UT) {
        m_dst.put(toBSONData(cast(double) value));
      } else static if (is(UT == UUID)) {
        m_dst.put(BSON(value).data);
      } else static if (isBSONSerializable!UT) {
        static if (!__traits(compiles, ()@safe { return value.toBSON(); }()))
          pragma(msg,
              "Non-@safe toBSON/fromBSON methods are deprecated - annotate "
              ~ T.stringof ~ ".toBSON() with @safe.");
        m_dst.put(() @trusted { return value.toBSON(); }().data);
      } else static if (isJSONSerializable!UT) {
        static if (!__traits(compiles, ()@safe { return value.toJSON(); }()))
          pragma(msg,
              "Non-@safe toJSON/fromJSON methods are deprecated - annotate "
              ~ UT.stringof ~ ".toJSON() with @safe.");
        m_dst.put(BSON(() @trusted { return value.toJSON(); }()).data);
      } else static if (is(UT : const(ubyte)[])) {
        writeValueH!(BSONBinData, false)(BSONBinData(BSONBinData.Type.generic, value.idup));
      } else
        static assert(false, "Unsupported type: " ~ UT.stringof);
    }

    private void writeCompositeEntryHeader(BSON.Type tp) @safe {
      if (!m_compositeStack.length) {
        assert(m_type == BSON.Type.null_, "Overwriting root item.");
        m_type = tp;
      }

      if (m_entryName !is null) {
        m_dst.put(tp);
        m_dst.putCString(m_entryName);
        m_entryName = null;
      } else if (m_entryIndex != size_t.max) {
        import std.format;

        m_dst.put(tp);
        static struct Wrapper {
        @trusted:
          AllocAppender!(ubyte[])* app;
          void put(char ch) {
            (*app).put(ch);
          }

          void put(in char[] str) {
            (*app).put(cast(const(ubyte)[]) str);
          }
        }

        auto wr = Wrapper(&m_dst);
        wr.formattedWrite("%d\0", m_entryIndex);
        m_entryIndex = size_t.max;
      }
    }

    //
    // deserialization
    //
    void readDictionary(Traits)(scope void delegate(string) @safe entry_callback) {
      enforce(m_inputData.type == BSON.Type.object,
          "Expected object instead of " ~ m_inputData.type.to!string());
      auto old = m_inputData;
      foreach (string name, value; old.byKeyValue) {
        m_inputData = value;
        entry_callback(name);
      }
      m_inputData = old;
    }

    void beginReadDictionaryEntry(Traits)(string name) {
    }

    void endReadDictionaryEntry(Traits)(string name) {
    }

    void readArray(Traits)(scope void delegate(size_t) @safe size_callback,
        scope void delegate() @safe entry_callback) {
      enforce(m_inputData.type == BSON.Type.array,
          "Expected array instead of " ~ m_inputData.type.to!string());
      auto old = m_inputData;
      foreach (value; old.byValue) {
        m_inputData = value;
        entry_callback();
      }
      m_inputData = old;
    }

    void beginReadArrayEntry(Traits)(size_t index) {
    }

    void endReadArrayEntry(Traits)(size_t index) {
    }

    T readValue(Traits, T)() {
      static if (is(T == BSON))
        return m_inputData;
      else static if (is(T == JSON))
        return m_inputData.toJSON();
      else static if (is(T == bool))
        return m_inputData.get!bool();
      else static if (is(T == uint))
        return cast(T) m_inputData.get!int();
      else static if (is(T : int)) {
        if (m_inputData.type == BSON.Type.long_) {
          enforce((m_inputData.get!long() >= int.min) && (m_inputData.get!long() <= int.max),
              "Long out of range while attempting to deserialize to int: " ~ m_inputData.get!long
              .to!string);
          return cast(T) m_inputData.get!long();
        } else
          return m_inputData.get!int().to!T;
      } else static if (is(T : long)) {
        if (m_inputData.type == BSON.Type.int_)
          return cast(T) m_inputData.get!int();
        else
          return cast(T) m_inputData.get!long();
      } else static if (is(T : double))
        return cast(T) m_inputData.get!double();
      else static if (is(T == SysTime)) {
        // support legacy behavior to serialize as string
        if (m_inputData.type == BSON.Type.string)
          return SysTime.fromISOExtString(m_inputData.get!string);
        else
          return m_inputData.get!BSONDate().toSysTime();
      } else static if (isBSONSerializable!T) {
        static if (!__traits(compiles, ()@safe { return T.fromBSON(BSON.init); }()))
          pragma(msg,
              "Non-@safe toBSON/fromBSON methods are deprecated - annotate "
              ~ T.stringof ~ ".fromBSON() with @safe.");
        auto bval = readValue!(Traits, BSON);
        return () @trusted { return T.fromBSON(bval); }();
      } else static if (isJSONSerializable!T) {
        static if (!__traits(compiles, ()@safe { return T.fromJSON(JSON.init); }()))
          pragma(msg,
              "Non-@safe toJSON/fromJSON methods are deprecated - annotate "
              ~ T.stringof ~ ".fromJSON() with @safe.");
        auto jval = readValue!(Traits, BSON).toJSON();
        return () @trusted { return T.fromJSON(jval); }();
      } else static if (is(T : const(ubyte)[])) {
        auto ret = m_inputData.get!BSONBinData.rawData;
        static if (isStaticArray!T)
          return cast(T) ret[0 .. T.length];
        else static if (is(T : immutable(char)[]))
          return ret;
        else
          return cast(T) ret.dup;
      } else
        return m_inputData.get!T();
    }

    bool tryReadNull(Traits)() {
      if (m_inputData.type == BSON.Type.null_)
        return true;
      return false;
    }

    private static BSON.Type getBSONTypeID(T, bool accept_ao = false)(auto ref T value) @safe {
      alias UT = Unqual!T;
      BSON.Type tp;
      static if (is(T == BSON))
        tp = value.type;
      else static if (is(UT == JSON))
        tp = JSONTypeToBSONType(value.type);
      else static if (is(UT == typeof(null)))
        tp = BSON.Type.null_;
      else static if (is(UT == string))
        tp = BSON.Type.string;
      else static if (is(UT == BSONBinData))
        tp = BSON.Type.binData;
      else static if (is(UT == BSONObjectID))
        tp = BSON.Type.objectID;
      else static if (is(UT == BSONDate))
        tp = BSON.Type.date;
      else static if (is(UT == SysTime))
        tp = BSON.Type.date;
      else static if (is(UT == BSONRegex))
        tp = BSON.Type.regex;
      else static if (is(UT == BSONTimestamp))
        tp = BSON.Type.timestamp;
      else static if (is(UT == bool))
        tp = BSON.Type.bool_;
      else static if (isIntegral!UT && is(UT : int))
        tp = BSON.Type.int_;
      else static if (isIntegral!UT && is(UT : long))
        tp = BSON.Type.long_;
      else static if (isFloatingPoint!UT && is(UT : double))
        tp = BSON.Type.double_;
      else static if (isBSONSerializable!UT)
        tp = value.toBSON().type; // FIXME: this is highly inefficient
      else static if (isJSONSerializable!UT)
        tp = JSONTypeToBSONType(value.toJSON().type); // FIXME: this is highly inefficient
      else static if (is(UT == UUID))
        tp = BSON.Type.binData;
      else static if (is(UT : const(ubyte)[]))
        tp = BSON.Type.binData;
      else static if (accept_ao && isArray!UT)
        tp = BSON.Type.array;
      else static if (accept_ao && isAssociativeArray!UT)
        tp = BSON.Type.object;
      else static if (accept_ao && (is(UT == class) || is(UT == struct)))
        tp = BSON.Type.object;
      else
        static assert(false, "Unsupported type: " ~ UT.stringof);
      return tp;
    }
  }

  private BSON.Type JSONTypeToBSONType(JSON.Type tp) @safe {
    static immutable BSON.Type[JSON.Type.max + 1] JSONIDToBSONID = [
      BSON.Type.undefined, BSON.Type.null_, BSON.Type.bool_, BSON.Type.long_,
      BSON.Type.long_, BSON.Type.double_, BSON.Type.string, BSON.Type.array,
      BSON.Type.object
    ];
    return JSONIDToBSONID[tp];
  }

  private BSON.Type writeBSON(R)(ref R dst, in JSON value)
      if (isOutputRange!(R, ubyte)) {
    final switch (value.type) {
    case JSON.Type.undefined:
      return BSON.Type.undefined;
    case JSON.Type.null_:
      return BSON.Type.null_;
    case JSON.Type.bool_:
      dst.put(cast(ubyte)(cast(bool) value ? 0x01 : 0x00));
      return BSON.Type.bool_;
    case JSON.Type.int_:
      dst.put(toBSONData(cast(long) value));
      return BSON.Type.long_;
    case JSON.Type.bigInt:
      dst.put(toBSONData(cast(long) value));
      return BSON.Type.long_;
    case JSON.Type.float_:
      dst.put(toBSONData(cast(double) value));
      return BSON.Type.double_;
    case JSON.Type.string:
      dst.put(toBSONData(cast(uint) value.length + 1));
      dst.put(cast(bdata_t) cast(string) value);
      dst.put(cast(ubyte) 0);
      return BSON.Type.string;
    case JSON.Type.array:
      auto app = appender!bdata_t();
      foreach (size_t i, ref const JSON v; value) {
        app.put(cast(ubyte)(JSONTypeToBSONType(v.type)));
        putCString(app, to!string(i));
        writeBSON(app, v);
      }

      dst.put(toBSONData(cast(int)(app.data.length + int.sizeof + 1)));
      dst.put(app.data);
      dst.put(cast(ubyte) 0);
      return BSON.Type.array;
    case JSON.Type.object:
      auto app = appender!bdata_t();
      foreach (string k, ref const JSON v; value) {
        app.put(cast(ubyte)(JSONTypeToBSONType(v.type)));
        putCString(app, k);
        writeBSON(app, v);
      }

      dst.put(toBSONData(cast(int)(app.data.length + int.sizeof + 1)));
      dst.put(app.data);
      dst.put(cast(ubyte) 0);
      return BSON.Type.object;
    }
  }

  unittest {
    JSON jsvalue = parseJSONString("{\"key\" : \"Value\"}");
    assert(serializeToBSON(jsvalue).toJSON() == jsvalue);

    jsvalue = parseJSONString("{\"key\" : [{\"key\" : \"Value\"}, {\"key2\" : \"Value2\"}] }");
    assert(serializeToBSON(jsvalue).toJSON() == jsvalue);

    jsvalue = parseJSONString("[ 1 , 2 , 3]");
    assert(serializeToBSON(jsvalue).toJSON() == jsvalue);
  }

  unittest {
    static struct Pipeline(ARGS...) {
      @asArray ARGS pipeline;
    }

    auto getPipeline(ARGS...)(ARGS args) {
      return Pipeline!ARGS(args);
    }

    string[string] a = ["foo" : "bar"];
    int b = 42;

    auto fields = getPipeline(a, b).serializeToBSON()["pipeline"].get!(BSON[]);
    assert(fields[0]["foo"].get!string == "bar");
    assert(fields[1].get!int == 42);
  }

  private string skipCString(ref bdata_t data) @safe {
    auto idx = data.countUntil(0);
    enforce(idx >= 0, "Unterminated BSON C-string.");
    auto ret = data[0 .. idx];
    data = data[idx + 1 .. $];
    return cast(string) ret;
  }

  private void putCString(R)(ref R dst, string str) {
    dst.put(cast(bdata_t) str);
    dst.put(cast(ubyte) 0);
  }

  ubyte[] toBSONData(T)(T v) {
    /*static T tmp;
	tmp = nativeToLittleEndian(v);
	return cast(ubyte[])((&tmp)[0 .. 1]);*/
    if (__ctfe)
      return nativeToLittleEndian(v).dup;
    else {
      static ubyte[T.sizeof] ret;
      ret = nativeToLittleEndian(v);
      return ret;
    }
  }

  T fromBSONData(T)(in ubyte[] v) {
    assert(v.length >= T.sizeof);
    //return (cast(T[])v[0 .. T.sizeof])[0];
    ubyte[T.sizeof] vu = v[0 .. T.sizeof];
    return littleEndianToNative!T(vu);
  }

  ubyte[] toBigEndianData(T)(T v) {
    if (__ctfe)
      return nativeToBigEndian(v).dup;
    else {
      static ubyte[T.sizeof] ret;
      ret = nativeToBigEndian(v);
      return ret;
    }
  }

  private string underscoreStrip(string field_name) pure @safe {
    if (field_name.length < 1 || field_name[$ - 1] != '_')
      return field_name;
    else
      return field_name[0 .. $ - 1];
  }

  /// private
  package template isBSONSerializable(T) {
    enum isBSONSerializable = is(typeof(T.init.toBSON()) : BSON)
      && is(typeof(T.fromBSON(BSON())) : T);
  }
