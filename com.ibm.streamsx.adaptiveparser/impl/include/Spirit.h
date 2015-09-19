#ifndef SPIRIT_H_
#define SPIRIT_H_

#define STR_(DELIM,SKIPPER) (raw[*(byte_ - eoi)])
#define STR_W(DELIM,SKIPPER) (no_skip[raw[*(byte_ - eoi)]])
#define STR_S(DELIM,SKIPPER) (raw[skip(byte_ - SKIPPER)[eps]])
#define STR_SW(DELIM,SKIPPER) (skip(SKIPPER)[raw[skip(byte_ - SKIPPER)[eps]] >> eps])
#define STR_D(DELIM,SKIPPER) (raw[*(byte_ - DELIM)])
#define STR_DW(DELIM,SKIPPER) (no_skip[raw[*(byte_ - DELIM)]])
#define STR_DS(DELIM,SKIPPER) (raw[*(byte_ - skip(SKIPPER)[DELIM|eoi])])
#define STR_DSW(DELIM,SKIPPER) (skip(SKIPPER)[raw[*(byte_ - skip(SKIPPER)[DELIM|eoi])] >> eps])

#include <streams_boost/config/warning_disable.hpp>
#include <streams_boost/spirit/include/phoenix.hpp>
#include <streams_boost/fusion/include/adapt_struct.hpp>
#include <streams_boost/fusion/include/std_pair.hpp>
#include <streams_boost/spirit/include/qi.hpp>
#include <streams_boost/spirit/repository/include/qi_kwd.hpp>
#include <streams_boost/spirit/repository/include/qi_keywords.hpp>
#include "SPL/Runtime/Function/SPLFunctions.h"
#include "time.h"

namespace extension = streams_boost::fusion::extension;
namespace fusion = streams_boost::fusion;
namespace phoenix = streams_boost::phoenix;
namespace ascii = streams_boost::spirit::ascii;
namespace qi = streams_boost::spirit::qi;
namespace repo = streams_boost::spirit::repository::qi;
namespace traits = streams_boost::spirit::traits;

using ascii::char_; using ascii::cntrl; using ascii::punct; using ascii::space;
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
using qi::as; using qi::as_string; using qi::attr; using qi::attr_cast; using qi::lazy; using repo::kwd;
using qi::lexeme; using qi::no_skip; using qi::omit; using qi::raw; using qi::repeat; using qi::skip;
using streams_boost::iterator_range;
using namespace qi::labels;

typedef const char* charPtr;
typedef iterator_range<charPtr>::const_iterator (iterator_range<charPtr>::*IterType)(void) const;

namespace ext {

	struct dummy_ {
		qi::unused_type unused;
	};

	struct boolean_ : qi::symbols<char, bool> {
		boolean_() {
			add
				("T", true)
				("F", false)
				("t", true)
				("f", false)
				("TRUE", true)
				("FALSE", false)
				("true", true)
				("false", false)
				("1", true)
				("0", false);
		}
	};


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


	STREAMS_BOOST_SPIRIT_TERMINAL_EX(timestampFMT);

    struct timestampFMT_parser : qi::primitive_parser<timestampFMT_parser> {
        template <typename Context, typename Iterator>
        struct attribute {
            typedef SPL::timestamp type;
        };

        timestampFMT_parser(const char* value) : value_(value) {}

        template <typename Iterator, typename Context, typename Skipper, typename Attribute>
        bool parse(Iterator& first, Iterator const& last, Context&, Skipper const& skipper, Attribute& attr) const {
        	qi::skip_over(first, last, skipper);

    		struct tm sysTm;
    		const char* tsParsed = strptime(reinterpret_cast<const char*>(first), value_, &sysTm);

    		if(tsParsed) {
    			first = reinterpret_cast<charPtr>(tsParsed);
				time_t rawtime = mktime(&sysTm);
				if(rawtime >= 0) {
					traits::assign_to(SPL::timestamp(rawtime,0,0), attr);
					return true;
				}
    		}

			return false;
        }

		template <typename Context>
		streams_boost::spirit::info what(Context&) const {
			return streams_boost::spirit::info("timestampFMT");
		}

        const char* value_;
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


    template <>
    struct use_terminal<qi::domain, terminal_ex<ext::tag::timestampFMT, fusion::vector1<const char*> > > : mpl::true_ {};

    template <>
    struct use_lazy_terminal<qi::domain, ext::tag::timestampFMT, 1> : mpl::true_ {};

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


    template <typename Modifiers>
    struct make_primitive<terminal_ex<ext::tag::timestampFMT, fusion::vector1<const char*> >, Modifiers> {
        typedef ext::timestampFMT_parser result_type;

        template <typename Terminal>
        result_type operator()(Terminal const& term, unused_type) const {
            return result_type(fusion::at_c<0>(term.args));
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
			attr = SPL::spl_cast<SPL::decimal128, long double>::cast(1);
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
