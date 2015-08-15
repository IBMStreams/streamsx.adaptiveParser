package Spirit;

use strict;
use warnings;

sub symbols_defEnum(@) {
	my ($adapt, $cppType, $splType) = @_;

	if (defined($adapt->{'symbols'}->{$splType})) {
		return $adapt->{'symbols'}->{$splType}->{'enumName'};
	}
	else {
		(my $enumName = $cppType) =~ s/::/_/g;
		my @symbols = map {qq( ("$_", $cppType\::$_) )} Type::getEnumValues($splType);
		$adapt->{'symbols'}->{$splType}->{'enumName'} = $enumName;
		$adapt->{'symbols'}->{$splType}->{'enumType'} = $cppType;
		$adapt->{'symbols'}->{$splType}->{'enumValues'} = \@symbols;
		return $enumName;
	}

}

sub traits_defXml(@) {
	my ($adapt, $cppType) = @_;

	unless (defined($adapt->{'xml'}->{$cppType})) {
		$adapt->{'xml'}->{$cppType} = 
qq(
namespace streams_boost { namespace spirit { namespace traits {
template <typename Iterator>
struct assign_to_attribute_from_iterators<$cppType, Iterator> {
    static void call(Iterator const& first, Iterator const& last, $cppType & attr) {
		attr = $cppType( SPL::rstring(first,last));
    }
};
}}}
);

	}

}

sub traits_defStruct(@) {
	my ($adapt, $cppType) = @_;

	$adapt->{'traits'} =
qq(
namespace streams_boost { namespace fusion { namespace traits {
	template<> struct tag_of<$cppType> { typedef struct_tag type; };
}}}
);

}

sub ext_defStructSize(@) {
	my ($adapt, $cppType, $tupleSize) = @_;
	
	$adapt->{'extension'} =
qq(
namespace streams_boost { namespace fusion { namespace extension {
	template<> struct struct_size<$cppType> : mpl::int_<$tupleSize> {};
);

}

# Workaround for a known Spirit bug
sub ext_defDummyStructMember(@) {
	my ($adapt, $cppType) = @_;
	
	$adapt->{'extension'} .=
qq(
	template<>
	struct struct_member<$cppType, 1> {
		typedef qi::unused_type type;
		//typedef char type;
		static type dummy;
		
		static type& call($cppType& struct_) {
			return dummy;
		};
	};
);

}

sub ext_defStructMember(@) {
	my ($adapt, $attrName, $cppType, $i) = @_;
	
	$adapt->{'extension'} .=
qq(
	template<>
	struct struct_member<$cppType, $i> {
		typedef $cppType\::$attrName\_type type;
		static type& call($cppType& struct_) {
			return struct_.get_$attrName();
		};
	};
);

}

1;
