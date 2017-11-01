#!/usr/bin/perl
#
# Portions Copyright (c) 2011 Greenplum Inc
# Portions Copyright (c) 2012-Present Pivotal Software, Inc.
#
# Author: Jeffrey I Cohen

use POSIX;
use Pod::Usage;
use Getopt::Long;
use Data::Dumper;
use strict;
use warnings;

# SLZY_POD_HDR_BEGIN
# WARNING: DO NOT MODIFY THE FOLLOWING POD DOCUMENT:
# Generated by sleazy.pl version 4 (release Fri Jul  8 15:26:54 2011)
# Make any changes under SLZY_TOP_BEGIN/SLZY_LONG_BEGIN

=head1 NAME

B<catullus.pl> - generate pg_proc entries

=head1 VERSION

 This document describes version 8 of catullus.pl, released
 Mon Oct  3 12:58:12 2011.

=head1 SYNOPSIS

B<catullus.pl> 

Options:

    -help       brief help message
    -man        full documentation
    -procdef    sql definitions for pg_proc functions
    -prochdr    header file to modify (procedures)

=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>

    Prints the manual page and exits.

=item B<-procdef> <filename> (Required)

    sql definitions for pg_proc functions (normally pg_proc.sql)

=item B<-prochdr> <filename> (Required)

    header file to modify (normally pg_proc_gp.h).  The original file is copied to a .backup copy.


=back

=head1 DESCRIPTION

catullus.pl converts annotated sql CREATE FUNCTION statements into
pg_proc entries and updates pg_proc_gp.h.

The pg_proc definitions are stored in pg_proc.sql.  catullus reads
these definitions and, using type information from pg_type.sql,
generates DATA statements for loading the pg_proc table.  In
pg_proc_gp.h, it looks for a block of code delimited by the tokens
TIDYCAT_BEGIN_PG_PROC_GEN and TIDYCAT_END_PG_PROC_GEN and substitutes
the new generated code for the previous contents.

=head1 CAVEATS/FUTURE WORK

The aggregate transition functions are constructed from CREATE
FUNCTION statements.  But we should really use CREATE AGGREGATE
statements to generate the DATA statements for pg_aggregate and the
pg_proc entries.  A similar limitation exists for window functions in
pg_window.  And operators and operator classes?  Access methods? Casts?


=head1 AUTHORS

Jeffrey I Cohen

Portions Copyright (c) 2011 Greenplum.  All rights reserved.
Portions Copyright (c) 2012-Present Pivotal Software, Inc.

Address bug reports and comments to: bugs@greenplum.org

=cut
# SLZY_POD_HDR_END

my $glob_id = "";
my %glob_typeoidh; # hash type names to oid

# SLZY_GLOB_BEGIN
my $glob_glob;
# SLZY_GLOB_END

sub glob_validate
{
	# XXX XXX: special case these for now...

	$glob_typeoidh{"gp_persistent_relation_node"}	= 6990;
	$glob_typeoidh{"gp_persistent_database_node"}	= 6991;
	$glob_typeoidh{"gp_persistent_tablespace_node"} = 6992;
	$glob_typeoidh{"gp_persistent_filespace_node"}	= 6993;

	return 1;
}

# SLZY_CMDLINE_BEGIN
# WARNING: DO NOT MODIFY THE FOLLOWING SECTION:
# Generated by sleazy.pl version 4 (release Fri Jul  8 15:26:54 2011)
# Make any changes under SLZY_TOP_BEGIN/SLZY_LONG_BEGIN
# Any additional validation logic belongs in glob_validate()

BEGIN {
	    my $s_help      = 0;     # brief help message
	    my $s_man       = 0;     # full documentation
	    my $s_procdef;           # sql definitions for pg_proc functions
	    my $s_prochdr;           # header file to modify (procedures)

    GetOptions(
		'help|?'                                                 =>     \$s_help,
		'man'                                                    =>     \$s_man,
		'procdef|prosource|procsource|prosrc|procsrc=s'          =>     \$s_procdef,
		'prochdr|proheader|procheader|prohdr=s'                  =>     \$s_prochdr,
               )
        or pod2usage(2);

	pod2usage(-msg => $glob_id, -exitstatus => 1) if $s_help;
	pod2usage(-msg => $glob_id, -exitstatus => 0, -verbose => 2) if $s_man;
	
	
	$glob_glob = {};
	
	
	# version and properties from json definition
	$glob_glob->{_sleazy_properties} = {};
	$glob_glob->{_sleazy_properties}->{version} = '8';
	$glob_glob->{_sleazy_properties}->{slzy_date} = '1317671892';
	
	    die ("missing required argument for 'procdef'")
	    unless (defined($s_procdef));
	    die ("invalid argument for 'procdef': file $s_procdef does not exist")
	    unless (defined($s_procdef) && (-e $s_procdef));
	    die ("missing required argument for 'prochdr'")
	    unless (defined($s_prochdr));
	    die ("invalid argument for 'prochdr': file $s_prochdr does not exist")
	    unless (defined($s_prochdr) && (-e $s_prochdr));
	
	$glob_glob->{procdef}    =  $s_procdef  if (defined($s_procdef));
	$glob_glob->{prochdr}    =  $s_prochdr  if (defined($s_prochdr));
	
	glob_validate();


}
# SLZY_CMDLINE_END

sub doformat
{
	my ($bigstr, $kv) = @_;

	my %blankprefix;

	# find format expressions with leading blanks
	if ($bigstr =~ m/\n/)
	{
		my @foo = split(/\n/, $bigstr);

		for my $lin (@foo)
		{
			next unless ($lin =~ m/^\s+\{.*\}/);

			# find the first format expression after the blank prefix
			my @baz = split(/\}/, $lin, 2);

			my $firstf = shift @baz;

			my @zzz = ($firstf =~ m/^(\s+)\{(.*)$/);

			next unless (defined($zzz[1]) &&
						 length($zzz[1]));

			my $k2 = quotemeta($zzz[1]);

			die "duplicate use of prefixed pattern $k2"
				if (exists($blankprefix{$k2}));

			# store the prefix
			$blankprefix{$k2} = $zzz[0];
		}

	}

#	print Data::Dumper->Dump([%blankprefix]);

	while (my ($kk, $vv) = each(%{$kv}))
	{
		my $subi = '{' . quotemeta($kk) . '}';
		my $v2 = $vv;

		if (exists($blankprefix{quotemeta($kk)}) && 
			($v2 =~ m/\n/))
		{
			my @foo = split(/\n/, $v2);

			# for a multiline substitution, prefix every line with the
			# offset of the original token
			$v2 = join("\n" . $blankprefix{quotemeta($kk)}, @foo);

			# fixup trailing newline if necessary
			if ($vv =~ m/\n$/)
			{
				$v2 .= "\n"
					unless ($v2 =~ m/\n$/);
			}

		}

		$bigstr =~ s/$subi/$v2/gm;
	}

	return $bigstr;
}

# get oid for type from local cache
sub get_typeoid
{
	my $tname = shift;

	# check the type/oid cache 
	return $glob_typeoidh{$tname} if (exists($glob_typeoidh{$tname}));

	die "cannot find type: $tname";

	return undef;
} # get_typeoid


sub get_fntype
{
	my $funcdef = shift;

	my @foo = split(/\s+/, $funcdef);

	my $tdef = "";
	
	# get [SETOF] typname 
	for my $ff (@foo)
	{
		if ($ff =~ m/^(setof)$/i)
		{
			$tdef .= $ff . " ";
			next;
		}
		if ($ff =~ m/^(\[.*\])$/i)
		{
			$tdef .= $ff;
			next;
		}
		$tdef .= $ff;
		last;
	}

	# get array bounds or ARRAY array bounds
	for my $ff (@foo)
	{
		if ($ff =~ m/^(ARRAY)$/i)
		{
			$tdef .= " " . $ff . " ";
			next;
		}
		if ($ff =~ m/^(\[.*\])$/i)
		{
			$tdef .= $ff;
			last;
		}
		last;
	}

	return $tdef;
} # end get_fntype

sub get_fnoptlist
{
	my $funcdef = shift;
	my @optlist;

	my $rex = 'called\s+on\s+null\s+input|'.
		'returns\s+null\s+on\s+null\s+input|strict|immutable|stable|volatile|'.
		'external\s+security\s+definer|external\s+security\s+invoker|' .
		'security\s+definer|security\s+invoker|' .
		'cost\s+(\d+)|' .
		'rows\s+(\d+)|' .
		'execute\s+on\s+any|' .
		'execute\s+on\s+master|' .
		'execute\s+on\s+all\s+segments|' .
		'no\s+sql|contains\s+sql|reads\s+sql\s+data|modifies\s+sql\s+data|' .
		'language\s+\S+|' .
		'as\s+\\\'\S+\\\'(?:\s*,\s*\\\'\S+\\\')*';

#	print "$rex\n";

#	my @foo = ($funcdef =~ m/((?:\s*$rex\s*))*/i);

	my @foo = ($funcdef =~ m/($rex)/i);

	while (scalar(@foo))
	{
		my $opt = $foo[0];
		push @optlist, $opt;
		my $o2 = quotemeta($opt);
		$funcdef =~ s/$o2//;
		@foo = ($funcdef =~ m/($rex)/i);
	}

	return \@optlist;

} # end get_fnoptlist

sub make_opt
{
	my $fndef = shift;

	# values from pg_language
	my $plh = {
		internal => 12, 
		c		 => 13,
		sql		 => 14,
		plpgsql	 => 10886
	};

	my $proname		= $fndef->{name};
	my $prolang;
	my $procost;
	my $prorows;
	my $provolatile;
	my $proisstrict = 0;
	my $prosecdef	= 0;
	my $prodataaccess;
	my $proexeclocation;
	my $prosrc;
	my $func_as;

	my $tdef;

	# remove double quotes
	$proname =~ s/^\"//;
	$proname =~ s/\"$//;

	if (exists($fndef->{optlist}))
	{
		for my $opt (@{$fndef->{optlist}})
		{
			if ($opt =~ m/^(immutable|stable|volatile)/i)
			{
				die ("conflicting or redundant options: $opt") 
					if (defined($provolatile));
				
				# provolatile is first char of option ([i]mmmutble, [s]table,
				# [v]olatile).
				$provolatile = lc(substr($opt, 0, 1));
			}


			if ($opt =~ m/^language\s+(internal|c|sql|plpgsql)$/i)
			{
				die ("conflicting or redundant options: $opt") 
					if (defined($prolang));
				
				my $l1 = lc($opt);
				$l1 =~ s/^language\s+//;

				$prolang = $plh->{$l1};
			}

			if ($opt =~ m/^(no\s+sql|contains\s+sql|reads\s+sql\s+data|modifies\s+sql\s+data)/i)
			{
				die ("conflicting or redundant options: $opt")
					if (defined($prodataaccess));

				# prodataaccess is first char of option ([n]o sql, [c]ontains sql,
				# [r]eads sql data, [m]odifies sql data).
				$prodataaccess = lc(substr($opt, 0, 1));
			}

			if ($opt =~ m/^execute\s+on\s+any/i)
			{
				die ("conflicting or redundant options: $opt")
					if (defined($proexeclocation));

				$proexeclocation = 'a';
			}
			if ($opt =~ m/^execute\s+on\s+master/i)
			{
				die ("conflicting or redundant options: $opt")
					if (defined($proexeclocation));

				$proexeclocation = 'm';
			}
			if ($opt =~ m/^execute\s+on\s+all\s+segments/i)
			{
				die ("conflicting or redundant options: $opt")
					if (defined($proexeclocation));

				$proexeclocation = 's';
			}

			if ($opt =~ m/^AS\s+\'.*\'$/)
			{
				die ("conflicting or redundant options: $opt") 
					if (defined($func_as));

				# NOTE: we preprocessed dollar-quoted ($$) AS options
				# to single-quoted strings.  Will fix the string value
				# later.
				my @foo = ($opt =~ m/^AS\s+\'(.*)\'$/);
				die "bad func AS: $opt" unless (scalar(@foo));

				$func_as = shift @foo;
			}

			if ($opt =~ m/^cost\s+(\d+)$/i)
			{
				die ("conflicting or redundant options: $opt")
					if (defined($procost));
				$procost = $1;
			}
			if ($opt =~ m/^rows\s+(\d+)$/i)
			{
				die ("conflicting or redundant options: $opt")
					if (defined($prorows));

				$prorows = $1;
			}

			$proisstrict = 1
				if ($opt =~ m/^(strict|returns\s+null\s+on\s+null\s+input)$/i);
			$proisstrict = 0
				if ($opt =~ m/^(called\s+on\s+null\s+input)$/i);

			$prosecdef = 1
				if ($opt =~ m/security definer/i);
			$prosecdef = 0
				if ($opt =~ m/security invoker/i);
		} # end for

		$tdef = {

			proname		 => $proname,
#			pronamespace => 11, # pg_catalog
#			proowner	 => 10, # admin
			pronamespace => "PGNSP", # pg_catalog
			proowner	 => "PGUID", # admin
			prolang		 => $prolang,
			procost		 => $procost,
			prorows		 => $prorows,
			provariadic	 => 0,
			proisagg	 => 0,
			prosecdef	 => $prosecdef,
			proisstrict	 => $proisstrict,
#			proretset
			provolatile	 => $provolatile,
#			pronargs
#			prorettype
			proiswindow	 => 0,
#			proargtypes
#			proallargtypes
#			proargmodes
#			proargnames
			prodataaccess	=> $prodataaccess,
			proexeclocation	=> $proexeclocation
		};

		if (defined($func_as) && defined($prolang))
		{
			if (12 == $prolang) # internal
			{
				$tdef->{prosrc} = $func_as;
			}
			elsif (13 == $prolang) # C
			{
				die ("bad C function def $func_as") unless ($func_as =~ m/\,/);

				$func_as =~ s/\'//g;
				
				my @foo = split(/\s*\,\s*/, $func_as);

				$tdef->{prosrc} = $foo[1];
				$tdef->{probin} = $foo[0];

			}
			elsif (14 == $prolang) # sql
			{
				$func_as =~ s/^\s*\'//;
				$func_as =~ s/\'\s*$//;

				# NOTE: here is the fixup for the AS option --
				# retrieve the quoted string.
				#  [ unquurl ]
				$func_as =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
				$tdef->{prosrc} = $func_as;
			}
			else
			{
				die ("bad lang: $prolang");
			}
		} 

		if (!defined($prodataaccess))
		{ 
			if (14 == $prolang) # SQL
			{
				$prodataaccess = 'c';
			}
			else
			{
				$prodataaccess = 'n';
			}

			$tdef->{prodataaccess} = $prodataaccess;
		}

		# check for conflicting prodataaccess options
		if (14 == $prolang && ('n' eq $prodataaccess))
		{
			die ("conflicting options: A SQL function cannot specify NO SQL");
		}

		if (defined($provolatile) && ('i' eq $provolatile))
		{
			if ('r' eq $prodataaccess)
			{
				die ("conflicting options: IMMUTABLE conflicts with READS SQL DATA");
			}
			if ('m' eq $prodataaccess)
			{
				die ("conflicting options: IMMUTABLE conflicts with MODIFIES SQL DATA");
			}
		}

	} # end if exists

	

	$fndef->{tuple} = $tdef if (defined($tdef));


} # end make_opt

sub make_rettype
{
	my $fndef = shift;

	if (exists($fndef->{returntype}))
	{
		my $rt = $fndef->{returntype};

		# check if SETOF returntype
		$fndef->{tuple}->{proretset} = ($rt =~ m/^setof/i);

		# remove SETOF
		$rt =~ s/^setof\s*//i;

		# remove "pg_catalog." prefix
		$rt =~ s/^pg\_catalog\.//i;

		# quotes
		$rt =~ s/\"//g;

		my $rtoid = get_typeoid($rt);

		$fndef->{tuple}->{prorettype} = $rtoid 
			if (defined($rtoid));
	}
	
} # end make_rettype

sub make_allargs
{
	my $fndef = shift;
	my $fnname = $fndef->{name};

	return undef
		unless (exists($fndef->{rawargs}) && 
				length($fndef->{rawargs}));
	
	my $argstr = $fndef->{rawargs};
	
	return undef
		unless (length($argstr) && ($argstr !~ m/^\s*$/));
	
	my @foo;
	
	# A function takes multiple "func_args" (parameters),
	# separated by commas.  Each func_arg must have a type,
	# and it optionally has a name (for languages that
	# support named parameters) and/or an "arg_class" (which
	# is IN, OUT, INOUT or "IN OUT").  The func_arg tokens are
	# separated by spaces, and the ordering and combinations
	# are a bit too flexible for comfort.  So we only support
	# declarations in the order arg_class, param_name, func_type.
	
	if ($argstr =~ m/\,/)
	{
		@foo = split(/\s*\,\s*/, $argstr);
	}
	else
	{
		push @foo, $argstr;
	}

	# oids, type, class, name
	my @argoids;
	my @argtype;
	my @argclass;
	my @argname;
	
	my $nargs = 0;
	for my $func_arg (@foo)
	{
		# no spaces, so arg_type only
		if ($func_arg !~ /\S+\s+\S+/)
		{
			my $arg1 = $func_arg;
			$arg1 =~ s/\"//g;
			$arg1 =~ s/^\s+//;
			$arg1 =~ s/\s+$//g;
			push @argtype, $arg1;
		}
		else # split func_arg
		{
			if ($func_arg =~ m/^in\s+out\s+/i)
			{
				# NOTE: we want to split by spaces, 
				# so convert "in out" to "inout"
				$func_arg =~ s/^in\s+out\s+/inout /i;
			}

			my @baz = split(/\s+/, $func_arg);
			
			if (3 == scalar(@baz))
			{	
				die "$fnname: arg str badly formed: $argstr"
					unless ($baz[0] =~ m/^(in|out|inout|in\s+out)$/i);
				
				my $aclass = shift @baz;
				
				if ($aclass =~ m/^(in|out)$/i)
				{
					# use first char as argclass
					$argclass[$nargs] = lc(substr($aclass, 0, 1));
				}
				else
				{
					$argclass[$nargs] = "b"; # [b]oth
				}
				
				# drop thru to handle two remaining args
				# (and don't allow multiple IN/OUT for same func_arg)
				die "$fnname: arg str badly formed: $argstr"
					if ($baz[0] =~ m/^(in|out|inout|in\s+out)$/i);
			}
			
			die "$fnname: arg str badly formed: $argstr"
				unless (2 == scalar(@baz));
			
			# last token is always a type
			my $arg1 = pop(@baz);
			$arg1 =~ s/\"//g;
			$arg1 =~ s/^\s+//;
			$arg1 =~ s/\s+$//g;
			push @argtype, $arg1;
			
			# remaining token is an arg_class or name
			if ($baz[0] =~ m/^(in|out|inout|in\s+out)$/i)
			{
				my $aclass = shift @baz;
				
				if ($aclass =~ m/^(in|out)$/i)
				{
					$argclass[$nargs] = lc(substr($aclass, 0, 1));
				}
				else # both
				{
					$argclass[$nargs] = "b";
				}
			}
			else # not a class, so it's a name
			{
				my $arg2 = pop(@baz);
				$arg2 =~ s/\"//g;
				$arg2 =~ s/^\s+//;
				$arg2 =~ s/\s+$//g;
				$argname[$nargs] = $arg2;
			}
			
		} # end split func_arg

		$nargs++;
	} # end for my func_arg
	
	for my $ftyp (@argtype)
	{
		push @argoids, get_typeoid($ftyp);				
	}
	
	# check list of names
	if (scalar(@argname))
	{
		# fill in blank names if necessary
		for my $ii (0..($nargs-1))
		{
			$argname[$ii] = ""
				unless (defined($argname[$ii]) &&
						length($argname[$ii]));
		}
		
		$fndef->{tuple}->{proargnames} = "{" .
			join(",", @argname) . "}";
	}
	
	my @iargs; # count the input args
	# check list of arg class
	if (scalar(@argclass))
	{
		# if no class specified, use "IN"
		for my $ii (0..($nargs-1))
		{
			$argclass[$ii] = "i"
				unless (defined($argclass[$ii]) &&
						length($argclass[$ii]));
			
			# distinguish input args from output
			push @iargs, $argoids[$ii]
				if ($argclass[$ii] !~ m/o/i);
		}
		
		$fndef->{tuple}->{proargmodes} = "{" .
			join(",", @argclass) . "}";
	}
	
	# sigh. stupid difference between representation for oidvector and
	# oid array.  This is an oid array for proallargtypes.  
	# Oidvector uses spaces, not commas.
	my $oidstr =  "{" . join(",", @argoids) . "}";
	
	# number of args is input args if have arg_class, else just count
	$fndef->{tuple}->{pronargs} = 
		scalar(@argclass) ? scalar(@iargs) : $nargs;
	if (scalar(@argclass))
	{
		# distinguish input args from all args
		$fndef->{tuple}->{proallargtypes} = $oidstr;
		$fndef->{tuple}->{proargtypes} = 
			join(" ", @iargs);

		# handle case of no input args (pg_get_keywords)
		$fndef->{tuple}->{proargtypes} = ""
			unless (defined($fndef->{tuple}->{proargtypes}) &&
					length($fndef->{tuple}->{proargtypes}));


	}
	else # no input args (or all input args...)
	{
		$fndef->{tuple}->{proargtypes} = 
			join(" ", @argoids);
	}
	return $oidstr;
	
} # end make_allargs


# parse the WITH clause
sub get_fnwithhash
{
	my $funcdef = shift;
	my %withh;
	use Text::ParseWords;


	if ($funcdef =~ m/with\s*\(.*\)/i)
	{
		my @baz = ($funcdef =~ m/(with\s*\(.*\))/is);
		
		die "bad WITH: $funcdef"  unless (scalar(@baz));

		my $withclause = shift @baz;

		$withclause =~ s/^\s*with\s*\(\s*//is;
		$withclause =~ s/\s*\)\s*$//s;

		# split by comma, but use Text::ParseWords::parse_line to
		# preserve quoted descriptions
		@baz = parse_line(",", 1, $withclause);

		for my $withdef (@baz)
		{
			my @bzz = split("=", $withdef, 2);

			die "bad WITH def: $withdef" unless (2 == scalar(@bzz));

			my $kk = shift @bzz;
			my $vv = shift @bzz;

			$kk =~ s/^\s+//;
			$kk =~ s/\s+$//;
			$kk = lc($kk);

			$vv =~ s/^\s+//;
			$vv =~ s/\s+$//;

			if ($kk =~ m/proisagg|proiswindow/)
			{
				# unquote the string
				$vv =~ s/\"//g;
			}
			if ($kk =~ m/prosrc/)
			{
				# double the single quotes
				$vv =~ s/\'/\'\'/g;
			}

			$withh{$kk} = $vv;
		}

	}

	return \%withh;
} # end get_fnwithhash

sub printfndef
{
	my $fndef = shift;
	my $bigstr = "";

	my $addcomment = 1;

	die "bad fn" unless (exists($fndef->{with}->{oid}));
	my $tup = $fndef->{tuple};
	my $nam = $fndef->{name};
	
	$nam =~ s/\"//g;

	if (exists($fndef->{prefix}) &&
		length($fndef->{prefix}))
	{
		$bigstr .= $fndef->{prefix};
	}
	
#		print Data::Dumper->Dump([$tup]);		
#		print $fndef->{name} . "\n\n";

	$bigstr .= "/* " .
		$fndef->{name} . "(" . 
		($fndef->{rawargs} ? $fndef->{rawargs} : "" ) . ") => " .
		(exists($fndef->{returntype}) ? $fndef->{returntype} : "()") . " */ \n"
		if ($addcomment);


	$bigstr .= "DATA(insert OID = " . $fndef->{with}->{oid} . " ( " .
		$nam . "  " . $tup->{pronamespace} . " " .
		$tup->{proowner} . " " .
		$tup->{prolang} . " " .
		$tup->{procost} . " " .
		$tup->{prorows} . " " .
		($tup->{provariadic} ? $tup->{provariadic} : "0") . " " .
		(exists($fndef->{with}->{proisagg}) ? $fndef->{with}->{proisagg} :
		 ($tup->{proisagg} ? "t" : "f") ) . " " .
		(exists($fndef->{with}->{proiswindow}) ? $fndef->{with}->{proiswindow} :
		 ($tup->{proiswindow} ? "t" : "f")) . " " .
		($tup->{prosecdef} ? "t" : "f") . " " .
		($tup->{proisstrict} ? "t" : "f") . " " .
		($tup->{proretset} ? "t" : "f") . " " .
		($tup->{provolatile} ? $tup->{provolatile} : "_null_" ) . " " .
		($tup->{pronargs} ? $tup->{pronargs} : 0) . " " .
		($tup->{pronargdefaults} ? $tup->{pronargdefaults} : 0) . " " .
		($tup->{prorettype} ? $tup->{prorettype} : '""') . " " .
		($tup->{proargtypes} ? '"'. $tup->{proargtypes} . '"' : '""') . " " .
		($tup->{proallargtypes} ? '"' . $tup->{proallargtypes} . '"'  : "_null_")  . " " .
		($tup->{proargmodes} ? '"' . $tup->{proargmodes} . '"' : "_null_") . " " .
		($tup->{proargnames} ? '"' . $tup->{proargnames} . '"' : "_null_") . " " .
		($tup->{proargdefault} ? $tup->{proargdefaults} : "_null_") . " " .
		(exists($fndef->{with}->{prosrc}) ? $fndef->{with}->{prosrc} :
		 ($tup->{prosrc} ? $tup->{prosrc} : "_null_" )) . " " .
		($tup->{probin} ? $tup->{probin} : "_null_") . " " .
		($tup->{proacl} ? $tup->{proacl} : "_null_") . " " . 
		($tup->{proconfig} ? $tup->{proconfig} : "_null_") . " " . 
		$tup->{prodataaccess} . " " .
		($tup->{proexeclocation} ? $tup->{proexeclocation} : "a" ) . " " .
		"));\n";
	$bigstr .= "DESCR(" . $fndef->{with}->{description} . ");\n"
		if (exists($fndef->{with}->{description}));
	$bigstr .= "\n"
		if ($addcomment);

	return $bigstr;
} # end printfndef

# MAIN routine for pg_proc generation
sub doprocs()
{
	
	my $whole_file;
	
	{
        # $$$ $$$ undefine input record separator (\n)
        # and slurp entire file into variable
		
        local $/;
        undef $/;
		
		my $fh;

		open $fh, "< $glob_glob->{procdef}" 
			or die "cannot open $glob_glob->{procdef}: $!";

		$whole_file = <$fh>;
		
		close $fh;
	}
	
	my @allfndef;
	my $fndefh;
	
	# XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX 
	# XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX 
	# NOTE: preprocess dollar quoted strings for SQL functions:
	if ($whole_file =~  m/\$\$/)
	{
		my @ddd = split(/(\$\$)/m, $whole_file);

		my @eee;

		my $gotone = -1;
		
		for my $d1 (@ddd)
		{
			$gotone *= -1
				if ($d1 =~ m/\$\$/);

			if (($gotone > 0) &&
				($d1 !~ m/\$\$/))
			{
				$d1 =~ s/\'/\'\'/gm; # double quote the single quotes

				# quurl - convert to a single quoted string without spaces
				$d1 =~ s/([^a-zA-Z0-9])/uc(sprintf("%%%02lx",  ord $1))/eg;

				# and make it a quoted, double quoted string (eg '"string"')
				$d1 = "'\"" . $d1 . "\"'";
			}
			# strip the $$ tokens
			push @eee, $d1
				if ($d1 !~ m/\$\$/);
		}
		$whole_file = join("", @eee);
	}
	# XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX 
	# XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX XXX 

	
	my @allfuncs = split(/\;\s*$/m, $whole_file);
	
#	print Data::Dumper->Dump(\@allfuncs);
	
	for my $funcdef (@allfuncs)
	{
		my $funcprefix;

		undef $funcprefix;

		# find "prefix", ie comments or #DEF's, preceding function definition.
		if ($funcdef =~ m/\s*\-\-.*create func/ims)
		{
			my @ppp = ($funcdef =~ m/(^\s*\-\-.*\n)\s*create func/ims);

#			print "ppp: ",Data::Dumper->Dump(\@ppp);

			if (scalar(@ppp))
			{
				my @qqq = split(/\n/, $ppp[0]);

				$funcprefix = "";

				for my $l1 (@qqq)
				{
					# uncomment #DEF's 
					if ($l1 =~ m/^\s*\-\- \#define/)
					{
						$l1 =~ s|\-\-\s*||;
					}
					# convert to c-style comments
					if ($l1 =~ m/^\s*\-\-/)
					{
						$l1 =~ s|\-\-|\/\*|;
						$l1 .= " */";
					}
					$funcprefix .= $l1 . "\n";
				}

				my $rex2 = quotemeta($ppp[0]);

				# remove the prefix
				$funcdef =~ s/$rex2//;

#				print $funcprefix;
			}

		}

		next
			unless ($funcdef =~ 
					m/create func(?:tion)*\s+((\w+\.)*(\")*(\w+)(\")*)/i);
		my $orig = $funcdef;
		
		# strip "create function"
		$funcdef =~ s/^\s*create func(?:tion)*\s*//i;
		
		# find function name (precedes leading paren)
		my @foo = split(/\(\s*/, $funcdef, 2);
		
		die "bad funcdef: $orig" unless (2 == scalar(@foo));
		
		my $funcname = shift @foo;
		my $fnrex = quotemeta($funcname);
		
		# strip func name
		$funcdef =~ s/\s*$fnrex\s*//;
		
		@foo = split(/\s*\)/, $funcdef, 2);		
		
		die "bad funcdef: $orig" unless (2 == scalar(@foo));
		
		my $fnargs = shift @foo;
		# remove leading paren
		$fnargs =~ s/\s*\(//;
		
		$funcdef = shift @foo;
		
		die "bad funcdef - no RETURNS: $orig" 
			unless ($funcdef =~ m/\s*RETURN/i);
		
		$funcdef =~ s/\s+RETURNS\s+//i;

		my $fntdef = get_fntype($funcdef);

		# remove the function arg list tokens
		@foo = split(/\s+/, $fntdef);
		for my $ff (@foo)
		{
			$ff = quotemeta($ff);
			$funcdef =~ s/^$ff//;
		}

#		print "name: $funcname\nargs: $fnargs\nreturns: $fntdef\nrest: $funcdef\n";

#		print Data::Dumper->Dump(get_fnoptlist($funcdef));
		my $t1 = get_fnoptlist($funcdef);
		my $w1 = get_fnwithhash($funcdef);
#		print "name: $funcname\nargs: $fnargs\nreturns: $fntdef\nrest: $funcdef\n";
#		print Data::Dumper->Dump($t1);

		$fndefh = { name=> $funcname, rawtxt => $orig, 
					returntype => $fntdef,
					rawargs => $fnargs, optlist => $t1, with => $w1 };

		$fndefh->{prefix} = $funcprefix
			if (defined($funcprefix));

		push @allfndef, $fndefh;
	}


#	print Data::Dumper->Dump(\@allfndef);

	for my $fndef (@allfndef)
	{
		make_opt($fndef);
		make_rettype($fndef);
		make_allargs($fndef);

		# Fill in defaults for procost and prorows. (We have to do this
		# after make_rettype, as we don't know if it's a set-returning function
		# before that.
		$fndef->{tuple}->{procost} = 1 unless defined($fndef->{tuple}->{procost});
		if ($fndef->{tuple}->{proretset})
		{
		    $fndef->{tuple}->{prorows} = 1000 unless defined($fndef->{tuple}->{prorows});
		}
		else
		{
		    $fndef->{tuple}->{prorows} = 0
		}
	}

#	print Data::Dumper->Dump(\@allfndef);

    my $verzion = "unknown";
	$verzion = $glob_glob->{_sleazy_properties}->{version}
	if (exists($glob_glob->{_sleazy_properties}) &&
		exists($glob_glob->{_sleazy_properties}->{version}));

	$verzion = $0 . " version " . $verzion;
	my $nnow = localtime;
	my $gen_hdr_str = "";
#	$gen_hdr_str = "/* TIDYCAT_BEGIN_PG_PROC_GEN \n\n";
	$gen_hdr_str = "\n";
	$gen_hdr_str .= "   WARNING: DO NOT MODIFY THE FOLLOWING SECTION: \n" .
		"   Generated by " . $verzion . "\n" . 
		"   on " . $nnow . "\n\n" . 
		"   Please make your changes in " . $glob_glob->{procdef} . "\n*/\n\n";

	my $bigstr = "";

	$bigstr .= $gen_hdr_str;

	# build definitions in same order as input file
	for my $fndef (@allfndef)
	{
		$bigstr .= printfndef($fndef);
	}

	$bigstr .= "\n";
#	$bigstr .= "\n\n/* TIDYCAT_END_PG_PROC_GEN */\n";

	if (0)
	{
		print $bigstr;
	}
	else
	{
        # $$$ $$$ undefine input record separator (\n)
        # and slurp entire file into variable
		
        local $/;
        undef $/;
		
		my $tfh;

		open $tfh, "< $glob_glob->{prochdr}" 
			or die "cannot open $glob_glob->{prochdr}: $!";

		my $target_file = <$tfh>;
		
		close $tfh;

		my $prefx = quotemeta('TIDYCAT_BEGIN_PG_PROC_GEN');
		my $suffx = quotemeta('TIDYCAT_END_PG_PROC_GEN');

		my @zzz = ($target_file =~ 
				   m/^\s*\/\*\s*$prefx\s*\s*$(.*)^\s*\/\*\s*$suffx\s*\*\/\s*$/ms);

		die "bad target: $glob_glob->{prochdr}"
			unless (scalar(@zzz));

		my $rex = $zzz[0];

		# replace carriage returns first, then quotemeta, then fix CR again...
		$rex =~ s/\n/SLASHNNN/gm;
		$rex = quotemeta($rex);
		$rex =~ s/SLASHNNN/\\n/gm;

		# substitute the new generated proc definitions for the prior
		# generated defitions in the target file
		$target_file =~ s/$rex/$bigstr/ms;

		# save a backup file
		system "cp $glob_glob->{prochdr} $glob_glob->{prochdr}.backup";

		my $outi;

		open $outi, "> $glob_glob->{prochdr}" 
			or die "cannot open $glob_glob->{prochdr} for write: $!";
		
		# rewrite the target file
		print $outi $target_file;

		close $outi;
		
	}


}

# MAIN routine for pg_type parsing
sub readtypes
{
	my $fh;

	open $fh, "< pg_type.h"
	    or die "cannot open pg_type.h: $!";

	while (my $row = <$fh>)
	{
	    # The DATA lines in pg_type.h look like this:
	    #   DATA(insert OID = 16 (	bool	   ...));
	    #
	    # Extract the oid and the type name.
	    $row =~ /^DATA\(insert\s+OID\s+=\s+(\d+)\s+\(\s+(\w+).*\)/ or next;
	    my $oid = $1;
	    my $typname = $2;

	    # save the oid for each typename for CREATE TYPE...ELEMENT lookup
	    $glob_typeoidh{lc($typname)} = $oid;
	}
	close $fh;
}

if (1)
{
	readtypes();
	doprocs();
}


# SLZY_TOP_BEGIN
if (0)
{
    my $bigstr = <<'EOF_bigstr';
{
   "args" : [
      {
         "alias" : "?",
         "long" : "Print a brief help message and exits.",
         "name" : "help",
         "required" : "0",
         "short" : "brief help message",
         "type" : "untyped"
      },
      {
         "long" : "Prints the manual page and exits.",
         "name" : "man",
         "required" : "0",
         "short" : "full documentation",
         "type" : "untyped"
      },
      {
         "alias" : "prosource|procsource|prosrc|procsrc",
         "long" : "sql definitions for pg_proc functions (normally pg_proc.sql)",
         "name" : "procdef",
         "required" : "1",
         "short" : "sql definitions for pg_proc functions",
         "type" : "file"
      },
      {
         "alias" : "proheader|procheader|prohdr",
         "long" : "header file to modify (normally pg_proc_gp.h).  The original file is copied to a .backup copy.",
         "name" : "prochdr",
         "required" : "1",
         "short" : "header file to modify (procedures)",
         "type" : "file"
      },
   ],
   "long" : "$toplong",
   "properties" : {
      "slzy_date" : 1317671892
   },
   "short" : "generate pg_proc entries",
   "version" : "8"
}

EOF_bigstr
}
# SLZY_TOP_END


# SLZY_LONG_BEGIN
if (0)
{
	my $toplong = <<'EOF_toplong';
catullus.pl converts annotated sql CREATE FUNCTION and CREATE TYPE
statements into pg_proc and updates pg_proc_gp.h.

The pg_proc definitions are stored in pg_proc.sql.  catullus reads
these definitions and, using type information from pg_type.h,
generates DATA statements for loading the pg_proc table.  In
pg_proc_gp.h, it looks for a block of code delimited by the tokens
TIDYCAT_BEGIN_PG_PROC_GEN and TIDYCAT_END_PG_PROC_GEN and substitutes
the new generated code for the previous contents.

{HEAD1} CAVEATS/FUTURE WORK

The aggregate transition functions are constructed from CREATE
FUNCTION statements.  But we should really use CREATE AGGREGATE
statements to generate the DATA statements for pg_aggregate and the
pg_proc entries.  A similar limitation exists for window functions in
pg_window.  And operators and operator classes?  Access methods? Casts?

EOF_toplong


}
# SLZY_LONG_END
