# data

[![DUB Package](https://img.shields.io/dub/v/dutils-data.svg)](https://code.dlang.org/packages/dutils-data)
[![Posix Build Status](https://travis-ci.org/d-utils/data.svg?branch=master)](https://travis-ci.org/d-utils/data)

Various safer data functions (currently runs on Linux only)

## example

    import dutils.data : dataUUID;

    auto id = dataUUID();
