
package AdaptiveParser_cpp;
use strict; use Cwd 'realpath';  use File::Basename;  use lib dirname(__FILE__);  use SPL::Operator::Instance::OperatorInstance; use SPL::Operator::Instance::Context; use SPL::Operator::Instance::Expression; use SPL::Operator::Instance::ExpressionTree; use SPL::Operator::Instance::ExpressionTreeVisitor; use SPL::Operator::Instance::ExpressionTreeCppGenVisitor; use SPL::Operator::Instance::InputAttribute; use SPL::Operator::Instance::InputPort; use SPL::Operator::Instance::OutputAttribute; use SPL::Operator::Instance::OutputPort; use SPL::Operator::Instance::Parameter; use SPL::Operator::Instance::StateVariable; use SPL::Operator::Instance::Window; 
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
   
   my $batch = ($_ = $model->getParameterByName('batch')) ? $_->getValueAt(0)->getSPLExpression() eq 'true' : 0;
   my $parsingMode = ($_ = $model->getParameterByName('parsingMode')) ? $_->getValueAt(0)->getSPLExpression() : 'full';
   my $blobDataAttr = ($_ = $model->getParameterByName('blobDataAttr')) ? $_->getValueAt(0)->getCppExpression() : '';
   my $stringDataAttr = ($_ = $model->getParameterByName('stringDataAttr')) ? $_->getValueAt(0)->getCppExpression() : '';
   
   SPL::CodeGen::errorln("'One of the parameters: blobDataAttr' or 'stringDataAttr' is missing", $model->getOutputPortAt(0)->getSourceLocation()) unless (length($blobDataAttr) || length($stringDataAttr));
   SPL::CodeGen::errorln("Only one of the parameters: 'blobDataAttr' or 'stringDataAttr' should be used", $model->getOutputPortAt(0)->getSourceLocation()) if (length($blobDataAttr) && length($stringDataAttr));
   
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
   print '	IPort0Type const & iport$0 = static_cast<IPort0Type const&>(tuple);', "\n";
   print "\n";
   if ($blobDataAttr) {
   print "\n";
   print '	const blob & raw =  ';
   print $blobDataAttr;
   print ';', "\n";
   print '	charPtr iter_start = raw.getData();', "\n";
   print '	charPtr iter_end = raw.getData() + raw.getSize();', "\n";
   }
   else {
   print "\n";
   print '	const std::string & row =  ';
   print $stringDataAttr;
   print ';', "\n";
   print '	charPtr iter_start = (charPtr)row.data();', "\n";
   print '	charPtr iter_end = (charPtr)(iter_start + row.size());', "\n";
   }
   print "\n";
   print "\n";
   if ($batch) {
   print "\n";
   print '	while(iter_start < iter_end) {', "\n";
   }
   print "\n";
   print '		OPort0Type otuple;', "\n";
   print "\n";
   print '		bool isCommented;', "\n";
   print '		bool parsed = qi::parse(iter_start, iter_end, tupleParser(ref(isCommented)), otuple);', "\n";
   print "\n";
   print '		if(!isCommented) {', "\n";
   print '			if(!parsed ';
   print $batch || ($parsingMode eq 'partial') ? '' : '|| iter_start != iter_end';
   print ')', "\n";
   print '				SPLAPPLOG(L_ERROR, "Parsing did not complete successfully", "PARSE");', "\n";
   print '	', "\n";
   print '			submit(otuple, 0);', "\n";
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
   print "\n";
   print '//qi::unused_type streams_boost::fusion::extension::struct_member<SPL::BeJwrMcwtLjbMBQAKbgKX, 1>::dummy;', "\n";
   CORE::exit $SPL::CodeGen::USER_ERROR if ($SPL::CodeGen::sawError);
}
1;
