streamsx.adaptiveParser
=======================

The toolkit allows to parse any structured, semi-structured and unstructured input format accordingly to an output tuple format of any complexity. Supports all SPL types including collections, binaries and enums. 

AdaptiveParser provides an ability to apply settings globally for the whole tuple level or locally for a single attribute.

The toolkit hosts a repository for common standard parsers ready to use, which are implemented by wrapping AdaptiveParser with specific parameters inside a composite operator.
The following parsers implemented:
BroParsers, CEFParser, CLFParser, LEEFParser and JSONParser.


Web page with SPLDoc for operators and samples: [streamsx.adaptiveParser SPLDoc](http://ibmstreams.github.io/streamsx.adaptiveParser).
