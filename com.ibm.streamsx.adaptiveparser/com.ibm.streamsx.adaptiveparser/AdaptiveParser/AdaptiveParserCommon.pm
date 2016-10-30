package AdaptiveParserCommon;

use strict;
use warnings;

use Data::Dumper;
use Spirit;
use Types;

sub buildStructs(@) {
	my ($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) = @_;

	return buildStructFromTuple($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) if (Type::isTuple($splType));
	
	return handleListOrSet($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size)	if (Type::isList($splType) || Type::isBList($splType) ||
																											Type::isSet($splType) || Type::isBSet($splType));
	
	return handleMap($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) if (Type::isMap($splType) || Type::isBMap($splType));
	
	return handlePrimitive($srcLocation, $cppType, $splType, $structs, $parserOpt) if (Type::isPrimitive($splType));
	
	SPL::CodeGen::errorln("Unsupported type %s.", $splType, $srcLocation);
}


sub buildStructFromTuple(@) {
	my ($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) = @_;
	my @attrNames = Type::getAttributeNames($splType);
	my @attrTypes = Type::getAttributeTypes($splType);
	my $tupleSize = @attrNames;
	$tupleSize -= @{$parserOpt->{'passAttrs'}} if ($parserOpt->{'passAttrs'});
	$$size = $tupleSize if($tupleSize > $$size);

	(my $ruleName = $cppType) =~ s/::/_/g;
	$ruleName .= '_base' if ($ruleName eq $cppType);
	my $adapt = {};
	
	$adapt->{'cppType'} = $cppType;
	$adapt->{'ruleName'} = $ruleName;
	$adapt->{'ruleBody'} = [];
	$adapt->{'globalAttrNameAsPrefix'} = $parserOpt->{'globalAttrNameAsPrefix'};
	$adapt->{'skipper'} = $parserOpt->{'skipper'};
	$adapt->{'size'} = $tupleSize;
	$adapt->{'symbols'} = {};
	$adapt->{'xml'} = {};

	unshift @{$structs}, $adapt;
	my $struct = $structs->[0];
	
	my $adapted = defined($structs->[-1]->{'tuples'}->{$splType});
	$structs->[-1]->{'tuples'}->{$splType} = '';
	
	Spirit::traits_defStruct($adapt, $cppType) unless ($adapted);

	my %attrParams;
	my $topLevel = ref $oAttrParams eq 'SPL::Operator::Instance::OutputPort';

	if (!$topLevel && $oAttrParams){
		my $attrParamNames = $oAttrParams->getAttributes();
		for (my $i = 0; $i < @{$attrParamNames}; $i++) {
			SPL::CodeGen::errorln("Parameter attribute '%s' is not found in a output attribute type '%s'", $attrParamNames->[$i], $splType, $srcLocation)
				unless ($attrParamNames->[$i] ~~ @attrNames);
			$attrParams{$attrParamNames->[$i]} = $oAttrParams->getLiteralAt($i)->getExpression();
			
		}
	}

	for (my $i = 0; $i < @attrNames; $i++) {
		
		next if ($parserOpt->{'passAttrs'} && $attrNames[$i] ~~ @{$parserOpt->{'passAttrs'}});
		
		Spirit::ext_defStructMember($struct, $attrNames[$i], $cppType) unless ($adapted);

		my $parserCustOpt;
		@{$parserCustOpt}{@Types::inheritedParams} = @{$parserOpt}{@Types::inheritedParams};
		$parserCustOpt->{'skipperLast'} =  $parserOpt->{'skipper'};
		
		my $attr;
		my $param1;
		my $param2;
		
		if ($topLevel) {
			$attr = $oAttrParams->getAttributeByName($attrNames[$i]);
			$srcLocation = $attr->getAssignmentSourceLocation();
			$attr = '' unless ($attr->hasAssignment());
		}
		else {
			$attr = $attrParams{$attrNames[$i]};
		}
		
		if ($attr) {
		
			my $funcName = getFuncNameParams($srcLocation, $attr, \$param1, \$param2, $topLevel);
			
			if ($funcName eq 'AsIs') {
				
				my $value = $topLevel ? $attr->getAssignmentOutputFunctionParameterValueAt(0)->getSPLExpression() : $attr->getArgumentAt(0)->getValue();
				push @{$struct->{'ruleBody'}}, "attr($value)";
				next;
			}
			else {
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%Types::allowedParams);
			}
		}
		
		$parserCustOpt->{'attrNameAsPrefix'} //= $parserOpt->{'globalAttrNameAsPrefix'};
		$parserCustOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
		$parserCustOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		$parserCustOpt->{'lastSuffix'} = $parserOpt->{'tupleSuffix'} if ($parserOpt->{'tupleSuffix'});
				
		my $parser = buildStructs($srcLocation, "$cppType\::$attrNames[$i]\_type", $attrTypes[$i], $structs, $param2, $parserCustOpt, $size);

		if ($parserCustOpt->{'cutStringDelim'}) {
			$parser = "reparse(byte_ - (lit($parserCustOpt->{'cutStringDelim'}) | eoi))[$parser]";
		}
		elsif ($parserCustOpt->{'cutSkipper'}) {
			$parser = "eps >> reparse(byte_ - ($parserCustOpt->{'cutSkipper'} | eoi))[$parser]";
		}

		if (Type::isComposite($attrTypes[$i])) {
			#$parser = "lit($parserCustOpt->{'prefix'}) >> $parser" if ($parserCustOpt->{'prefix'});
			#$parser .= " >> lit($parserCustOpt->{'suffix'})" if ($parserCustOpt->{'suffix'});
			$parser = "$parser >> -lit($parserCustOpt->{'delimiter'})" if ($parserCustOpt->{'delimiter'});
			$parser = "-($parser)" if ($parserCustOpt->{'optional'});
		}
		
		if ($parserCustOpt->{'attrNameAsPrefix'}) {
			my $attrNameDelimiter = $parserCustOpt->{'attrNameDelimiter'};
			$attrNameDelimiter ||= $parserCustOpt->{'delimiter'};
			my $attrName =  $parserCustOpt->{'attrFieldName'} ? $parserCustOpt->{'attrFieldName'}  : $attrNames[$i];
			$attrName =~ tr/\"//d;
			$attrName =  qq(\\"$attrName\\") if ($parserCustOpt->{'attrNameQuoted'});
			$parser = "lit($attrNameDelimiter) >> $parser" if ($attrNameDelimiter);

			if ($tupleSize > 1 && $parserOpt->{'globalAttrNameAsPrefix'}) {
				$parser = qq(kwd("$attrName",0,inf)[$parser]);
			}
			else {
				$parser = qq(lit("$attrName") >> $parser);
			}
		}
		#elsif ($parserCustOpt->{'globalAttrNameAsPrefix'} && $tupleSize > 1) {
		#	SPL::CodeGen::errorln("attrNameAsPrefix cannot be set to false when globalAttrNameAsPrefix is true", $srcLocation);
		#}
		
		push @{$struct->{'ruleBody'}}, $parser;
	}

	Spirit::traits_defTuple1($structs->[-1], $splType, $cppType) if ($tupleSize == 1);
	
	$struct->{'extension'} .= ")" unless ($adapted);

	#$ruleName = "attr_cast<$cppType, $cppType\::$attrNames[0]\_type>($ruleName)" if ($tupleSize == 1);
	$ruleName = "lit($parserOpt->{'tuplePrefix'}) >> $ruleName" if ($parserOpt->{'tuplePrefix'});
	$ruleName .= " >> lit($parserOpt->{'tupleSuffix'})" if ($parserOpt->{'tupleSuffix'});

	return $ruleName;
}


sub handleListOrSet(@) {
	my ($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) = @_;
	my $bound = Type::getBound($splType);
	my $valueType = Type::getElementType($splType);
	my $parser;

	my $parserCustOpt;
	@{$parserCustOpt}{@Types::inheritedParams} = @{$parserOpt}{@Types::inheritedParams};
	$parserCustOpt->{'skipperLast'} =  $parserOpt->{'skipperLast'};
	
	SPL::CodeGen::errorln("Only parameter attribute 'value' is allowed for a list/set attribute type '%s'", $splType, $srcLocation)
		unless (!$oAttrParams || ($oAttrParams->getNumberOfElements() == 1 && $oAttrParams->getAttributeAt(0) eq 'value'));
						
	my $param1;
	my $param2;
	
	{
		if ($oAttrParams) {
			my $attr = $oAttrParams->getLiteralAt(0)->getExpression();
			my $funcName = getFuncNameParams($srcLocation, $attr, \$param1, \$param2, 0);
			
			if ($funcName eq 'AsIs') {
				$parser = "attr($attr->getArgumentAt(0)->getValue())";
				next;
			}
			else {
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%Types::allowedParams);
			}
		}
		
		$parserCustOpt->{'attrNameAsPrefix'} //= $parserOpt->{'globalAttrNameAsPrefix'};
		$parserCustOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
		$parserCustOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		$parserCustOpt->{'lastSuffix'} = $parserOpt->{'listSuffix'} if ($parserOpt->{'listSuffix'});
		
		$parser = buildStructs($srcLocation, "$cppType\::value_type", $valueType, $structs, $param2, $parserCustOpt, $size);
	
		if ($parserCustOpt->{'cutStringDelim'}) {
			$parser = "reparse(byte_ - (lit($parserCustOpt->{'cutStringDelim'}) | eoi))[$parser]";
		}
		elsif ($parserCustOpt->{'cutSkipper'}) {
			$parser = "eps >> reparse(byte_ - ($parserCustOpt->{'cutSkipper'} | eoi))[$parser]";
		}

		if (Type::isComposite($valueType)) {
			#$parser = "lit($parserCustOpt->{'prefix'}) >> $parser" if ($parserCustOpt->{'prefix'});
			#$parser .= " >> lit($parserCustOpt->{'suffix'})" if ($parserCustOpt->{'suffix'});
			$parser = "$parser >> -lit($parserCustOpt->{'delimiter'})" if ($parserCustOpt->{'delimiter'});
			$parser = "-($parser)" if ($parserCustOpt->{'optional'});
		}
		
		if ($bound) {
			$parser = "repeat($bound)[$parser]";
		}
		else {
			$parser = "*(($parser >> eps) - eoi)";
		}
	}
	
	$parser = "lit($parserOpt->{'listPrefix'}) >> $parser" if ($parserOpt->{'listPrefix'});
	$parser .= " >> lit($parserOpt->{'listSuffix'})" if ($parserOpt->{'listSuffix'});
	$parser = "(attr_cast<$cppType>(undefined) | $parser)" if ($parserOpt->{'undefined'});
	
	return $parser;
}


sub handleMap(@) {
	my ($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) = @_;
	my $bound = Type::getBound($splType);
	my $keyType = Type::getKeyType($splType);
	my $valueType = Type::getValueType($splType);

	my $adapt = {};
	my $cppValuetype = $bound ? 'data_type' : 'mapped_type';
	(my $ruleName = "$cppType\::value_type") =~ s/::/_/g;

	$adapt->{'cppType'} = "std::pair<$cppType\::key_type,$cppType\::$cppValuetype>";
	$adapt->{'ruleName'} = $ruleName;
	$adapt->{'ruleBody'} = [];
	$adapt->{'skipper'} = $parserOpt->{'skipper'};
	$adapt->{'size'} = 2;

	unshift @{$structs}, $adapt;
	
	my $struct = $structs->[0];
	
	my %attrParams;
	if ($oAttrParams){
		my $attrParamNames = $oAttrParams->getAttributes();
		for (my $i = 0; $i < @{$attrParamNames}; $i++) {
			SPL::CodeGen::errorln("Parameter attribute '%s' is not found in a output attribute type '%s'", $attrParamNames->[$i], $splType, $srcLocation)
				unless ($attrParamNames->[$i] ~~ ['key','value']);
			$attrParams{$attrParamNames->[$i]} = $oAttrParams->getLiteralAt($i)->getExpression();
			
		}
	}
	
	my $keyDelimiter = '';
	
	foreach my $attrName (('key','value')) {

		my $parserCustOpt;
		@{$parserCustOpt}{@Types::inheritedParams} = @{$parserOpt}{@Types::inheritedParams};
		$parserCustOpt->{'skipperLast'} =  $parserOpt->{'skipperLast'};
		
		my $attr = $attrParams{$attrName};
		my $param1;
		my $param2;
		my $parser;
		
		if ($attr) {
		
			my $funcName = getFuncNameParams($srcLocation, $attr, \$param1, \$param2, 0);
			
			if ($funcName eq 'AsIs') {
				push @{$struct->{'ruleBody'}}, "attr($attr->getArgumentAt(0)->getValue())";
				next;
			}
			else {
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%Types::allowedParams);
			}
		}

		$parserCustOpt->{'attrNameAsPrefix'} //= $parserOpt->{'globalAttrNameAsPrefix'};
		$parserCustOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
		$parserCustOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
		$parserCustOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		$parserCustOpt->{'lastSuffix'} = $parserOpt->{'mapSuffix'} if ($parserOpt->{'mapSuffix'});
		
		if ($attrName eq 'key') {
			$parserCustOpt->{'delimiter'} //= $parserCustOpt->{'attrNameAsPrefix'} ? $parserCustOpt->{'attrNameDelimiter'} : $parserOpt->{'globalDelimiter'};
			$parserCustOpt->{'quotedStrings'} = defined($parserCustOpt->{'attrNameQuoted'}) ? $parserCustOpt->{'attrNameQuoted'} : $parserCustOpt->{'quotedStrings'};
			$keyDelimiter = $parserCustOpt->{'delimiter'};
			$parser = buildStructs($srcLocation, "$cppType\::key_type", $keyType, $structs, $param2, $parserCustOpt, $size);
		}
		else {
			$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
			my $valueSkipper = $parserCustOpt->{'skipper'};

			if ($parserCustOpt->{'cutCharsetDelim'}) {
				SPL::CodeGen::errorln("Cannot use empty skipper along with 'cutCharsetDelim'", $srcLocation) unless ($valueSkipper);
				
				$parserCustOpt->{'skipper'} = '';
				$parser = buildStructs($srcLocation, "$cppType\::$cppValuetype", $valueType, $structs, $param2, $parserCustOpt, $size);
				$parser = "reparse(byte_ - ($valueSkipper >> (+char_($parserCustOpt->{'cutCharsetDelim'}) >> lit($keyDelimiter) | eoi)))[$parser]";
			}
			else {
				$parser = buildStructs($srcLocation, "$cppType\::$cppValuetype", $valueType, $structs, $param2, $parserCustOpt, $size);
			}
		}

		my $attrType = ($attrName eq 'key') ? $keyType : $valueType;
		if ($parserCustOpt->{'cutStringDelim'}) {
			$parser = "reparse(byte_ - (lit($parserCustOpt->{'cutStringDelim'}) | eoi))[$parser]";
		}
		elsif ($parserCustOpt->{'cutSkipper'}) {
			$parser = "eps >> reparse(byte_ - ($parserCustOpt->{'cutSkipper'} | eoi))[$parser]";
		}
		
		if (Type::isComposite($attrType)) {
			#$parser = "lit($parserCustOpt->{'prefix'}) >> $parser" if ($parserCustOpt->{'prefix'});
			#$parser .= " >> lit($parserCustOpt->{'suffix'})" if ($parserCustOpt->{'suffix'});
			$parser = "$parser >> -lit($parserCustOpt->{'delimiter'})" if ($parserCustOpt->{'delimiter'});
			$parser = "-($parser)" if ($parserCustOpt->{'optional'});
		}
	
		push @{$struct->{'ruleBody'}}, $parser;
	}

	my $parser;

	if ($bound) {
		$parser = "repeat($bound)[$ruleName]";
	}
	else {
		$parser = "*(($ruleName >> eps) - eoi)";
	}
	
	$parser = "lit($parserOpt->{'mapPrefix'}) >> $parser" if ($parserOpt->{'mapPrefix'});
	$parser .= " >> lit($parserOpt->{'mapSuffix'})" if ($parserOpt->{'mapSuffix'});
	$parser = "(attr_cast<$cppType>(undefined) | $parser)" if ($parserOpt->{'undefined'});

	return $parser;
}


sub handlePrimitive(@) {
	my ($srcLocation, $cppType, $splType, $structs, $parserOpt) = @_;
	my $value = '';
	
	$parserOpt->{'attrNameAsPrefix'} //= $parserOpt->{'globalAttrNameAsPrefix'};
	$parserOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
	$parserOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
	$parserOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
	$parserOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
	$parserOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
	
	if (Type::isBoolean($splType)) {
		$value = getSkippedValue($parserOpt, 'boolean');
	}
	elsif (Type::isBlob($splType)) {
		$value = AdaptiveParserCommon::getStringMacro($parserOpt, 'as_blob', 0, 0);
	}
	#elsif (Type::isEnum($splType)) {
	#	$value = AdaptiveParserCommon::getStringMacro($parserOpt, 'as_string', $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
	#	Spirit::traits_defEnum($structs->[-1], $cppType, $splType);
	#}
	elsif (Type::isEnum($splType)) {
		$value = Spirit::symbols_defEnum($structs->[-1], $cppType, $splType, $parserOpt->{'enumAliasesMap'});
		$value = getSkippedValue($parserOpt, $value);
	}
	elsif(Type::isBString($splType)) {
		my $bound = Type::getBound($splType);
		
		$value = "raw[repeat($bound)[char_]]";
		$value = "dq >> $value >> skip(byte_ - dq)[dq]" if ($parserOpt->{'quotedStrings'});
		
	}
	elsif (Type::isRString($splType) || Type::isUString($splType)) {
		$value = AdaptiveParserCommon::getStringMacro($parserOpt, 'as_string', $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
	}
	elsif (Type::isXml($splType)) {
		$value = AdaptiveParserCommon::getStringMacro($parserOpt, 'as_string', $parserOpt->{'quotedStrings'}, $parserOpt->{'quotedOptStrings'});
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
		elsif (AdaptiveParserCommon::getStringValue( $parserOpt->{'tsToken'})) {
			$value = "timestamp(val($parserOpt->{'tsToken'}))";
		}
		else {
			$value = getSkippedValue($parserOpt, 'ulong_');
		}
	}
	elsif (Type::isComplex($splType)) {
		SPL::CodeGen::errorln("The type '%s' is not supported.", $splType, $srcLocation);
	}
	elsif ($parserOpt->{'binaryMode'}) {
	
		if (Type::isDecimal($splType)) {
			SPL::CodeGen::errorln("The type '%s' is not supported in binary mode.", $splType, $srcLocation);
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
	
	$value = "(attr_cast<$cppType>(undefined) | $value)" if ($parserOpt->{'undefined'});
	$value = "($value | as<$cppType>()[eps])" if ($parserOpt->{'allowEmpty'});
	$value = "lit($parserOpt->{'prefix'}) >> $value" if ($parserOpt->{'prefix'});
	$value .= " >> lit($parserOpt->{'suffix'})" if ($parserOpt->{'suffix'});
	$value .= " >> -lit($parserOpt->{'delimiter'})" if ($parserOpt->{'delimiter'});
	$value = "-($value)" if ($parserOpt->{'optional'});
	return $value;
}

sub getFuncNameParams(@) {
	my ($srcLocation, $attr, $param1, $param2, $topLevel) = @_;
	my $funcName;
		
	if ($topLevel) {
		$funcName = $attr->getAssignmentOutputFunctionName();
		$funcName =~ s/^.+:://;
		my $funcArity = scalar @{$attr->getAssignmentOutputFunctionParameterValues()};
		
		SPL::CodeGen::errorln("Only AsIs() or Param() are allowed as top level custom output functions", $srcLocation) unless ($funcName ~~ ['AsIs','Param']);

		$$param1 = $attr->getAssignmentOutputFunctionParameterValueAt(0)->getSPLExpressionTree();
		$$param2 = $attr->getAssignmentOutputFunctionParameterValueAt(1)->getSPLExpressionTree() if ($funcArity > 1);
	}
	else {
		$funcName = $attr->getFunctionName();
		$funcName =~ s/^.+:://;
		my $funcArity = $attr->getNumberOfArguments();
		
		SPL::CodeGen::errorln("Only AsIs() or ParamN() are allowed as nested custom output functions", $srcLocation) unless ($funcName ~~ ['AsIs','ParamN']);

		$$param1 = $attr->getArgumentAt(0);
		$$param2 = $attr->getArgumentAt(1) if ($funcArity > 1);
	}
		
	return $funcName;
}

sub setParserCustOpt(@) {
	my ($srcLocation, $parserCustOpt, $param1, $param2, $expectedAttrs) = @_;
	SPL::CodeGen::errorln("Parameter '%s' is not a tuple literal", $param1->toString(), $srcLocation) unless ($param1->isTupleLiteral());
	SPL::CodeGen::errorln("Parameter '%s' is not a tuple literal", $param2->toString(), $srcLocation) unless (!$param2 || $param2->isTupleLiteral());

	my $paramAttrNames = $param1->getAttributes();
	my $paramAttrVals = $param1->getLiterals();
	
	for (my $k = 0; $k < @{$paramAttrNames}; $k++) {
		
		if (exists($expectedAttrs->{$paramAttrNames->[$k]})) {
			if ($paramAttrNames->[$k] ~~ ['skipper','globalSkipper','cutSkipper']) {
				my $skipper = AdaptiveParserCommon::getSkipper( $paramAttrVals->[$k]->getValue());
				SPL::CodeGen::errorln("Attribute '%s' is not valid, expected type: Skipper.Skippers.", $paramAttrNames->[$k], $srcLocation) unless (defined($skipper));
				$parserCustOpt->{$paramAttrNames->[$k]} = $skipper;
			}
			else {
				SPL::CodeGen::errorln("Attribute '%s' of type '%s' is not valid, expected type: '%s'.",
										$paramAttrNames->[$k], $paramAttrVals->[$k]->getType(), $expectedAttrs->{$paramAttrNames->[$k]}, $srcLocation)
					unless ($paramAttrVals->[$k]->getType() eq $expectedAttrs->{$paramAttrNames->[$k]});
	
				if ($expectedAttrs->{$paramAttrNames->[$k]} eq 'boolean') {
					$parserCustOpt->{$paramAttrNames->[$k]} = $paramAttrVals->[$k]->getValue() eq 'true';
				}
				elsif ($expectedAttrs->{$paramAttrNames->[$k]} eq 'rstring') {
					$parserCustOpt->{$paramAttrNames->[$k]} = AdaptiveParserCommon::getStringValue( $paramAttrVals->[$k]->getValue());
				}
				elsif ($expectedAttrs->{$paramAttrNames->[$k]} =~ /^map/) {
					$parserCustOpt->{$paramAttrNames->[$k]} = $paramAttrVals->[$k];
				}
				else {
					$parserCustOpt->{$paramAttrNames->[$k]} = $paramAttrVals->[$k]->getValue();
				}
			}
		}
		else {
			SPL::CodeGen::errorln("Attribute '%s' is not valid, expected: '%s'.", $paramAttrNames->[$k], Dumper($expectedAttrs), $srcLocation);
		}
	}
}

sub getStringValue($) {
	my ($str) = @_;
	
	return ($str eq '""' ? '' : $str);
}

sub getSkipper($) {
	my ($skipper) = @_;
	
	return $Types::skippers{$skipper};
}

sub getSkippedValue(@) {
	my ($parserOpt, $value) = @_;

	if ($parserOpt->{'skipper'} ne $parserOpt->{'skipperLast'}) {
		$value = "skip($parserOpt->{'skipper'})[$value]" if ($parserOpt->{'skipper'});
		$value = "lexeme[$value]" unless ($parserOpt->{'skipper'});
	}
	
	return $value;
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
		$macro = "dq >> no_skip[$macro($operator,$value,$params)] >> dq";
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
	
	if ($parserOpt->{'base64Mode'}) {
		$macro = "attr_cast<SPL::blob,iterator_range<charPtr> >($macro)" if ($op eq 'as_blob');
		$macro = "attr_cast<std::string,iterator_range<charPtr> >($macro)" if ($op eq 'as_string');
	}
	
	return $macro;
}

1;
