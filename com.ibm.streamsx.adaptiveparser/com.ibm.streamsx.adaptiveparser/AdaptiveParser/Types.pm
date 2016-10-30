package Types;

use strict;
use warnings;

our @inheritedParams = (
	'allowEmpty',
	'binaryMode',
	'listPrefix',
	'listSuffix',
	'lastSuffix',
	'mapPrefix',
	'mapSuffix',
	'tuplePrefix',
	'tupleSuffix',
	'prefix',
	'suffix',
	'quotedOptStrings',
	'quotedStrings',
	'tsFormat',
	'tsToken',
	'globalAttrNameAsPrefix',
	'globalAttrNameDelimiter',
	'globalAttrNameQuoted',
	'globalDelimiter',
	'globalEscapeChar',
	'globalSkipper',
	'undefined'
);

our %allowedParams = (
	binaryMode => 'boolean',
	base64Mode => 'boolean',
	attrNameAsPrefix => 'boolean',
	attrNameQuoted => 'boolean',
	globalAttrNameAsPrefix => 'boolean',
	globalAttrNameQuoted => 'boolean',
	attrFieldName => 'rstring',
	enumAliasesMap => 'map<rstring,rstring>',
	delimiter => 'rstring',
	escapeChar => 'rstring',
	hexCharPrefix => 'rstring',
	skipChars => 'rstring',
	attrNameDelimiter => 'rstring',
	globalAttrNameDelimiter => 'rstring',
	globalDelimiter => 'rstring',
	globalEscapeChar => 'rstring',
	cutCharsetDelim => 'rstring',
	cutStringDelim => 'rstring',
	cutSkipper => 'Skipper.Skippers',
	prefix => 'rstring',
	suffix => 'rstring',
	listPrefix => 'rstring',
	listSuffix => 'rstring',
	mapPrefix => 'rstring',
	mapSuffix => 'rstring',
	tuplePrefix => 'rstring',
	tupleSuffix => 'rstring',
	skipper => 'Skipper.Skippers',
	globalSkipper => 'Skipper.Skippers',
	optional => 'boolean',
	quotedOptStrings => 'boolean',
	quotedStrings => 'boolean',
	tsFormat => 'rstring',
	tsToken => 'rstring',
	tupleId => 'boolean'
);

our %skippers = (
	none => '',
	blank => 'blank',
	control => 'cntrl',
	endl => 'eol',
	punct => 'punct',
	tab => 'char_(9)',
	whitespace => 'space'
);

1;
