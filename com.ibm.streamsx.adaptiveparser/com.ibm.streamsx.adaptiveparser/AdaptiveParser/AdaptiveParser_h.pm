
package AdaptiveParser_h;
use strict; use Cwd 'realpath';  use File::Basename;  use lib dirname(__FILE__);  use SPL::Operator::Instance::OperatorInstance; use SPL::Operator::Instance::Annotation; use SPL::Operator::Instance::Context; use SPL::Operator::Instance::Expression; use SPL::Operator::Instance::ExpressionTree; use SPL::Operator::Instance::ExpressionTreeEvaluator; use SPL::Operator::Instance::ExpressionTreeVisitor; use SPL::Operator::Instance::ExpressionTreeCppGenVisitor; use SPL::Operator::Instance::InputAttribute; use SPL::Operator::Instance::InputPort; use SPL::Operator::Instance::OutputAttribute; use SPL::Operator::Instance::OutputPort; use SPL::Operator::Instance::Parameter; use SPL::Operator::Instance::StateVariable; use SPL::Operator::Instance::TupleValue; use SPL::Operator::Instance::Window; 
sub main::generate($$) {
   my ($xml, $signature) = @_;  
   print "// $$signature\n";
   my $model = SPL::Operator::Instance::OperatorInstance->new($$xml);
   unshift @INC, dirname ($model->getContext()->getOperatorDirectory()) . "/../impl/nl/include";
   $SPL::CodeGenHelper::verboseMode = $model->getContext()->isVerboseModeOn();
   print '#include <SPL/Runtime/Type/Enum.h>', "\n";
   print '#include <SPL/Runtime/Type/SPLType.h>', "\n";
   print '#include <SPL/Runtime/Function/TimeFunctions.h>', "\n";
   print '#include "time.h"', "\n";
   print "\n";
   print '// #define STREAMS_BOOST_SPIRIT_QI_DEBUG', "\n";
   print "\n";
   # [----- perl code -----]
   BEGIN {*Type:: = *SPL::CodeGen::Type::};
   use AdaptiveParserCommon;
   
   my $batch = ($_ = $model->getParameterByName('batch')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   my $startFrom = ($_ = $model->getParameterByName('startFrom')) ? $_->getValueAt(0)->getSPLExpression() : '';
   
   my $parserOpt = {};
   $parserOpt->{'allowEmpty'} = ($_ = $model->getParameterByName('allowEmpty')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'binaryMode'} = ($_ = $model->getParameterByName('binaryMode')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'globalAttrNameAsPrefix'} = ($_ = $model->getParameterByName('globalAttrNameAsPrefix')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'globalAttrNameQuoted'} = ($_ = $model->getParameterByName('globalAttrNameQuoted')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'quotedStrings'} = ($_ = $model->getParameterByName('quotedStrings')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'comment'} = ($_ = $model->getParameterByName('comment')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'globalAttrNameDelimiter'} = ($_ = $model->getParameterByName('globalAttrNameDelimiter')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'globalDelimiter'} = ($_ = $model->getParameterByName('globalDelimiter')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'globalEscapeChar'} = ($_ = $model->getParameterByName('globalEscapeChar')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'globalSkipper'} = ($_ = $model->getParameterByName('globalSkipper')) ? AdaptiveParserCommon::getSkipper($_->getValueAt(0)->getSPLExpression()) : 'space';
   $parserOpt->{'skipper'} = $parserOpt->{'skipperLast'} = $parserOpt->{'globalSkipper'};
   $parserOpt->{'listPrefix'} = ($_ = $model->getParameterByName('listPrefix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'listSuffix'} = ($_ = $model->getParameterByName('listSuffix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'mapPrefix'} = ($_ = $model->getParameterByName('mapPrefix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'mapSuffix'} = ($_ = $model->getParameterByName('mapSuffix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'tuplePrefix'} = ($_ = $model->getParameterByName('tuplePrefix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'tupleSuffix'} = ($_ = $model->getParameterByName('tupleSuffix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'prefix'} = ($_ = $model->getParameterByName('prefix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'suffix'} = ($_ = $model->getParameterByName('suffix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'undefined'} = $model->getParameterByName('undefined');
   
   my $oTupleCppType = 'oport0';
   my $oTupleSplType = $model->getOutputPortAt(0)->getSPLTupleType();
   my $oTupleSrcLocation = $model->getOutputPortAt(0)->getSourceLocation();
   my $structs = [];
   
   my $oAttrParams = $model->getOutputPortAt(0);
   #my %oAttrNames = map { $_->getName() => ($_->hasAssignment() ? $_ : undef) } @{$model->getOutputPortAt(0)->getAttributes()};
   
   my $STREAMS_FUSION_MAX_VECTOR_SIZE = 10;
   AdaptiveParserCommon::buildStructs($oTupleSrcLocation, $oTupleCppType, $oTupleSplType, $structs, $oAttrParams, $parserOpt, \$STREAMS_FUSION_MAX_VECTOR_SIZE);
   
   SPL::CodeGen::errorln("More than 50 attributes on the same level of tuple is not supported", $oTupleSrcLocation)  if ($STREAMS_FUSION_MAX_VECTOR_SIZE > 50);
   # [----- perl code -----]
   print "\n";
   print "\n";
   print '#define STREAMS_FUSION_MAX_VECTOR_SIZE ';
   print $STREAMS_FUSION_MAX_VECTOR_SIZE;
   print "\n";
   print '//#define STREAMS_BOOST_FUSION_DONT_USE_PREPROCESSED_FILES', "\n";
   print "\n";
    if ($STREAMS_FUSION_MAX_VECTOR_SIZE > 20) {
   print "\n";
   print '#define STREAMS_BOOST_MPL_LIMIT_LIST_SIZE ';
   print int($STREAMS_FUSION_MAX_VECTOR_SIZE / 10 + 0.99)*10;
   print "\n";
   print '#define STREAMS_BOOST_MPL_LIMIT_VECTOR_SIZE STREAMS_BOOST_MPL_LIMIT_LIST_SIZE', "\n";
   print '#define STREAMS_BOOST_MPL_CFG_NO_PREPROCESSED_HEADERS', "\n";
   }
   print "\n";
   print "\n";
   print '#include "Spirit.h"', "\n";
   print "\n";
   SPL::CodeGen::headerPrologue($model);
   print "\n";
   my $baseRule = 'oport0_base';
   print "\n";
   print "\n";
   print 'using namespace ::ext;', "\n";
   print "\n";
   print 'typedef MY_BASE_OPERATOR::OPort0Type oport0;', "\n";
   print "\n";
   print 'const std::string dq = "\\"";', "\n";
   print "\n";
   print 'template <typename Iterator>', "\n";
   print 'struct TupleParserGrammar : qi::grammar<Iterator, oport0(bool&)> {', "\n";
   print '    TupleParserGrammar() : TupleParserGrammar::base_type(';
   print $baseRule;
   print ') {', "\n";
   print "\n";
   # [----- perl code -----]
   
   for my $symbols (values %{$structs->[-1]->{'symbols'}}) {
   print qq(
   		$symbols->{'enumName'}.add @{$symbols->{'enumValues'}} ;
   );
   }
   
   if ($parserOpt->{'undefined'}) {
   	my $undefValue;
   	my @undefinedValues = map { $_->getSPLExpression() ne '""' ? '('.$_->getSPLExpression().', qi::unused)' : () } @{$parserOpt->{'undefined'}->getValues()};
   	SPL::CodeGen::errorln("Empty values cannot be assigned to parameter 'undefined'", $oTupleSrcLocation)  unless (@undefinedValues);
   
   print qq(
   		undefined.add @undefinedValues;
   );
   
   }
   
   foreach my $struct (@{$structs}) {
   if (scalar %{$struct}) {
   	my $skipper = $struct->{'skipper'} ? "skip($struct->{'skipper'})" : 'lexeme';
   #my $assign = $struct->{'size'} == 1 ? '=' : '%=';
   	my $operator = $struct->{'globalAttrNameAsPrefix'} ? ' / ' : ' >> ';
   	my $rule = join($operator, @{$struct->{'ruleBody'}});
   	$rule = "lit($parserOpt->{'tuplePrefix'}) >> $rule" if ($struct->{'cppType'} eq 'oport0' && $parserOpt->{'tuplePrefix'});
   	$rule = "eps >> $rule" if ($struct->{'size'} == 1); # patch for single element tuple
   	$rule = $skipper."[$rule]";
   	if ($struct->{'cppType'} eq 'oport0' && $parserOpt->{'tupleSuffix'}) {
   		$rule = "$rule >> lit($parserOpt->{'tupleSuffix'})" if ($batch);
   		$rule = "reparse2(byte_ - (lit($parserOpt->{'tupleSuffix'}) | eoi))[$rule] >> lit($parserOpt->{'tupleSuffix'})" unless ($batch);
   	}
   	$rule = "skip(byte_ - lit($startFrom))[eps] >> $rule" if ($struct->{'cppType'} eq 'oport0' && $startFrom);
   	$rule = "!lit($parserOpt->{'comment'})[_r1 = val(true)] >> eps[_r1 = val(false)] >> $rule" if ($struct->{'cppType'} eq 'oport0' && $parserOpt->{'comment'});
   print qq(
   		$struct->{'ruleName'} %= $rule;
   );
   }
   }
   # [----- perl code -----]
   print "\n";
   print "\n";
   print '	timestamp = skip(blank)[eps] >> long_[bind(&ts::setSeconds,_val,_1)] >> lit(_r1) >> uint_[bind(&ts::setNanoSeconds,_val,_1*1000)];', "\n";
   print '	timestampS = skip(blank)[eps] >> "(" >> long_[bind(&ts::setSeconds,_val,_1)] >> "," >> uint_[bind(&ts::setNanoSeconds,_val,_1)] >> "," >> int_[bind(&ts::setMachineId,_val,_1)] >> ")";', "\n";
   print "\n";
   print '//    	';
   print $baseRule;
   print '.name("oport0");', "\n";
   print "\n";
   print '//		on_error<fail> (';
   print $baseRule;
   print ', std::cout', "\n";
   print '//				<< val("Error! Expecting ")', "\n";
   print '//				<< _4                               // what failed?', "\n";
   print '//				<< val("\\nhere:")', "\n";
   print '//				<< std::endl', "\n";
   print '//				<< construct<std::string>(_3, _2)   // iterators to error-pos, end', "\n";
   print '//				<< std::endl', "\n";
   print '//		);', "\n";
   print "\n";
   print '//		STREAMS_BOOST_SPIRIT_DEBUG_NODE(';
   print $baseRule;
   print ');', "\n";
   print '    }', "\n";
   print "\n";
   print 'private:', "\n";
   print "\n";
   print '//	const qi::real_parser<double, qi::strict_ureal_policies<double> > double_;', "\n";
   print '//	const qi::real_parser<float, qi::strict_ureal_policies<float> > float_;', "\n";
   print ' ', "\n";
   print '	boolean_ boolean;', "\n";
   print '	dummy_ dummy;', "\n";
   print '	qi::symbols<char, qi::unused_type> undefined;', "\n";
   print "\n";
   print '	qi::rule<Iterator,  ts(std::string)> timestamp;', "\n";
   print '	qi::rule<Iterator,  ts()> timestampS;', "\n";
   print '    ', "\n";
   # [----- perl code -----]
   
   for my $symbols (values %{$structs->[-1]->{'symbols'}}) {
   print qq(
   	qi::symbols<char, $symbols->{'enumType'}> $symbols->{'enumName'};
   );
   }
   
   foreach my $struct (@{$structs}) {
   	if (scalar %{$struct} && $struct->{'cppType'} ne 'oport0') {
   print qq(
   	qi::rule<Iterator, $struct->{'cppType'}()> $struct->{'ruleName'};
   );
   	}
   }
   # [----- perl code -----]
   print "\n";
   print "\n";
   print '    qi::rule<Iterator, oport0(bool&)> oport0_base;', "\n";
   print "\n";
   print '};', "\n";
   print "\n";
   print 'class MY_OPERATOR : public MY_BASE_OPERATOR {', "\n";
   print 'public:', "\n";
   print '  MY_OPERATOR();', "\n";
   print '  virtual ~MY_OPERATOR(); ', "\n";
   print "\n";
   print '  void allPortsReady(); ', "\n";
   print '  void prepareToShutdown(); ', "\n";
   print "\n";
   print '  void process(Tuple const & tuple, uint32_t port);', "\n";
   print '  void process(Punctuation const & punct, uint32_t port);', "\n";
   print "\n";
   print '  inline void setInputIterators(const blob & raw, charPtr & iter_start, charPtr & iter_end) {', "\n";
   print '	iter_start = reinterpret_cast<charPtr>(raw.getData());', "\n";
   print '	iter_end = reinterpret_cast<charPtr>(raw.getData() + raw.getSize());', "\n";
   print '  }', "\n";
   print '  ', "\n";
   print '  inline void setInputIterators(const std::string & row, charPtr & iter_start, charPtr & iter_end) {', "\n";
   print '	iter_start = row.data();', "\n";
   print '	iter_end = iter_start + row.size();', "\n";
   print '  }', "\n";
   print "\n";
   print 'private:', "\n";
   print '	TupleParserGrammar<charPtr> tupleParser;', "\n";
   print '}; ', "\n";
   print "\n";
   SPL::CodeGen::headerEpilogue($model);
   print "\n";
   print "\n";
   print 'typedef ';
   print $model->getOutputPortAt(0)->getCppTupleType();
   print ' oport0;', "\n";
   print "\n";
   # [----- perl code -----]
   if (defined($structs->[-1]->{'enum'})) {
   	my @enumDefs = values %{$structs->[-1]->{'enum'}};
   	
   	foreach my $cppType (@enumDefs) {
   print qq(
   	namespace streams_boost { namespace spirit { namespace traits {
   	template <typename Iterator>
   	struct assign_to_attribute_from_iterators<$cppType, Iterator> {
   		static void call(Iterator const& first, Iterator const& last, $cppType & attr) {
   			const std::string enumValue(first,last);
   			if(attr.isValidValue(enumValue)) {
   				attr = enumValue;
   			}
   			else {
   				SPLAPPLOG(L_ERROR, enumValue << " is not part of $cppType enum.", "AdaptiveParser");
   			}
   		}
   	};
   	
   //	template <>
   //	struct assign_to_attribute_from_value<std::string, $cppType> {
   //		static void call(std::string & enumValue, $cppType & attr) {
   //			std::cout << enumValue << std::endl;
   //			if(attr.isValidValue(enumValue)) {
   //				attr = enumValue;
   //			}
   //		}
   //	};
   	}}}
   );
   	}
   
   }
   
   if (defined($structs->[-1]->{'xml'})) {
   	my @xmlDefs = values %{$structs->[-1]->{'xml'}};
   	
   	foreach my $cppType (@xmlDefs) {
   print qq(
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
   if (defined($structs->[-1]->{'tuple1'})) {
   	my @splTupleDefs = keys %{$structs->[-1]->{'tuple1'}};
   	my @cppTupleDefs = values %{$structs->[-1]->{'tuple1'}};
   	
   	for (my $i = 0; $i < @splTupleDefs; $i++) {
   		my $splAttrName = (Type::getAttributeNames($splTupleDefs[$i]))[0];
   		my $splAttrType = (Type::getAttributeTypes($splTupleDefs[$i]))[0];
   		my $cppTupleType = $cppTupleDefs[$i];
   		my $cppAttrType = "$cppTupleType\::$splAttrName\_type";
   		my $assignOp = Type::isString($splAttrType) || Type::isCollection($splAttrType) ? 'assign_to_container_from_value' : 'assign_to_attribute_from_value';
   print qq(
   	namespace streams_boost { namespace spirit { namespace traits {
   		template <>
   		struct $assignOp<$cppAttrType, $cppTupleType> {
   			static void call(const $cppTupleType & attr, $cppAttrType& val) {
   				val = attr.get_$splAttrName();
   			}
   		};
   	}}}
   );
   	}
   
   }
   
   
   foreach my $struct (@{$structs}) {
   print qq(
   	$struct->{'traits'}
   	$struct->{'extension'}
   );
   }
   # [----- perl code -----]
   print "\n";
   CORE::exit $SPL::CodeGen::USER_ERROR if ($SPL::CodeGen::sawError);
}
1;
