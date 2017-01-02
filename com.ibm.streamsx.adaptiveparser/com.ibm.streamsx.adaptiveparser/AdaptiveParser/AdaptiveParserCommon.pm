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
	$adapt->{'skipper'} = $parserOpt->{'skipper'};
	$adapt->{'tupleScheme'} = $parserOpt->{'tupleScheme'};
	$adapt->{'size'} = $tupleSize;
	$adapt->{'defaults'} = [];
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
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%Types::allowedParams, $attrTypes[$i]);
			}
		}
		
		$parserCustOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
		$parserCustOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		$parserCustOpt->{'tupleScheme'} //= $parserOpt->{'globalTupleScheme'};
		$parserCustOpt->{'lastSuffix'} = $parserOpt->{'tupleSuffix'} if ($parserOpt->{'tupleSuffix'});
				
		Spirit::defaults_setValue($structs->[-1], "$cppType\::$attrNames[$i]\_type", $parserCustOpt->{'defaultValue'}) if ($parserCustOpt->{'defaultValue'});
		
		my $parser = buildStructs($srcLocation, "$cppType\::$attrNames[$i]\_type", $attrTypes[$i], $structs, $param2, $parserCustOpt, $size);

		if ($parserCustOpt->{'cutStringDelim'}) {
			$parser = "reparse(byte_ - (lit($parserCustOpt->{'cutStringDelim'}) | eoi))[$parser]";
		}
		elsif ($parserCustOpt->{'cutSkipper'}) {
			$parser = "eps >> reparse(byte_ - ($parserCustOpt->{'cutSkipper'} | eoi))[$parser]";
		}

		if (Type::isComposite($attrTypes[$i])) {
			$parser = "$parser >> -lit($parserCustOpt->{'delimiter'})" if ($parserCustOpt->{'delimiter'});
			$parser = "-($parser)" if ($parserCustOpt->{'optional'});
		}
		
		#$parser = "(($parser) | attr($parserCustOpt->{'defaultValue'}))" if ($parserCustOpt->{'defaultValue'});
	
		if ($parserOpt->{'tupleScheme'} eq '/') {
			my $attrNameDelimiter = $parserCustOpt->{'attrNameDelimiter'};
			$attrNameDelimiter //= $parserCustOpt->{'delimiter'};
			my $attrName =  $parserCustOpt->{'attrFieldName'} ? $parserCustOpt->{'attrFieldName'}  : $attrNames[$i];
			$attrName =~ tr/\"//d;
			$attrName =  qq(\\"$attrName\\") if ($parserCustOpt->{'attrNameQuoted'});
			$parser = "lit($attrNameDelimiter) >> $parser" if ($attrNameDelimiter);
			$parser = $tupleSize > 1 ? qq(kwd("$attrName",0,inf)[$parser]) : qq(lit("$attrName") >> $parser);
		}
		
		if ($parserOpt->{'tupleScheme'} eq '|') {
			$parser = "as<$cppType\::$attrNames[$i]\_type>()[($parser)][bind(&$cppType\::set_$attrNames[$i],_val,_1)]";
		}
		
		push @{$struct->{'ruleBody'}}, "$parser";
	}

	Spirit::traits_defTuple1($structs->[-1], $splType, $cppType) if ($tupleSize == 1);
	
	$struct->{'extension'} .= ")" unless ($adapted);

	$ruleName = "lit($parserOpt->{'tuplePrefix'}) >> $ruleName" if ($parserOpt->{'tuplePrefix'});
	$ruleName .= " >> lit($parserOpt->{'tupleSuffix'})" if ($parserOpt->{'tupleSuffix'});

	#$ruleName = "advance($parserOpt->{'skipCountBefore'}) >> $ruleName" if ($parserOpt->{'skipCountBefore'});
	#$ruleName .= " >> advance($parserOpt->{'skipCountAfter'})" if ($parserOpt->{'skipCountAfter'});

	$ruleName = "advance( bind(&MY_OP::${\(Spirit::cppExpr_wrap($structs->[-1], $cppType, 'skipCountBefore', $parserOpt->{'skipCountBefore'}))}, &op)) >> $ruleName" if ($parserOpt->{'skipCountBefore'});
	$ruleName .= " >> advance( bind(&MY_OP::${\(Spirit::cppExpr_wrap($structs->[-1], $cppType, 'skipCountAfter', $parserOpt->{'skipCountAfter'}))}, &op))" if ($parserOpt->{'skipCountAfter'});

	if ($parserOpt->{'parseToState'}) {
		SPL::CodeGen::errorln("State '%s' is not defined", $parserOpt->{'parseToState'}, $srcLocation)
			unless ( exists($AdaptiveParser_h::stateVars{$parserOpt->{'parseToState'}}));

		my $cppType = $AdaptiveParser_h::stateVars{$parserOpt->{'parseToState'}}->[0];
		my $splType = $AdaptiveParser_h::stateVars{$parserOpt->{'parseToState'}}->[1];
		my $parseToState = Types::getPrimitiveValue($srcLocation, $cppType, $splType, $structs, $parserOpt);
		$ruleName = "omit[$parseToState\[ref($parserOpt->{'parseToState'}) = _1]] >> $ruleName";
	}
	
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
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%Types::allowedParams, $valueType);
			}
		}
		
		$parserCustOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
		$parserCustOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
		$parserCustOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
		$parserCustOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		$parserCustOpt->{'tupleScheme'} //= $parserOpt->{'globalTupleScheme'};
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
	
	$parser = "(attr_cast<$cppType>(undefined) | $parser)" if ($parserOpt->{'undefined'});
	$parser = "lit($parserOpt->{'listPrefix'}) >> $parser" if ($parserOpt->{'listPrefix'});
	$parser .= " >> lit($parserOpt->{'listSuffix'})" if ($parserOpt->{'listSuffix'});

	$parser = "advance($parserOpt->{'skipCountBefore'}) >> $parser" if ($parserOpt->{'skipCountBefore'});
	$parser .= " >> advance($parserOpt->{'skipCountAfter'})" if ($parserOpt->{'skipCountAfter'});

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
				setParserCustOpt($srcLocation, $parserCustOpt, $param1, $param2, \%Types::allowedParams, $attrName eq 'key' ? $keyType : $valueType);
			}
		}

		$parserCustOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
		$parserCustOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
		$parserCustOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
		$parserCustOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
		$parserCustOpt->{'tupleScheme'} //= $parserOpt->{'globalTupleScheme'};
		$parserCustOpt->{'lastSuffix'} = $parserOpt->{'mapSuffix'} if ($parserOpt->{'mapSuffix'});
		
		if ($attrName eq 'key') {
			$parserCustOpt->{'delimiter'} //= $parserCustOpt->{'tupleScheme'} eq '/' ? $parserCustOpt->{'attrNameDelimiter'} : $parserOpt->{'globalDelimiter'};
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
	
	$parser = "(attr_cast<$cppType>(undefined) | $parser)" if ($parserOpt->{'undefined'});
	$parser = "lit($parserOpt->{'mapPrefix'}) >> $parser" if ($parserOpt->{'mapPrefix'});
	$parser .= " >> lit($parserOpt->{'mapSuffix'})" if ($parserOpt->{'mapSuffix'});

	$parser = "advance($parserOpt->{'skipCountBefore'}) >> $parser" if ($parserOpt->{'skipCountBefore'});
	$parser .= " >> advance($parserOpt->{'skipCountAfter'})" if ($parserOpt->{'skipCountAfter'});

	return $parser;
}


sub handlePrimitive(@) {
	my ($srcLocation, $cppType, $splType, $structs, $parserOpt) = @_;
	
	$parserOpt->{'attrNameDelimiter'} //= $parserOpt->{'globalAttrNameDelimiter'};
	$parserOpt->{'attrNameQuoted'} //= $parserOpt->{'globalAttrNameQuoted'};
	$parserOpt->{'delimiter'} //= $parserOpt->{'globalDelimiter'};
	$parserOpt->{'escapeChar'} //= $parserOpt->{'globalEscapeChar'};
	$parserOpt->{'skipper'} //= $parserOpt->{'globalSkipper'};
	$parserOpt->{'tupleScheme'} //= $parserOpt->{'globalTupleScheme'};
	
	my $value = Types::getPrimitiveValue($srcLocation, $cppType, $splType, $structs, $parserOpt);
	
	$value = "(attr_cast<$cppType>(undefined) | $value)" if ($parserOpt->{'undefined'});
	$value = "($value | as<$cppType>()[eps])" if ($parserOpt->{'allowEmpty'});
	$value = "lit($parserOpt->{'prefix'}) >> $value" if ($parserOpt->{'prefix'});
	$value .= " >> lit($parserOpt->{'suffix'})" if ($parserOpt->{'suffix'});
	$value .= " >> -lit($parserOpt->{'delimiter'})" if ($parserOpt->{'delimiter'});
	$value = "-($value)" if ($parserOpt->{'optional'});
	#$value = "advance($parserOpt->{'skipCountBefore'}) >> $value" if ($parserOpt->{'skipCountBefore'});
	#$value .= " >> advance($parserOpt->{'skipCountAfter'})" if ($parserOpt->{'skipCountAfter'});

	$value = 'advance( '. Spirit::cppExpr_wrap($structs->[-1], $cppType, 'skipCountBefore', $parserOpt->{'skipCountBefore'}) .") >> $value" if ($parserOpt->{'skipCountBefore'});
	$value .= ' >> advance( '. Spirit::cppExpr_wrap($structs->[-1], $cppType, 'skipCountAfter', $parserOpt->{'skipCountAfter'}) .')' if ($parserOpt->{'skipCountAfter'});

	if ($parserOpt->{'parseToState'}) {
		(my $state = $parserOpt->{'parseToState'}) =~ tr/\"//d;
		SPL::CodeGen::errorln("State '%s' is not defined", $state, $srcLocation) unless (exists($AdaptiveParser_h::stateVars{$state}));

		#$value = "$state >> $value";

		my $cppCode = $AdaptiveParser_h::stateVars{$state}->[0];
		my $cppType = $AdaptiveParser_h::stateVars{$state}->[1];
		my $splType = $AdaptiveParser_h::stateVars{$state}->[2];
		my $parseToState = Types::getPrimitiveValue($srcLocation, $cppType, $splType, $structs, $parserOpt);
		$value = "omit[$parseToState\[ref(op.$cppCode) = _1]] >> $value";
	}
	
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
	my ($srcLocation, $parserCustOpt, $param1, $param2, $expectedAttrs, $splType) = @_;
	SPL::CodeGen::errorln("Parameter '%s' is not a tuple literal", $param1->toString(), $srcLocation) unless ($param1->isEnum() || $param1->isTupleLiteral());
	SPL::CodeGen::errorln("Parameter '%s' is not a tuple literal", $param2->toString(), $srcLocation) unless (!$param2 || $param2->isTupleLiteral());

	if( $param1->isEnum()) { return };
	
	my $paramAttrNames = $param1->getAttributes();
	my $paramAttrVals = $param1->getLiterals();
	
	for (my $k = 0; $k < @{$paramAttrNames}; $k++) {
		
		if (exists($expectedAttrs->{$paramAttrNames->[$k]})) {
			if ($paramAttrNames->[$k] ~~ ['skipper','globalSkipper','cutSkipper']) {
				my $skipper = Types::getSkipper( $paramAttrVals->[$k]->getValue());
				SPL::CodeGen::errorln("Parameter '%s' is not valid, expected type: Skipper.Skippers.", $paramAttrNames->[$k], $srcLocation) unless (defined($skipper));
				$parserCustOpt->{$paramAttrNames->[$k]} = $skipper;
			}
			elsif ($paramAttrNames->[$k] ~~ ['globalTupleScheme','tupleScheme']) {
				my $scheme = Types::getSchemeOp( $paramAttrVals->[$k]->getValue());
				SPL::CodeGen::errorln("Parameter '%s' is not valid, expected type: TupleScheme.Schemes.", $paramAttrNames->[$k], $srcLocation) unless (defined($scheme));
				$parserCustOpt->{$paramAttrNames->[$k]} = $scheme;
			}
			else {
				my $expectedType = $expectedAttrs->{$paramAttrNames->[$k]} eq 'attr' ? $splType : $expectedAttrs->{$paramAttrNames->[$k]};

				SPL::CodeGen::errorln("Parameter '%s' of type '%s' is not valid, expected types: '%s'.",
										$paramAttrNames->[$k], $paramAttrVals->[$k]->getType(), Types::getFormattedValue($expectedType), $srcLocation)
					unless ($paramAttrVals->[$k]->getType() ~~ [$expectedType]);
	
				if ($expectedAttrs->{$paramAttrNames->[$k]} eq 'attr' || $paramAttrNames->[$k] ~~ ['skipCountAfter','skipCountBefore']) {
					#SPL::CodeGen::errorln("Side effected expressions are not supported.", $srcLocation)
						#if ($paramAttrVals->[$k]->isExpressionLiteral() && $paramAttrVals->[$k]->getExpression()->hasSideEffects());
						
					$parserCustOpt->{$paramAttrNames->[$k]} = Types::getCppExpr($paramAttrVals->[$k]);
				}
				elsif ($expectedType eq 'boolean') {
					$parserCustOpt->{$paramAttrNames->[$k]} = $paramAttrVals->[$k]->getValue() eq 'true';
				}
				elsif ($expectedType eq 'rstring') {
					$parserCustOpt->{$paramAttrNames->[$k]} = Types::getStringValue( $paramAttrVals->[$k]->getValue());
				}
				elsif ($expectedType =~ /^map/) {
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

1;
