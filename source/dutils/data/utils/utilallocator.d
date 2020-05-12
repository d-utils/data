module dutils.data.utils.utilallocator;

public import stdx.allocator : allocatorObject, IAllocator, theAllocator;

// NOTE: this needs to be used instead of theAllocator due to Phobos issue 17564
@property IAllocator vibeThreadAllocator() @safe nothrow @nogc {
	import stdx.allocator.gc_allocator;

	static IAllocator s_threadAllocator;
	if (!s_threadAllocator)
		s_threadAllocator = () @trusted {
		return allocatorObject(GCAllocator.instance);
	}();
	return s_threadAllocator;
}
