#ifndef SPIRIT_H_
#define SPIRIT_H_

#define STR_(DELIM,SKIPPER) (raw[skip(char_ - eoi)[eps]])
#define STR_W(DELIM,SKIPPER) (lexeme[raw[skip(char_ - eoi)[eps]]])
#define STR_S(DELIM,SKIPPER) (raw[skip(char_ - SKIPPER)[eps]])
#define STR_SW(DELIM,SKIPPER) (skip(SKIPPER)[raw[skip(char_ - SKIPPER)[eps]] >> eps])
#define STR_D(DELIM,SKIPPER) (raw[skip(char_ - DELIM)[eps]])
#define STR_DW(DELIM,SKIPPER) (lexeme[raw[skip(char_ - DELIM)[eps]]])
#define STR_DS(DELIM,SKIPPER) (raw[skip(char_ - (skip(SKIPPER)[DELIM]))[eps]])
#define STR_DSW(DELIM,SKIPPER) (skip(SKIPPER)[raw[skip(char_ - (skip(SKIPPER)[DELIM]))[eps]] >> eps])

#include <streams_boost/config/warning_disable.hpp>
#include <streams_boost/spirit/include/phoenix_bind.hpp>
#include <streams_boost/spirit/include/phoenix_core.hpp>
#include <streams_boost/spirit/include/phoenix_fusion.hpp>
#include <streams_boost/spirit/include/phoenix_operator.hpp>
#include <streams_boost/spirit/include/phoenix_object.hpp>
#include <streams_boost/spirit/include/phoenix_stl.hpp>
#include <streams_boost/fusion/include/adapt_struct.hpp>
#include <streams_boost/fusion/include/std_pair.hpp>
#include <streams_boost/spirit/include/qi.hpp>
#include <streams_boost/spirit/include/qi_match.hpp>
#include "SPL/Runtime/Function/SPLFunctions.h"

namespace extension = streams_boost::fusion::extension;
namespace fusion = streams_boost::fusion;
namespace phoenix = streams_boost::phoenix;
namespace ascii = streams_boost::spirit::ascii;
namespace qi = streams_boost::spirit::qi;
namespace traits = streams_boost::spirit::traits;

using ascii::char_; using ascii::space;
using fusion::at_c; using qi::locals; using qi::_val;
using phoenix::bind; using phoenix::construct; using phoenix::ref; using phoenix::val;
using qi::alnum; using qi::alpha; using qi::blank; using qi::string; using qi::symbols;
using qi::bin; using qi::hex; using qi::oct;
using qi::float_; using qi::double_; using qi::long_double;
using qi::short_; using qi::int_; using qi::long_;
using qi::ushort_; using qi::uint_; using qi::ulong_;
using qi::byte_; using qi::word; using qi::dword; using qi::qword;
using qi::eoi; using qi::eol; using qi::eps; using qi::lit;
using qi::debug; using qi::fail; using qi::on_error;
using qi::attr; using qi::attr_cast; using qi::lazy; using qi::lexeme;
using qi::omit; using qi::raw; using qi::repeat; using qi::skip;
using streams_boost::iterator_range;
using namespace qi::labels;


namespace ext {
	STREAMS_BOOST_SPIRIT_TERMINAL_EX(reparse);

	template <typename Subject, typename RangeSkipper>
	struct reparse_parser : qi::unary_parser<reparse_parser<Subject, RangeSkipper> > {
		typedef Subject subject_type;

		template <typename Context, typename Iterator>
		struct attribute : traits::attribute_of<Subject, Context, Iterator> {};

		reparse_parser(Subject const& subject, RangeSkipper const& rangeSkipper) : subject(subject),  rangeSkipper(rangeSkipper) {}

		template <typename Iterator, typename Context, typename Skipper, typename Attribute>
		bool parse(Iterator& first, Iterator const& last, Context& context, Skipper const& skipper, Attribute& attr) const {
			Iterator rangeFirst, rangeLast;
			rangeFirst = rangeLast = first;

			qi::skip_over(rangeLast, last, rangeSkipper);
			if( !subject.parse(rangeFirst, rangeLast, context, skipper, attr)) {
				return false;
			}

			first = rangeLast;
			return true;
		}

		template <typename Context>
		streams_boost::spirit::info what(Context&) const {
			return streams_boost::spirit::info("reparse");
		}

		Subject subject;
		RangeSkipper rangeSkipper;
	};


	STREAMS_BOOST_SPIRIT_TERMINAL_EX(reverse);

	template <typename Subject, typename RangeSkipper, typename ReverseSkipper>
	struct reverse_parser : qi::unary_parser<reverse_parser<Subject, RangeSkipper, ReverseSkipper> > {
		typedef Subject subject_type;

		template <typename Context, typename Iterator>
		struct attribute : traits::attribute_of<Subject, Context, Iterator> {};

		reverse_parser(Subject const& subject, RangeSkipper const& rangeSkipper, ReverseSkipper const& reverseSkipper) : subject(subject), rangeSkipper(rangeSkipper), reverseSkipper(reverseSkipper) {}

		template <typename Iterator, typename Context, typename Skipper, typename Attribute>
		bool parse(Iterator& first, Iterator const& last, Context& context, Skipper const& skipper, Attribute& attr) const {
			Iterator rangeFirst, rangeLast;
			rangeFirst = rangeLast = first;
			std::reverse_iterator<Iterator> rrangeLast(first);

			qi::skip_over(rangeLast, last, rangeSkipper);
			Iterator skippedRangeLast = rangeLast;

			if(rangeLast != last) {
				std::reverse_iterator<Iterator> rrangeFirst(rangeLast);
				qi::skip_over(rrangeFirst, rrangeLast, reverseSkipper);
				skippedRangeLast = &(*rrangeFirst);
			}

			if( !subject.parse(rangeFirst, skippedRangeLast, context, skipper, attr)) {
				return false;
			}

			first = skippedRangeLast;
			return true;
		}

		template <typename Context>
		streams_boost::spirit::info what(Context&) const {
			return streams_boost::spirit::info("reverse");
		}

		Subject subject;
		RangeSkipper rangeSkipper;
		ReverseSkipper reverseSkipper;
	};
}


namespace streams_boost { namespace spirit {
    template <typename RangeSkipper>
	struct use_directive<qi::domain, terminal_ex<ext::tag::reparse, fusion::vector1<RangeSkipper> > > : mpl::true_ {};

    template <>
	struct use_lazy_directive<qi::domain, ext::tag::reparse, 1> : mpl::true_ {};


    template <typename RangeSkipper, typename ReverseSkipper>
	struct use_directive<qi::domain, terminal_ex<ext::tag::reverse, fusion::vector2<RangeSkipper, ReverseSkipper> > > : mpl::true_ {};

    template <>
	struct use_lazy_directive<qi::domain, ext::tag::reverse, 2> : mpl::true_ {};
}}

namespace streams_boost { namespace spirit { namespace qi {
	template <typename RangeSkipper, typename Subject, typename Modifiers>
    struct make_directive<terminal_ex<ext::tag::reparse, fusion::vector1<RangeSkipper> >, Subject, Modifiers> {
        typedef typename result_of::compile<qi::domain, RangeSkipper, Modifiers>::type rangeSkipper_type;
        typedef ext::reparse_parser<Subject, rangeSkipper_type> result_type;

        template <typename Terminal>
        result_type operator()(Terminal const& term, Subject const& subject, Modifiers const& modifiers) const {
            return result_type(subject, compile<qi::domain>(fusion::at_c<0>(term.args), modifiers));
        }
    };


	template <typename RangeSkipper, typename ReverseSkipper, typename Subject, typename Modifiers>
    struct make_directive<terminal_ex<ext::tag::reverse, fusion::vector2<RangeSkipper, ReverseSkipper> >, Subject, Modifiers> {
        typedef typename result_of::compile<qi::domain, RangeSkipper, Modifiers>::type rangeSkipper_type;
        typedef typename result_of::compile<qi::domain, ReverseSkipper, Modifiers>::type reverseSkipper_type;
        typedef ext::reverse_parser<Subject, rangeSkipper_type, reverseSkipper_type> result_type;

        template <typename Terminal>
        result_type operator()(Terminal const& term, Subject const& subject, Modifiers const& modifiers) const {
            return result_type(subject, compile<qi::domain>(fusion::at_c<0>(term.args), modifiers), compile<qi::domain>(fusion::at_c<1>(term.args), modifiers));
        }
    };
}}}

namespace streams_boost { namespace spirit { namespace traits {
	template <typename Subject, typename RangeSkipper>
    struct has_semantic_action<ext::reparse_parser<Subject, RangeSkipper> > : mpl::or_<has_semantic_action<Subject>, has_semantic_action<RangeSkipper> > {};

	template <typename Subject, typename RangeSkipper, typename ReverseSkipper>
    struct has_semantic_action<ext::reverse_parser<Subject, RangeSkipper, ReverseSkipper> > : mpl::or_<has_semantic_action<Subject>, has_semantic_action<RangeSkipper>, has_semantic_action<ReverseSkipper> > {};


	template <>
	struct assign_to_attribute_from_value<float, SPL::decimal32> {
		static void call(float& val, SPL::decimal32& attr) {
			attr = SPL::spl_cast<SPL::decimal32, float>::cast(val);
		}
	};

	template <>
	struct assign_to_attribute_from_value<double, SPL::decimal64> {
		static void call(double& val, SPL::decimal64& attr) {
			attr = SPL::spl_cast<SPL::decimal64, double>::cast(val);
		}
	};

	template <>
	struct assign_to_attribute_from_value<long double, SPL::decimal128> {
		static void call(long double& val, SPL::decimal128& attr) {
			attr = SPL::spl_cast<SPL::decimal128, long double>::cast(val);
		}
	};

	template <typename Iterator>
	struct assign_to_attribute_from_iterators<SPL::blob, Iterator> {
	    static void call(Iterator const& first, Iterator const& last, SPL::blob & attr) {
			attr = SPL::blob(first, last - first);
	    }
	};

	template <typename Iterator, int N>
	struct assign_to_attribute_from_iterators<SPL::bstring<N>, Iterator> {
	    static void call(Iterator const& first, Iterator const& last, SPL::bstring<N> & attr) {
			attr = SPL::bstring<N>(reinterpret_cast<const char*>(first), last - first);
	    }
	};

	template <typename Iterator>
	struct assign_to_attribute_from_iterators<SPL::ustring, Iterator> {
	    static void call(Iterator const& first, Iterator const& last, SPL::ustring & attr) {
			attr = SPL::spl_cast<SPL::ustring, SPL::rstring>::cast(SPL::rstring(first,last));
	    }
	};

//	template <typename Iterator>
//	struct assign_to_attribute_from_iterators<SPL::timestamp, Iterator> {
//	    static void call(Iterator const& first, Iterator const& last, SPL::timestamp & attr) {
//			attr = SPL::spl_cast<SPL::timestamp, SPL::rstring>::cast("(" + SPL::rstring(first,last) + ")");
//	    }
//	};


    template <typename K, typename V, int N>
	struct is_container<SPL::bmap<K,V,N> > : mpl::true_ {};

	template <typename K, typename V, int N>
    struct container_value<SPL::bmap<K,V,N> > : mpl::identity<std::pair<K,V> > {};

	template <typename K, typename V, typename P, int N>
    struct push_back_container<SPL::bmap<K,V,N>, P> {
        static bool call(SPL::bmap<K,V,N>& bm, P const& val) {
            bm.insert(val);
            return true;
        }
    };

	template <typename T>
	struct is_container<SPL::set<T> > : mpl::true_ {};

	template <typename T>
    struct container_value<SPL::set<T> > : mpl::identity<T> {};

	template <typename T>
    struct push_back_container<SPL::set<T>, T> {
        static bool call(SPL::set<T>& s, T const& val) {
            s.add(val);
            return true;
        }
    };

	template <typename T, int N>
	struct is_container<SPL::bset<T,N> > : mpl::true_ {};

	template <typename T, int N>
    struct container_value<SPL::bset<T,N> > : mpl::identity<T> {};

	template <typename T, int N>
    struct push_back_container<SPL::bset<T,N>, T> {
        static bool call(SPL::bset<T,N>& bs, T const& val) {
            bs.add(val);
            return true;
        }
    };
}}}

#endif /* SPIRIT_H_ */
