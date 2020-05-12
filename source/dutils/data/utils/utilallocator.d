module dutils.data.utils.utilallocator;

public import stdx.allocator : allocatorObject, CAllocatorImpl, dispose,
	expandArray, IAllocator, make, makeArray, shrinkArray, theAllocator;
public import stdx.allocator.mallocator;
public import stdx.allocator.building_blocks.affix_allocator;

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
