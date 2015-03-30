
package AdaptiveParser_h;
use strict; use Cwd 'realpath';  use File::Basename;  use lib dirname(__FILE__);  use SPL::Operator::Instance::OperatorInstance; use SPL::Operator::Instance::Context; use SPL::Operator::Instance::Expression; use SPL::Operator::Instance::ExpressionTree; use SPL::Operator::Instance::ExpressionTreeVisitor; use SPL::Operator::Instance::ExpressionTreeCppGenVisitor; use SPL::Operator::Instance::InputAttribute; use SPL::Operator::Instance::InputPort; use SPL::Operator::Instance::OutputAttribute; use SPL::Operator::Instance::OutputPort; use SPL::Operator::Instance::Parameter; use SPL::Operator::Instance::StateVariable; use SPL::Operator::Instance::Window; 
sub main::generate($$) {
   my ($xml, $signature) = @_;  
   print "// $$signature\n";
   my $model = SPL::Operator::Instance::OperatorInstance->new($$xml);
   unshift @INC, dirname ($model->getContext()->getOperatorDirectory()) . "/../impl/nl/include";
   $SPL::CodeGenHelper::verboseMode = $model->getContext()->isVerboseModeOn();
   print '#include <SPL/Runtime/Type/Enum.h>', "\n";
   print '#include <SPL/Runtime/Type/SPLType.h>', "\n";
   print "\n";
   # [----- perl code -----]
   BEGIN {*Type:: = *SPL::CodeGen::Type::};
   use AdaptiveParserCommon;
   
   my $parserOpt = {};
   $parserOpt->{'binaryMode'} = ($_ = $model->getParameterByName('binaryMode')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'quotedStrings'} = ($_ = $model->getParameterByName('quotedStrings')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   $parserOpt->{'comment'} = ($_ = $model->getParameterByName('comment')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'globalDelimiter'} = ($_ = $model->getParameterByName('globalDelimiter')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'globalSkipper'} = ($_ = $model->getParameterByName('globalSkipper')) ? AdaptiveParserCommon::getSkipper($_->getValueAt(0)->getSPLExpression()) : 'space';
   $parserOpt->{'skipper'} = $parserOpt->{'skipperLast'} = $parserOpt->{'globalSkipper'};
   $parserOpt->{'prefix'} = ($_ = $model->getParameterByName('prefix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'suffix'} = ($_ = $model->getParameterByName('suffix')) ? $_->getValueAt(0)->getSPLExpression() : '';
   $parserOpt->{'undefined'} = $model->getParameterByName('undefined');
    
   my $oTupleCppType = 'oport0';
   my $oTupleSplType = $model->getOutputPortAt(0)->getSPLTupleType();
   my $oTupleSrcLocation = $model->getOutputPortAt(0)->getSourceLocation();
   my $structs = [];
   
   my $oAttrParams = $model->getOutputPortAt(0);
   #my %oAttrNames = map { $_->getName() => ($_->hasAssignment() ? $_ : undef) } @{$model->getOutputPortAt(0)->getAttributes()};
   
   my $FUSION_MAX_VECTOR_SIZE = 10;
   AdaptiveParserCommon::buildStructs($oTupleSrcLocation, $oTupleCppType, $oTupleSplType, $structs, $oAttrParams, $parserOpt, \$FUSION_MAX_VECTOR_SIZE);
   # [----- perl code -----]
   print "\n";
   print "\n";
   print '#define FUSION_MAX_VECTOR_SIZE ';
   print $FUSION_MAX_VECTOR_SIZE > 50 ? 50 : $FUSION_MAX_VECTOR_SIZE;
   print "\n";
   print "\n";
   print '#include "Spirit.h"', "\n";
   print '#include <streams_boost/typeof/typeof.hpp>', "\n";
   print '#include <streams_boost/foreach.hpp>', "\n";
   print "\n";
   print '#define foreach STREAMS_BOOST_FOREACH', "\n";
   print "\n";
   print 'typedef const unsigned char* charPtr;', "\n";
   print 'typedef iterator_range<charPtr>::const_iterator (iterator_range<charPtr>::*IterType)(void) const;', "\n";
   print "\n";
   SPL::CodeGen::headerPrologue($model);
   print "\n";
   print ' ', "\n";
   print 'typedef MY_BASE_OPERATOR::OPort0Type oport0;', "\n";
   print "\n";
   print 'struct boolean_ : qi::symbols<char, bool> {', "\n";
   print '	boolean_() {', "\n";
   print '		add', "\n";
   print '			("T", true)', "\n";
   print '			("F", false)', "\n";
   print '			("t", true)', "\n";
   print '			("f", false)', "\n";
   print '			("TRUE", true)', "\n";
   print '			("FALSE", false)', "\n";
   print '			("true", true)', "\n";
   print '			("false", false)', "\n";
   print '			("1", true)', "\n";
   print '			("0", false);', "\n";
   print '	}', "\n";
   print '} boolean;', "\n";
   print "\n";
   if ($parserOpt->{'undefined'}) {
   	my $undefValue;
   	my @undefinedValues = map { $_->getSPLExpression() ne '""' ? '('.$_->getSPLExpression().', qi::unused)' : () } @{$parserOpt->{'undefined'}->getValues()};
   	SPL::CodeGen::errorln("Empty values cannot be assigned to parameter 'undefined'", $oTupleSrcLocation)  unless (@undefinedValues);
   print "\n";
   print "\n";
   print 'struct undefined_ : qi::symbols<char, qi::unused_type> {', "\n";
   print '	undefined_() {', "\n";
   print '		', "\n";
   print '		add ';
   print @undefinedValues;
   print ' ;', "\n";
   print '	}', "\n";
   print '} undefined;', "\n";
   print "\n";
   }
   print "\n";
   print "\n";
   print "\n";
   # [----- perl code -----]
   my $baseRule = 'oport0_base';
   
   for my $symbols (values %{$structs->[-1]->{'symbols'}}) {
   	my @symbol = values %{$symbols};
   print qq(
   	@symbol
   );
   }
    
   # [----- perl code -----]
   print "\n";
   print "\n";
   print 'template <typename Iterator>', "\n";
   print 'struct TupleParserGrammar : qi::grammar<Iterator, oport0(bool&)> {', "\n";
   print '    TupleParserGrammar() : TupleParserGrammar::base_type(';
   print $baseRule;
   print ') {', "\n";
   print '    	using namespace ::ext;', "\n";
   print '//    	qi::real_parser<double, qi::strict_ureal_policies<double> > double_;', "\n";
   print '//    	qi::real_parser<float, qi::strict_ureal_policies<float> > float_;', "\n";
   print "\n";
   print '    	const std::string dq = "\\"";', "\n";
   print "\n";
   # [----- perl code -----]
   
   foreach my $struct (@{$structs}) {
   if (scalar %{$struct}) {
   	my $skipper = $struct->{'skipper'} ? "skip($struct->{'skipper'})" : 'lexeme';
   	my $ruleBody = join(" >> ", @{$struct->{'ruleBody'}});
   	$ruleBody = "lit($parserOpt->{'comment'})[_r1 = val(true)] | (eps[_r1 = val(false)] >> $ruleBody)" if ($parserOpt->{'comment'});
   	my $rule = $skipper."[$ruleBody]";
   	$rule .= " >> attr(0)" if ($struct->{'size'} <= 1); # patch for single element tuple - no need from Streams 3.2.2
   print qq(
   		$struct->{'ruleName'} %= $rule;
   );
   }
   }
   # [----- perl code -----]
   print "\n";
   print "\n";
   print '		timestamp = lexeme[ (long_ >> string(_r1) >> uint_ >> eps[_a = val(0)] >> -(string(_r1) >> uint_[_a = _1]))[_val = construct<SPL::timestamp>(_1, _3, _a)] ];', "\n";
   print "\n";
   print '    	';
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
   print '//			debug(oport0);', "\n";
   print '    }', "\n";
   print "\n";
   print '	qi::rule<Iterator,  SPL::timestamp(std::string), locals<int> > timestamp;', "\n";
   print "\n";
   print '    qi::rule<Iterator, oport0(bool&)> oport0_base;', "\n";
   print '    ', "\n";
   # [----- perl code -----]
   
   foreach my $struct (@{$structs}) {
   if (scalar %{$struct} && $struct->{'cppType'} ne 'oport0') {
   print qq(
   	qi::rule<Iterator, $struct->{'cppType'}()> $struct->{'ruleName'};
   );
   }
   }
   # [----- perl code -----]
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
   if (defined($structs->[-1]->{'xml'})) {
   	my @xmlDefs = values %{$structs->[-1]->{'xml'}};
   	
   	foreach my $xml (@xmlDefs) {
   print qq(
   	$xml
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
