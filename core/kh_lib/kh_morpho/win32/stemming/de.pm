package kh_morpho::win32::stemming::de;
use strict;
use base qw( kh_morpho::win32::stemming );

sub init{
	my $self = shift;
	
	$self->{icode} = kh_jchar->check_code($self->target,1);
	
	$self->{splitter} = Lingua::Sentence->new('de');
	$self->{stemmer}  = Lingua::Stem::Snowball->new(
		lang     => 'de',
		encoding => 'UTF-8'
	);
	
	return $self;
}

sub tokenize{
	my $self = shift;
	my $t    = shift;

	# ʸ������
	$t =~ s/(.+)(["|''|']{0,1}[\.|\!+|\?+|\!+\?|\?+\!+]["|''|']{0,1})\s*$/\1 \2/go;

	# �����
	$t =~ s/(\S),([\s|\Z])/\1 ,\2/go;

	# ���֥륯�����Ȥ䥫�å���
	$t =~ s/(''|``|"|\(|\)|\[|\]|\{|\})(\S)/\1 \2/go;
	$t =~ s/(\S)(''|``|"|\(|\)|\[|\]|\{|\})/\1 \2/go;

	# ���󥰥륯������
	$t =~ s/(\S)'([\s|\Z])/\1 '\2/go;
	$t =~ s/(\s|^)'(\S)/\1' \2/go;

	my @words_hyoso = split / /, $t;

	return(\@words_hyoso, undef);
}


1;