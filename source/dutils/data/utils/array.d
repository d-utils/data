/**
	Utility functions for array processing

	Copyright: © 2012 Sönke Ludwig
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/
module dutils.data.utils.array;

import dutils.data.utils.utilallocator;

import std.algorithm;
import std.range : isInputRange, isOutputRange;
import std.traits;
static import std.utf;

enum AppenderResetMode {
	keepData,
	freeData,
	reuseData
}

struct AllocAppender(ArrayType : E[], E) {
	alias ElemType = Unqual!E;

	static assert(!hasIndirections!E && !hasElaborateDestructor!E);

	private {
		ElemType[] m_data;
		ElemType[] m_remaining;
		IAllocator m_alloc;
		bool m_allocatedBuffer = false;
	}

	this(IAllocator alloc, ElemType[] initial_buffer = null) {
		m_alloc = alloc;
		m_data = initial_buffer;
		m_remaining = initial_buffer;
	}

	@disable this(this);

	@property ArrayType data() {
		return cast(ArrayType) m_data[0 .. m_data.length - m_remaining.length];
	}

	void reset(AppenderResetMode reset_mode = AppenderResetMode.keepData) {
		if (reset_mode == AppenderResetMode.keepData)
			m_data = null;
		else if (reset_mode == AppenderResetMode.freeData) {
			if (m_allocatedBuffer)
				m_alloc.deallocate(m_data);
			m_data = null;
		}
		m_remaining = m_data;
	}

	/** Grows the capacity of the internal buffer so that it can hold a minumum amount of elements.

		Params:
			amount = The minimum amount of elements that shall be appendable without
				triggering a re-allocation.

	*/
	void reserve(size_t amount) @trusted {
		size_t nelems = m_data.length - m_remaining.length;
		if (!m_data.length) {
			m_data = cast(ElemType[]) m_alloc.allocate(amount * E.sizeof);
			m_remaining = m_data;
			m_allocatedBuffer = true;
		}
		if (m_remaining.length < amount) {
			debug {
				import std.digest.crc;

				auto checksum = crc32Of(m_data[0 .. nelems]);
			}
			if (m_allocatedBuffer) {
				void[] vdata = m_data;
				m_alloc.reallocate(vdata, (nelems + amount) * E.sizeof);
				m_data = () @trusted { return cast(ElemType[]) vdata; }();
			} else {
				auto newdata = cast(ElemType[]) m_alloc.allocate((nelems + amount) * E.sizeof);
				newdata[0 .. nelems] = m_data[0 .. nelems];
				m_data = newdata;
				m_allocatedBuffer = true;
			}
			debug assert(crc32Of(m_data[0 .. nelems]) == checksum);
		}
		m_remaining = m_data[nelems .. m_data.length];
	}

	void put(E el) @safe {
		if (m_remaining.length == 0)
			grow(1);
		m_remaining[0] = el;
		m_remaining = m_remaining[1 .. $];
	}

	void put(ArrayType arr) @safe {
		if (m_remaining.length < arr.length)
			grow(arr.length);
		m_remaining[0 .. arr.length] = arr[];
		m_remaining = m_remaining[arr.length .. $];
	}

	static if (!hasAliasing!E) {
		void put(in ElemType[] arr) @trusted {
			put(cast(ArrayType) arr);
		}
	}

	static if (is(ElemType == char)) {
		void put(dchar el) @safe {
			if (el < 128)
				put(cast(char) el);
			else {
				char[4] buf;
				auto len = std.utf.encode(buf, el);
				put(() @trusted { return cast(ArrayType) buf[0 .. len]; }());
			}
		}
	}

	static if (is(ElemType == wchar)) {
		void put(dchar el) @safe {
			if (el < 128)
				put(cast(wchar) el);
			else {
				wchar[3] buf;
				auto len = std.utf.encode(buf, el);
				put(() @trusted { return cast(ArrayType) buf[0 .. len]; }());
			}
		}
	}

	static if (!is(E == immutable) || !hasAliasing!E) {
		/** Appends a number of bytes in-place.

			The delegate will get the memory slice of the memory that follows
			the already written data. Use `reserve` to ensure that this slice
			has enough room. The delegate should overwrite as much of the
			slice as desired and then has to return the number of elements
			that should be appended (counting from the start of the slice).
		*/
		void append(scope size_t delegate(scope ElemType[] dst) @safe del) {
			auto n = del(m_remaining);
			assert(n <= m_remaining.length);
			m_remaining = m_remaining[n .. $];
		}
	}

	void grow(size_t min_free) {
		if (!m_data.length && min_free < 16)
			min_free = 16;

		auto min_size = m_data.length + min_free - m_remaining.length;
		auto new_size = max(m_data.length, 16);
		while (new_size < min_size)
			new_size = (new_size * 3) / 2;
		reserve(new_size - m_data.length + m_remaining.length);
	}
}

unittest {
	auto a = AllocAppender!string(theAllocator());
	a.put("Hello");
	a.put(' ');
	a.put("World");
	assert(a.data == "Hello World");
	a.reset();
	assert(a.data == "");
}

unittest {
	char[4] buf;
	auto a = AllocAppender!string(theAllocator(), buf);
	a.put("He");
	assert(a.data == "He");
	assert(a.data.ptr == buf.ptr);
	a.put("ll");
	assert(a.data == "Hell");
	assert(a.data.ptr == buf.ptr);
	a.put('o');
	assert(a.data == "Hello");
	assert(a.data.ptr != buf.ptr);
}

unittest {
	char[4] buf;
	auto a = AllocAppender!string(theAllocator(), buf);
	a.put("Hello");
	assert(a.data == "Hello");
	assert(a.data.ptr != buf.ptr);
}

unittest {
	auto app = AllocAppender!(int[])(theAllocator);
	app.reserve(2);
	app.append((scope mem) {
		assert(mem.length >= 2);
		mem[0] = 1;
		mem[1] = 2;
		return size_t(2);
	});
	assert(app.data == [1, 2]);
}

unittest {
	auto app = AllocAppender!string(theAllocator);
	app.reserve(3);
	app.append((scope mem) {
		assert(mem.length >= 3);
		mem[0] = 'f';
		mem[1] = 'o';
		mem[2] = 'o';
		return size_t(3);
	});
	assert(app.data == "foo");
}
