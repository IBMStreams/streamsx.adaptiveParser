package Spirit;

use strict;
use warnings;

sub cppExpr_wrap(@) {
	my ($adapt, $cppType, $paramName, $value) = @_;

	my $func = "$cppType\_$paramName";
	$func =~ s/::/_/g;
	$adapt->{'cppExprs'}->{$func} = $value;
	return "bind(&MY_OP::$func, op)";
}

sub defaults_setValue(@) {
	my ($adapt, $cppType, $value) = @_;

	(my $setExpr = $cppType) =~ s/^.*?::/otuple::/;
	$setExpr =~ s/::(.*?)_type/.get_${1}()/g;
	push $adapt->{'defaults'}, "$setExpr = $value;\n\t\t";
}

sub locals_define(@) {
	my ($adapt, $cppType, $splType) = @_;

	my $local = "local_$cppType";
	$local =~ s/::/_/g;
	push $adapt->{'locals'}, "SPL::$splType $local; \n\t\t";
	return $local;
}

sub regex_defExpr(@) {
	my ($adapt, $cppType, $value) = @_;

	my $regex = "re_$cppType";
	$regex =~ s/::/_/g;
	$adapt->{'regexes'}->{$regex} = $value;
	return "bind(&MY_OP::$regex, op, _1)";
}

sub symbols_defEnum(@) {
	my ($adapt, $cppType, $splType, $enumAliasesMap) = @_;

	my $enumName;
	
	if (defined($adapt->{'symbols'}->{$splType})) {
		$enumName = $adapt->{'symbols'}->{$splType}->{'enumName'};
	}
	else {
		($enumName = $cppType) =~ s/::/_/g;
		my @symbols = map {qq( ("$_", $cppType\::$_) )} Type::getEnumValues($splType);
		$adapt->{'symbols'}->{$splType}->{'enumName'} = $enumName;
		$adapt->{'symbols'}->{$splType}->{'enumType'} = $cppType;
		$adapt->{'symbols'}->{$splType}->{'enumValues'} = \@symbols;
	}

	if ($enumAliasesMap) {
		for (my $i = 0; $i < @{$enumAliasesMap->getKeys()}; $i++) {
			my $key = substr( $enumAliasesMap->getKeyAt($i)->getValue(), 1, -1);
			my $value = substr( $enumAliasesMap->getValueAt($i)->getValue(), 1, -1);
			
			if ($key && $key ne $value) {
				if ($value ~~ [Type::getEnumValues($splType)]) {
					$adapt->{'symbols'}->{$splType}->{'enumAliasesMap'}->{$key} = qq( ("$key", $cppType\::$value) );
				}
				else {
					SPL::CodeGen::warnln("'%s' is not part of enum '%s'", $value, $splType);
				}
			}
		}
	}
	
	return $enumName;
}

sub traits_defEnum(@) {
	my ($adapt, $cppType, $splType) = @_;

	unless (defined($adapt->{'enum'}->{$splType})) {
		$adapt->{'enum'}->{$splType} = $cppType;
	}
}

sub traits_defXml(@) {
	my ($adapt, $cppType) = @_;

	unless (defined($adapt->{'xml'}->{$cppType})) {
		$adapt->{'xml'}->{$cppType} = $cppType;
	}
}

sub traits_defTuple1(@) {
	my ($adapt, $splType, $cppType) = @_;

	unless (defined($adapt->{'tuple1'}->{$splType})) {
		$adapt->{'tuple1'}->{$splType} = $cppType;
	}
}

sub traits_defStruct(@) {
	my ($adapt, $cppType) = @_;

	$adapt->{'traits'} =
qq(
STREAMS_BOOST_FUSION_ADAPT_STRUCT\(
	$cppType,
);

}

sub ext_defStructMember(@) {
	my ($adapt, $attrName, $cppType) = @_;
	
	$adapt->{'extension'} .=
qq(
    ($cppType\::$attrName\_type, get_$attrName())
);

}

# Workaround for a known Spirit bug
sub ext_defDummyStructMember(@) {
	my ($adapt) = @_;

	$adapt->{'extension'} .=
qq(
    (SPL::TupleIterator, getEndIterator())
);

}

1;
