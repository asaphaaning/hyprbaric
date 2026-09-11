// The fetch binding needs the browser; tests and tools get the stub that
// reports no index instead.
export 'docs_search_fetcher_stub.dart'
    if (dart.library.js_interop) 'docs_search_fetcher_web.dart';
