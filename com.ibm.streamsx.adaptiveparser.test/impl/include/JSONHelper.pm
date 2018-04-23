package JSONHelper;

use strict;
use warnings;

#use Data::Dumper;
#use Scalar::Util qw(looks_like_number);
use JSON;

sub parseJson {
	my ($filename) = @_;

	local $/ = undef;
	open FILE, $filename or die "Couldn't open file ".$filename.", $!";
	my $jsonStr = <FILE>;
	close FILE;
	
	return JSON->new->relaxed()->decode($jsonStr);
}

sub splValue {
	my ($val) = @_;

	#return $val if (looks_like_number($val) || ref($val) eq 'JSON::PP::Boolean');
	#return defined(Types::getSkipper( substr($val, rindex($val, '.') + 1))) || defined(Types::getSchemeOp( substr($val, rindex($val, '.') + 1))) ? $val : qq("$val");
	return $val if (ref($val) ne 'ARRAY');
	return join ('' , @{$val});
}

sub buildParam {
	my ($params) = @_;

	if (%{$params}) {
		my @paramArray =  map { qq(\n\t\t\t$_ : @{[ splValue($params->{$_}) ]};) } keys %{$params};
		return join ('' , @paramArray);
	}
	return '';
}

sub buildState {
	my ($states) = @_;

	if (%{$states}) {
		my @paramArray =  map { qq({\n\t\t\t\t@{[ join (' ', @{$states->{$_}->[0]}) ]} $_ = @{[ splValue($states->{$_}->[1]) ]};\n\t\t\t}) } keys %{$states};
		return join ('' , @paramArray);
	}
	return '';
}

sub buildOptions {
	my ($params) = @_;

	if (@{$params}) {
		my $options = $params->[0];
		my $attrs = $params->[1];

		my @paramArray = map { qq($_ = @{[ splValue($options->{$_}) ]}) } keys %{$options};
		my $param1 =  join (',' , @paramArray);

		if (defined($attrs)) {
			my $param2 =  buildOutputLevel('ParamN', $attrs);
			return qq({$param1}, {$param2});
		}
		return qq({$param1});
	}
	return '';
}


sub buildOutputLevel {
	my ($func, $args) = @_;

	if (%{$args}) {
		my @paramArray =  map { qq(\n\t\t\t$_ = $func(@{[ buildOptions($args->{$_}) ]})) } keys %{$args};
		return join (',' , @paramArray);
	}
	return '';
}

1;
