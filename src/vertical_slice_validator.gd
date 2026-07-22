class_name VectorVerseVerticalSliceValidator
extends RefCounted

static func validate_and_save(graph: VectorVerseVisualGraph, compatible_after_start: Array[String]) -> Dictionary:
	return VectorVersePipelineCompiler.compile_validate_save(graph, compatible_after_start)
