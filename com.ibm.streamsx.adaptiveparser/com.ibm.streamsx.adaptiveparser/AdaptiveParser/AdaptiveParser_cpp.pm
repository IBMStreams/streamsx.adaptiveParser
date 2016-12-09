
package AdaptiveParser_cpp;
use strict; use Cwd 'realpath';  use File::Basename;  use lib dirname(__FILE__);  use SPL::Operator::Instance::OperatorInstance; use SPL::Operator::Instance::Annotation; use SPL::Operator::Instance::Context; use SPL::Operator::Instance::Expression; use SPL::Operator::Instance::ExpressionTree; use SPL::Operator::Instance::ExpressionTreeEvaluator; use SPL::Operator::Instance::ExpressionTreeVisitor; use SPL::Operator::Instance::ExpressionTreeCppGenVisitor; use SPL::Operator::Instance::InputAttribute; use SPL::Operator::Instance::InputPort; use SPL::Operator::Instance::OutputAttribute; use SPL::Operator::Instance::OutputPort; use SPL::Operator::Instance::Parameter; use SPL::Operator::Instance::StateVariable; use SPL::Operator::Instance::TupleValue; use SPL::Operator::Instance::Window; 
sub main::generate($$) {
   my ($xml, $signature) = @_;  
   print "// $$signature\n";
   my $model = SPL::Operator::Instance::OperatorInstance->new($$xml);
   unshift @INC, dirname ($model->getContext()->getOperatorDirectory()) . "/../impl/nl/include";
   $SPL::CodeGenHelper::verboseMode = $model->getContext()->isVerboseModeOn();
   SPL::CodeGen::implementationPrologue($model);
   print "\n";
   print "\n";
   # [----- perl code -----]
   use AdaptiveParserCommon;
   
   my $inputPort = $model->getInputPortAt(0);
   my $lastOutputPortNum = $model->getNumberOfOutputPorts() - 1;
   my $errorPortExists = $inputPort->getCppTupleType() eq $model->getOutputPortAt($lastOutputPortNum)->getCppTupleType();
   my $lastDataPortNum = $errorPortExists ? $lastOutputPortNum -1 : $lastOutputPortNum;
   
   if ($errorPortExists && $lastOutputPortNum == 0) {
   	SPL::CodeGen::exitln("There is only 1 output port defined and it's identical for the input port - specify data output port", $inputPort->getSourceLocation());
   }
   
   my $batch = ($_ = $model->getParameterByName('batch')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   my $parsingMode = ($_ = $model->getParameterByName('parsingMode')) ? $_->getValueAt(0)->getSPLExpression() : 'full';
   
   my $dataAttr = $model->getParameterByName('dataAttr');
   
   if ($dataAttr) {
   	my $dataAttrSPLValue = (split /\./, $dataAttr->getValueAt(0)->getSPLExpression())[-1];
   	SPL::CodeGen::checkMinimalSchema ($inputPort, { name => $dataAttrSPLValue, type => ["blob", "rstring"] });
   }
   elsif ($inputPort->getNumberOfAttributes == 1) {
   	SPL::CodeGen::checkMaximalSchema ($inputPort, { type => ["blob", "rstring"] });
   }
   else {
   	SPL::CodeGen::exitln("Input port has more than 1 attribute - specify dataAttr parameter", $inputPort->getSourceLocation());
   }
   
   my $dataAttrCppValue = $dataAttr ? $dataAttr->getValueAt(0)->getCppExpression() : 'iport$0.get_'.$inputPort->getAttributeAt(0)->getName().'()';
   
   my @passAttrs = ($model->getParameterByName('passAttrs')) ? map { (split /\./, $_->getSPLExpression())[-1] } @{$model->getParameterByName('passAttrs')->getValues()} : ();
   
   if (@passAttrs) {
   	my $outputAttrs = $model->getOutputPortAt(0)->getAttributes();
   	if (@passAttrs >= @{$outputAttrs}) {
   		SPL::CodeGen::exitln("The number of passed input attributes must be less than the number of output attributes", $inputPort->getSourceLocation());
   	}
   	
   	foreach my $attr (@{$outputAttrs}) {
   		my $attrName = $attr->getName();
   		if (($attrName ~~ @passAttrs) && ($attr->getCppType() ne $inputPort->getAttributeByName($attrName)->getCppType())) {
   			SPL::CodeGen::exitln("The passed input attribute '%s' must be of the same type in the corresponding output port", $attrName, $inputPort->getSourceLocation());
   		}
   	}
   }
   
   my $oTupleName = 'oport0';
   my $oTupleCppType = $model->getOutputPortAt(0)->getCppTupleType();
   my $oTupleSplType = $model->getOutputPortAt(0)->getSPLTupleType();
   my $oTupleSrcLocation = $model->getOutputPortAt(0)->getSourceLocation();
   
   # [----- perl code -----]
   print "\n";
   print "\n";
   print 'MY_OPERATOR_SCOPE::MY_OPERATOR::MY_OPERATOR() : ';
   print  join ',', map { "tupleParser$_(new TupleParserGrammar$_<charPtr,MY_OPERATOR>(*this))" } (0..$lastDataPortNum) ;
   print ' {}', "\n";
   print 'MY_OPERATOR_SCOPE::MY_OPERATOR::~MY_OPERATOR() {}', "\n";
   print "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::allPortsReady() {}', "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::prepareToShutdown() {}', "\n";
   print "\n";
   print 'template<typename OTuple, typename TupleParser>', "\n";
   print 'inline bool MY_OPERATOR_SCOPE::MY_OPERATOR::parse(OTuple & otuple, TupleParser const& tupleParser, uint32_t port, charPtr iter_start, charPtr iter_end) {', "\n";
   print '	', "\n";
   if (@passAttrs) {
   	foreach my $attrName (@passAttrs) {
   print "\n";
   print '		otuple.set_';
   print $attrName;
   print '(iport$0.get_';
   print $attrName;
   print '());', "\n";
   print '	';
   }
   }
   print "\n";
   print '		', "\n";
   print '		bool parsed = false;', "\n";
   print '		bool isCommented = false;', "\n";
   print '		', "\n";
   print '		parsed = qi::parse(iter_start, iter_end, (*tupleParser)(ref(isCommented)), otuple);', "\n";
   print "\n";
   print '		if(isCommented) {', "\n";
   print '			parsed = true;', "\n";
   print '		}', "\n";
   print '		else {', "\n";
   print '			if(!parsed ';
   print $batch || ($parsingMode eq 'partial') ? '' : '|| iter_start != iter_end';
   print ') {', "\n";
   print '				parsed = false;', "\n";
   print '				', "\n";
   print '			';
   unless ($errorPortExists) {
   print "\n";
   print '				if(port == ';
   print $lastDataPortNum;
   print ') {', "\n";
   print '					SPLAPPLOG(L_ERROR, "Parsing did not complete successfully", "PARSE");', "\n";
   print '					submit(otuple, port);', "\n";
   print '				}', "\n";
   print '			';
   }
   print "\n";
   print '			}', "\n";
   print '			else {', "\n";
   print '				submit(otuple, port);', "\n";
   print '				parsed = true;', "\n";
   print '			}', "\n";
   print '		}', "\n";
   print '		return parsed;', "\n";
   print '}', "\n";
   print "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::process(Tuple const & tuple, uint32_t port) {', "\n";
   print "\n";
   print '	IPort0Type const & iport$0 = static_cast<IPort0Type const&>(tuple);', "\n";
   print "\n";
   print '	charPtr iter_start;', "\n";
   print '	charPtr iter_end;', "\n";
   print '	', "\n";
   if ($batch) {
   print "\n";
   print '	while(iter_start < iter_end) {', "\n";
   }
   print "\n";
   print "\n";
   print '	bool parsed = false;', "\n";
   print "\n";
   print '	for(int i = 0; i <= ';
   print $lastDataPortNum;
   print ' && !parsed; i++) {', "\n";
   print '		setInputIterators(';
   print $dataAttrCppValue;
   print ', iter_start, iter_end);', "\n";
   print '	', "\n";
   print '		switch(i) {', "\n";
   print '		';
   foreach my $i (0..$lastDataPortNum) {
   print "\n";
   print '			case ';
   print $i;
   print ': {', "\n";
   print '				oport';
   print $i;
   print ' otuple;', "\n";
   print '				parsed = parse(otuple, tupleParser';
   print $i;
   print ', i, iter_start, iter_end);', "\n";
   print '				break;', "\n";
   print '			}', "\n";
   print '		';
   }
   print "\n";
   print '		}', "\n";
   print '	}', "\n";
   print '	', "\n";
   if ($errorPortExists) {
   print "\n";
   print '	if(!parsed) {', "\n";
   print '		submit(iport$0, ';
   print $lastOutputPortNum;
   print ');', "\n";
   print '	}', "\n";
   }
   print "\n";
   print "\n";
   if ($batch) {
   print "\n";
   print '	}', "\n";
   }
   print "\n";
   print '}', "\n";
   print "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::process(Punctuation const & punct, uint32_t port) {', "\n";
   print '   forwardWindowPunctuation(punct);', "\n";
   print '}', "\n";
   print "\n";
   SPL::CodeGen::implementationEpilogue($model);
   print "\n";
   CORE::exit $SPL::CodeGen::USER_ERROR if ($SPL::CodeGen::sawError);
}
1;
