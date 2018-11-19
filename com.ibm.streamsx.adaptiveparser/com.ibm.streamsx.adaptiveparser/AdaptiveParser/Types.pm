package Types;

use strict;
use warnings;

$Data::Dumper::Indent = 0;

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
	'globalTupleScheme',
	'undefined'
);

our %allowedParams = (
	defaultValue => 'attr',
	base64Mode => 'boolean',
	binaryMode => 'boolean',
	attrNameQuoted => 'boolean',
	globalAttrNameQuoted => 'boolean',
	quotedOptStrings => 'boolean',
	quotedStrings => 'boolean',
	optional => 'boolean',
	attrFieldName => 'rstring',
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
	parseToState => 'rstring',
	regexFilter => 'rstring',
	prefix => 'rstring',
	suffix => 'rstring',
	listPrefix => 'rstring',
	listSuffix => 'rstring',
	mapPrefix => 'rstring',
	mapSuffix => 'rstring',
	tuplePrefix => 'rstring',
	tupleSuffix => 'rstring',
	tsFormat => 'rstring',
	tsToken => 'rstring',
	bound => ['int8','int16','int32','int64','uint8','uint16','uint32','uint64'],
	skipCountAfter => ['int8','int16','int32','int64','uint8','uint16','uint32','uint64'],
	skipCountBefore => ['int8','int16','int32','int64','uint8','uint16','uint32','uint64'],
	enumAliasesMap => 'map<rstring,rstring>',
	skipper => 'Skipper.Skippers',
	globalSkipper => 'Skipper.Skippers',
	tupleScheme => 'TupleScheme.Schemes',
	globalTupleScheme => 'TupleScheme.Schemes',
	tupleId => 'boolean'
);

our %skippers = (
	none => '',
	blank => 'blank',		# all whitespaces except new line
	control => 'cntrl',		# all control chars
	endl => 'eol',			# new line
	punct => 'punct',		# all punct chars
	tab => 'char_(9)',		# tabulation
	whitespace => 'space'	# all whitespaces
);

our %schemes = (
	firstTypePaired => '|',	# alternative
	openAttrNamePaired => '/',	# key/value
	openTypeOrdered => '||',	# sequential/optional
	openTypeUnordered => '^',	# permutative
	strictTypeOrdered => '>>'	# sequential (default)
);

sub getSkipper($) {
	my ($skipper) = @_;
	
	return $Types::skippers{$skipper};
}

sub getSchemeOp($) {
	my ($scheme) = @_;
	
	return $Types::schemes{$scheme};
}

sub getSkippedValue(@) {
	my ($parserOpt, $value) = @_;

	if ($parserOpt->{'skipper'} ne $parserOpt->{'skipperLast'}) {
		$value = "skip($parserOpt->{'skipper'})[$value]" if ($parserOpt->{'skipper'});
		$value = "lexeme[$value]" unless ($parserOpt->{'skipper'});
	}
	
	return $value;
}

sub getStringValue($) {
	my ($str) = @_;
	
	return ($str eq '""' ? '' : $str);
}

sub getCppExpr($) {
	my ($expr) = @_;
	
	if ($expr->isExpressionLiteral()) {
		my $cppExpr = SPL::Operator::Instance::ExpressionTreeCppGenVisitor->new();
		$cppExpr->visit($expr->getExpression());
		return $cppExpr->getCppCode();
	}
	else {
		return $expr->getCppCode();
	}
}

sub getFormattedValue($) {
	my ($value) = @_;
	
	unless (ref($value)) {
		return $value;
	}
	elsif (ref($value) eq "ARRAY") {
		return join(',', @{$value});
	}
	else {
		return Dumper($value);
	}
}

sub getStringMacro(@) {
	my ($parserOpt, $op, $quotedStrings, $quotedOptStrings) = @_;
	my $macro = 'STR_';
	my $operator = $parserOpt->{'escapeChar'} || $parserOpt->{'hexCharPrefix'} || $parserOpt->{'skipChars'} ? $op : 'raw';

	if ($quotedStrings || $quotedOptStrings) {
		$macro .= 'D';

		my $params = "dq,''";
		
		my $value = $parserOpt->{'escapeChar'}
			? "(-lit($parserOpt->{'escapeChar'}) >> byte_)"
			: "byte_";
		
		$value = "(lit($parserOpt->{'hexCharPrefix'}) >> hex2 | $value)" if (defined($parserOpt->{'hexCharPrefix'}));
		$value = "(omit[char_($parserOpt->{'skipChars'})] | $value)" if (defined($parserOpt->{'skipChars'}));
		$macro = "(dq >> no_skip[$macro($operator,$value,$params)] >> dq)";
	}
	
	unless ($quotedStrings) {
		$macro = "((&lit(dq) >> $macro) | STR_" if ($quotedOptStrings);
		
		my $delimiter = $parserOpt->{'delimiter'};
		if ($parserOpt->{'suffix'}) {
			$delimiter = $parserOpt->{'suffix'};
		}
		elsif ($parserOpt->{'lastSuffix'}) {
			$delimiter = "(lit($delimiter) | $parserOpt->{'lastSuffix'})";
		}
		
		$macro .= 'D' if ($delimiter);
		$macro .= 'S' if ($parserOpt->{'skipper'});
		$macro .= 'W' if ($parserOpt->{'skipper'} ne $parserOpt->{'skipperLast'});
		
		my $params = "$delimiter,$parserOpt->{'skipper'}";
		
		my $value = ($parserOpt->{'escapeChar'})
			? "(-lit($parserOpt->{'escapeChar'}) >> byte_)"
			: "byte_";

		$value = "(lit($parserOpt->{'hexCharPrefix'}) >> hex2 | $value)" if (defined($parserOpt->{'hexCharPrefix'}));
		$value = "(omit[char_($parserOpt->{'skipChars'})] | $value)" if (defined($parserOpt->{'skipChars'}));
		$macro .= "($operator,$value,$params)";
		$macro .= ')' if ($quotedOptStrings);
	}
	
	$macro = "base64[$macro]" if ($parserOpt->{'base64Mode'});
	
	return $macro;
}

sub getPrimitiveValue(@);

sub getPrimitiveValue(@) {
	my ($srcLocation, $cppType, $splType, $structs, $parserOpt) = @_;
	my $value = '';
	
	if (Type::isBoolean($splType)) {
		$value = getSkippedValue($parserOpt, 'boolean');
	}
	elsif (Type::isBlob($splType)) {
		$value = getStringMacro($parserOpt, 'as_blob', 0, 0);
	}
	elsif (Type::isEnum($splType)) {
		$value = Spirit::symbols_defEnum($structs->[-1], $cppType, $splType, $parserOpt->{'enumAliasesMap'});
		$value = getSkippedValue($parserOpt, $value);
	}
	elsif(Type::isBString($splType) || (Type::isString($splType) && $parserOpt->{'bound'})) {
		my $bound;
		
		if($parserOpt->{'bound'}) {
			if($parserOpt->{'bound'}->getValue() == 0) {
				$bound = Spirit::locals_define($structs->[-1], $cppType, $parserOpt->{'bound'}->getType());
				my $parseBound = getPrimitiveValue($srcLocation, undef, $parserOpt->{'bound'}->getType(), $structs, $parserOpt);
				$value = "omit[$parseBound\[ref($bound) = _1]] >> ";
				$bound = "bind(&TPG::$bound, this)";
			}
			else {
				$bound = Types::getCppExpr($parserOpt->{'bound'});
				$bound = Spirit::cppExpr_wrap($structs->[-1], $cppType, 'bound', $bound);
			}
		}
		else {
			$bound = Type::getBound($splType);
		}
	
		my $unskip = $parserOpt->{'skipper'} ? 'lexeme' : 'no_skip';
		$value .= "$unskip\[raw[repeat($bound)[byte_]]]";
		$value = "(dq >> $value >> skip(byte_ - dq)[dq])" if ($parserOpt->{'quotedStrings'});
		
	}
	elsif (Type::isRString($splType) || Type::isUString($splType)) {
		$value = getStringMacro($parserOpt, 'as_string', $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
		#$value = getStringMacro($parserOpt, "(as<$cppType>())", $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
	}
	elsif (Type::isXml($splType)) {
		$value = getStringMacro($parserOpt, 'as_string', $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
		#$value = getStringMacro($parserOpt, "(as<$cppType>())", $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
		Spirit::traits_defXml($structs->[-1], $cppType);
	}
	elsif (Type::isTimestamp($splType)) {
		if ($parserOpt->{'tsFormat'}) {
			if ($parserOpt->{'tsFormat'} eq '"SPL"') {
				$value = 'timestampS';
			}
			else {
				$value = "timestampFMT(val($parserOpt->{'tsFormat'}))";
			}
		}
		elsif (getStringValue( $parserOpt->{'tsToken'})) {
			$value = "timestamp(val($parserOpt->{'tsToken'}))";
		}
		else {
			$value = getSkippedValue($parserOpt, 'ulong_');
		}
	}
	elsif (Type::isComplex($splType)) {
		SPL::CodeGen::exitln("The type '%s' is not supported.", $splType, $srcLocation);
	}
	elsif ($parserOpt->{'binaryMode'}) {
	
		if (Type::isDecimal($splType)) {
			SPL::CodeGen::exitln("The type '%s' is not supported in binary mode.", $splType, $srcLocation);
			$value = 'double_';
		}
		elsif (Type::isFloat32($splType)) {
			$value = 'float_';
		}
		elsif (Type::isFloat64($splType)) {
			$value = 'double_';
		}
		elsif (Type::isInt8($splType) || Type::isUint8($splType)) {
			$value = 'byte_';
		}
		elsif (Type::isInt16($splType) || Type::isUint16($splType)) {
			$value = 'word';
		}
		elsif (Type::isInt32($splType) || Type::isUint32($splType)) {
			$value = 'dword';
		}
		elsif (Type::isInt64($splType) || Type::isUint64($splType)) {
			$value = 'qword';
		}
	}
	else {
	
		if (Type::isDecimal32($splType)) {
			$value = getSkippedValue($parserOpt, 'float_');
		}
		if (Type::isDecimal64($splType)) {
			$value = getSkippedValue($parserOpt, 'double_');
		}
		if (Type::isDecimal128($splType)) {
			$value = getSkippedValue($parserOpt, 'long_double');
		}
		elsif (Type::isFloat32($splType)) {
			$value = getSkippedValue($parserOpt, 'float_');
			$value = "($value | attr(math::nanw()))";
		}
		elsif (Type::isFloat64($splType)) {
			$value = getSkippedValue($parserOpt, 'double_');
			$value = "($value | attr(math::nanl()))";
		}
		elsif (Type::isInt8($splType)) {
			$value = getSkippedValue($parserOpt, 'short_');
		}
		elsif (Type::isUint8($splType)) {
			$value = getSkippedValue($parserOpt, 'ushort_');
		}
		elsif (Type::isInt16($splType)) {
			$value = getSkippedValue($parserOpt, 'short_');
		}
		elsif (Type::isUint16($splType)) {
			$value = getSkippedValue($parserOpt, 'ushort_');
		}
		elsif (Type::isInt32($splType)) {
			$value = getSkippedValue($parserOpt, 'int_');
		}
		elsif (Type::isUint32($splType)) {
			$value = getSkippedValue($parserOpt, 'uint_');
		}
		elsif (Type::isInt64($splType)) {
			$value = getSkippedValue($parserOpt, 'long_');
		}
		elsif (Type::isUint64($splType)) {
			$value = getSkippedValue($parserOpt, 'ulong_');
		}
	}
	
	return $value;
}

1;
