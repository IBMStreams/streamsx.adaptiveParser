package AdaptiveParserCommon;

use strict;
use warnings;

use Data::Dumper;
use Spirit;

my @inheritedParams = ('attrNameAsPrefix','attrNameDelimiter','binaryMode','quotedStrings','globalDelimiter','globalSkipper','undefined');

my %allowedParams = (
					attrNameAsPrefix => 'boolean',
					binaryMode => 'boolean',
					delimiter => 'rstring',
					attrNameDelimiter => 'rstring',
					globalDelimiter => 'rstring',
					cutCharsetDelim => 'rstring',
					cutStringDelim => 'rstring',
					cutSkipper => 'Skipper.Skippers',
					prefix => 'rstring',
					suffix => 'rstring',
					skipper => 'Skipper.Skippers',
					globalSkipper => 'Skipper.Skippers',
					optional => 'boolean',
					quotedStrings => 'boolean',
					tsFormat => 'rstring',
					tsToken => 'rstring',
					tupleId => 'boolean'
				);

my %skippers = (
	none => '',
	blank => 'blank',
	control => 'cntrl',
	endl => 'eol',
	punct => 'punct',
	tab => 'char_(9)',
	whitespace => 'space'
);

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
	$$size = $tupleSize if($tupleSize > $$size);

	(my $ruleName = $cppType) =~ s/::/_/g;
	$ruleName .= '_base' if ($ruleName eq $cppType);
	my $adapt = {};
	
	Spirit::traits_defStruct($adapt, $cppType);

	$adapt->{'cppType'} = $cppType;
	$adapt->{'ruleName'} = $ruleName;
	$adapt->{'ruleBody'} = [];
	$adapt->{'attrNameAsPrefix'} = $parserOpt->{'attrNameAsPrefix'};
	$adapt->{'skipper'} = $parserOpt->{'skipper'};
	$adapt->{'size'} = $tupleSize;
	$adapt->{'symbols'} = {};
	$adapt->{'xml'} = {};

	unshift @{$structs}, $adapt;
	my $struct = $structs->[0];
	
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
	
	for (my $i = 0; $i < $tupleSize; $i++) {
		Spirit::ext_defStructMember($struct, $attrNames[$i], $cppType);

		my $parserCustOpt;
		@{$parserCustOpt}{@inheritedParams} = @{$parserOpt}{@inheritedParams};
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
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%allowedParams);
			}
		}
		
		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
				
		my $parser = buildStructs($srcLocation, "$cppType\::$attrNames[$i]\_type", $attrTypes[$i], $structs, $param2, $parserCustOpt, $size);

		if ($parserCustOpt->{'cutStringDelim'}) {
			$parser = "reparse(byte_ - (lit($parserCustOpt->{'cutStringDelim'}) | eoi))[$parser]";
		}
		elsif ($parserCustOpt->{'cutSkipper'}) {
			$parser = "eps >> reparse(byte_ - ($parserCustOpt->{'cutSkipper'} | eoi))[$parser]";
		}

		if (Type::isComposite($attrTypes[$i])) {
			$parser = "$parserCustOpt->{'prefix'} >> $parser" if ($parserCustOpt->{'prefix'});
			$parser .= " >> $parserCustOpt->{'suffix'}" if ($parserCustOpt->{'suffix'});
			$parser = "$parser >> -lit($parserCustOpt->{'delimiter'})" if ($parserCustOpt->{'delimiter'});
			$parser = "-($parser)" if ($parserCustOpt->{'optional'});
		}
		
		if ($parserCustOpt->{'attrNameAsPrefix'}) {
			my $attrNameDelimiter = $parserCustOpt->{'attrNameDelimiter'};
			$attrNameDelimiter ||= $parserCustOpt->{'delimiter'};
			$parser = "lit($attrNameDelimiter) >> $parser" if ($attrNameDelimiter);
			$parser = qq(kwd("$attrNames[$i]",0,1)[$parser]);
		}
		push @{$struct->{'ruleBody'}}, $parser;
	}

	#Spirit::ext_defDummyStructMember($struct) if ($tupleSize == 1);
	
	$struct->{'extension'} .= ")";
	return $ruleName;
}


sub handleListOrSet(@) {
	my ($srcLocation, $cppType, $splType, $structs, $oAttrParams, $parserOpt, $size) = @_;
	my $bound = Type::getBound($splType);
	my $valueType = Type::getElementType($splType);
	
	my $parserCustOpt;
	@{$parserCustOpt}{@inheritedParams} = @{$parserOpt}{@inheritedParams};
	$parserCustOpt->{'skipperLast'} =  $parserOpt->{'skipperLast'};
	
	SPL::CodeGen::errorln("Only parameter attribute 'value' is allowed for a list/set attribute type '%s'", $splType, $srcLocation)
		unless (!$oAttrParams || ($oAttrParams->getNumberOfElements() == 1 && $oAttrParams->getAttributeAt(0) eq 'value'));
						
	my $param1;
	my $param2;
	my $parser;
	
	{
		if ($oAttrParams) {
			my $attr = $oAttrParams->getLiteralAt(0)->getExpression();
			my $funcName = getFuncNameParams($srcLocation, $attr, \$param1, \$param2, 0);
			
			if ($funcName eq 'AsIs') {
				$parser = "attr($attr->getArgumentAt(0)->getValue())";
				next;
			}
			else {
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%allowedParams);
			}
		}
		
		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		
		$parser = buildStructs($srcLocation, "$cppType\::value_type", $valueType, $structs, $param2, $parserCustOpt, $size);
	
		if ($parserCustOpt->{'cutStringDelim'}) {
			$parser = "reparse(byte_ - (lit($parserCustOpt->{'cutStringDelim'}) | eoi))[$parser]";
		}
		elsif ($parserCustOpt->{'cutSkipper'}) {
			$parser = "eps >> reparse(byte_ - ($parserCustOpt->{'cutSkipper'} | eoi))[$parser]";
		}

		if (Type::isComposite($valueType)) {
			$parser = "$parserCustOpt->{'prefix'} >> $parser" if ($parserCustOpt->{'prefix'});
			$parser .= " >> $parserCustOpt->{'suffix'}" if ($parserCustOpt->{'suffix'});
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
	my $attrParamNames = $oAttrParams->getAttributes();
	for (my $i = 0; $i < @{$attrParamNames}; $i++) {
		SPL::CodeGen::errorln("Parameter attribute '%s' is not found in a output attribute type '%s'", $attrParamNames->[$i], $splType, $srcLocation)
			unless ($attrParamNames->[$i] ~~ ['key','value']);
		$attrParams{$attrParamNames->[$i]} = $oAttrParams->getLiteralAt($i)->getExpression();
		
	}
	
	my $keyDelimiter = '';
	
	foreach my $attrName (('key','value')) {

		my $parserCustOpt;
		@{$parserCustOpt}{@inheritedParams} = @{$parserOpt}{@inheritedParams};
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
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%allowedParams);
			}
		}

		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		
		if ($attrName eq 'key') {
			$keyDelimiter = $parserCustOpt->{'delimiter'};
			$parser = buildStructs($srcLocation, "$cppType\::key_type", $keyType, $structs, $param2, $parserCustOpt, $size);
		}
		else {
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
			$parser = "$parserCustOpt->{'prefix'} >> $parser" if ($parserCustOpt->{'prefix'});
			$parser .= " >> $parserCustOpt->{'suffix'}" if ($parserCustOpt->{'suffix'});
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
	
	return $parser;
}


sub handlePrimitive(@) {
	my ($srcLocation, $cppType, $splType, $structs, $parserOpt) = @_;
	my $value = '';
	
	$parserOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
	$parserOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
	
	if (Type::isBlob($splType)) {
		$value = AdaptiveParserCommon::getStringMacro($parserOpt, 0);
	}
	elsif (Type::isBoolean($splType)) {
		$value = getSkippedValue($parserOpt, 'boolean');
	}
	elsif(Type::isBString($splType)) {
		my $bound = Type::getBound($splType);
		
		$value = "raw[repeat($bound)[char_]]";
		$value = "dq >> $value >> skip(byte_ - dq)[dq]" if ($parserOpt->{'quotedStrings'});
		
	}
	elsif (Type::isRString($splType) || Type::isUString($splType) || Type::isXml($splType)) {
		$value = AdaptiveParserCommon::getStringMacro($parserOpt, $parserOpt->{'quotedStrings'});
		
		Spirit::traits_defXml($structs->[-1], $cppType) if(Type::isXml($splType));
	}
	elsif (Type::isEnum($splType)) {
		$value = Spirit::symbols_defEnum($structs->[-1], $cppType, $splType);
		$value = getSkippedValue($parserOpt, $value);
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
		else {
			$parserOpt->{'tsToken'} //= '"."';
			$value = "timestamp(val($parserOpt->{'tsToken'}))";
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
		}
		elsif (Type::isFloat64($splType)) {
			$value = getSkippedValue($parserOpt, 'double_');
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
	$value = "$parserOpt->{'prefix'} >> $value" if ($parserOpt->{'prefix'});
	$value .= " >> $parserOpt->{'suffix'}" if ($parserOpt->{'suffix'});
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
		
		SPL::CodeGen::errorln("Only AsIs() or ParamN() are allowed as top level custom output functions", $srcLocation) unless ($funcName ~~ ['AsIs','Param']);

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
	
	return $skippers{$skipper};
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
	my ($parserOpt, $quotedStrings) = @_;
	my $value = 'STR_';
	my $delimiter = defined($parserOpt->{'suffix'}) ? $parserOpt->{'suffix'} : $parserOpt->{'delimiter'};

	if ($quotedStrings) {
		$value .= 'D';
		$value .= "(dq,'')";
		$value = "no_skip[dq >> $value >> dq]";
	}
	else {
		$value .= 'D' if ($delimiter);
		$value .= 'S' if ($parserOpt->{'skipper'});
		$value .= 'W' if ($parserOpt->{'skipper'} ne $parserOpt->{'skipperLast'});
		$value .= "($delimiter,$parserOpt->{'skipper'})";
	}
	
	return $value;
}

1;
