
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
   my $outputPort2 = $model->getOutputPortAt(1) if ($model->getNumberOfOutputPorts() > 1) ;
   
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
   
   SPL::CodeGen::exitln("Error output port and input port schemas must match", $inputPort->getSourceLocation()) if($outputPort2 && $inputPort->getCppTupleType() ne $outputPort2->getCppTupleType());
   
   my $oTupleName = 'oport0';
   my $oTupleCppType = $model->getOutputPortAt(0)->getCppTupleType();
   my $oTupleSplType = $model->getOutputPortAt(0)->getSPLTupleType();
   my $oTupleSrcLocation = $model->getOutputPortAt(0)->getSourceLocation();
   
   # [----- perl code -----]
   print "\n";
   print "\n";
   print 'MY_OPERATOR_SCOPE::MY_OPERATOR::MY_OPERATOR() : tupleParser() {}', "\n";
   print 'MY_OPERATOR_SCOPE::MY_OPERATOR::~MY_OPERATOR() {}', "\n";
   print "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::allPortsReady() {}', "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::prepareToShutdown() {}', "\n";
   print "\n";
   print 'void MY_OPERATOR_SCOPE::MY_OPERATOR::process(Tuple const & tuple, uint32_t port) {', "\n";
   print "\n";
   print '	IPort0Type const & iport$0 = static_cast<IPort0Type const&>(tuple);', "\n";
   print "\n";
   print '	charPtr iter_start;', "\n";
   print '	charPtr iter_end;', "\n";
   print '	', "\n";
   print '	setInputIterators(';
   print $dataAttrCppValue;
   print ', iter_start, iter_end);', "\n";
   print "\n";
   if ($batch) {
   print "\n";
   print '	while(iter_start < iter_end) {', "\n";
   }
   print "\n";
   print '		OPort0Type otuple;', "\n";
   print "\n";
   print '		bool isCommented = false;', "\n";
   print '		bool parsed = qi::parse(iter_start, iter_end, tupleParser(ref(isCommented)), otuple);', "\n";
   print "\n";
   print '		if(!isCommented) {', "\n";
   print '			if(!parsed ';
   print $batch || ($parsingMode eq 'partial') ? '' : '|| iter_start != iter_end';
   print ') {', "\n";
   print '				';
   if ($model->getNumberOfOutputPorts() > 1) {
   print "\n";
   print '					submit(tuple, 1);', "\n";
   print '				';
   }
   				else {
   print "\n";
   print '					SPLAPPLOG(L_ERROR, "Parsing did not complete successfully", "PARSE");', "\n";
   print '					submit(otuple, 0);', "\n";
   print '				';
   }
   print "\n";
   print '			}', "\n";
   print '			else {', "\n";
   print '				submit(otuple, 0);', "\n";
   print '			}', "\n";
   print '		}', "\n";
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
