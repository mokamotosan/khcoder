package kh_cod::search;
use base qw(kh_cod);
use strict;

use mysql_exec;

my %sql_join = (
	'bun' =>
		'bun.id = bun_r.id',
	'dan' =>
		'
			    dan.dan_id = bun.dan_id
			AND dan.h5_id = bun.h5_id
			AND dan.h4_id = bun.h4_id
			AND dan.h3_id = bun.h3_id
			AND dan.h2_id = bun.h2_id
			AND dan.h1_id = bun.h1_id
		',
	'h5' =>
		'
			    h5.h5_id = bun.h5_id
			AND h5.h4_id = bun.h4_id
			AND h5.h3_id = bun.h3_id
			AND h5.h2_id = bun.h2_id
			AND h5.h1_id = bun.h1_id
		',
	'h4' =>
		'
			    h4.h4_id = bun.h4_id
			AND h4.h3_id = bun.h3_id
			AND h4.h2_id = bun.h2_id
			AND h4.h1_id = bun.h1_id
		',
	'h3' =>
		'
			    h3.h3_id = bun.h3_id
			AND h3.h2_id = bun.h2_id
			AND h3.h1_id = bun.h1_id
		',
	'h2' =>
		'
			    h2.h2_id = bun.h2_id
			AND h2.h1_id = bun.h1_id
		',
	'h1' =>
		'h1.h1_id = bun.h1_id'
);

sub new{
	my $class = shift;
	my $self;
	$self->{dummy} = '0';
	
	bless $self, $class;
	
	return $self;
}

#------------------------------#
#   直接入力コードの読み込み   #

sub add_direct{
	my $self = shift;
	my %args = @_;
	
	# 既に追加されていた場合はいったん削除
	if ($self->{codes}){
		if ($self->{codes}[0]->name eq '＃直接入力'){
			print "Delete old \'direct\'\n";
			shift @{$self->{codes}};
		}
	}
	
	if ($args{mode} eq 'code'){                   #「code」の場合
		unshift @{$self->{codes}}, kh_cod::a_code->new(
			'＃直接入力',
			Jcode->new($args{raw})->euc
		);
	} else {                                      # 「AND」,「OR」の場合
		$args{raw} = Jcode->new($args{raw})->tr('　',' ')->euc;
		$args{raw} =~ tr/\t\n/  /;
		my ($n, $t) = (0,'');
		foreach my $i (split / /, $args{raw}){
			unless ( length($i) ){next;}
			if ($n){$t .= " $args{mode} ";}
			$t .= "$i";
			++$n;
		}
		unshift @{$self->{codes}}, kh_cod::a_code->new(
			'＃直接入力',
			$t
		);
	}

}

#----------------#
#   検索の実行   #

sub search{
	my $self = shift;
	my %args = @_;
	
	$self->{tani} = $args{tani};
	
	# コーディング結果をクリア
	foreach my $i (@{$self->{codes}}){
		$i->clear;
	}
	$self->{valid_codes} = undef;
	
	# 取りあえず全部コーディング (もうちょっと効率的な方法ないかなぁ・・・)
	print "kh_cod::search -> coding...\n";
	$self->code($self->{tani}) or return 0;
	unless ($self->valid_codes){ return undef; }
	
	# AND条件の時に、0コードが存在した場合はreturn
	unless ($self->{valid_codes}){
		return undef;
	}
	if (
		   ( $args{method} eq 'and' )
		&& ( @{$self->{valid_codes}} < @{$args{selected}} )
	) {
		return undef;
	}
	
	# 合致する文書のリストを取得
	print "kh_cod::search -> searching...\n";
	my $sql = "SELECT $args{tani}.id\nFROM $args{tani}\n";
	foreach my $i (@{$args{selected}}){
		unless ($self->{codes}[$i]->res_table){
			next;
		}
		$sql .=
			"LEFT JOIN "
			.$self->{codes}[$i]->res_table
			." ON $args{tani}.id = "
			.$self->{codes}[$i]->res_table
			.".id\n";
	}
	$sql .= "WHERE\n";
	my $n = 0;
	foreach my $i (@{$args{selected}}){
		if ($n){ $sql .= "$args{method} "; }
		if ($self->{codes}[$i]->res_table){
			$sql .=
				"IFNULL("
				.$self->{codes}[$i]->res_table
				."."
				.$self->{codes}[$i]->res_col
				.",0)\n";
		} else {
			$sql .= "0\n";
		}
		++$n;
	}
	my $sth = mysql_exec->select($sql,1)->hundle;
	
	# 文書の先頭部分を取り出し
	my @result;
	print "kh_cod::search -> fetching";
	while (my $i = $sth->fetch){
		push @result, [
			$i->[0],
			kh_cod::search->get_doc_head($i->[0],$args{tani})
		];
		print ".";
	}
	print "\n";
	
	# 検索に利用した語（表層）のリスト
	print "kh_cod::search -> getting word list...\n";
	my (@words, %words);
	foreach my $i (@{$args{selected}}){
		unless ($self->{codes}[$i]->res_table){
			next;
		}
		if ($self->{codes}[$i]->hyosos){
			foreach my $h (@{$self->{codes}[$i]->hyosos}){
				++$words{$h};
			}
		}
	}
	@words = (keys %words);
	

	
	return (\@result,\@words);
}

#-----------------------------------------#
#   1つの文書に与えられたコードのリスト   #

sub check_a_doc{
	my $self   = shift;
	my $doc_id = shift;
	
	# コーディング
	my $text = 
		"・この文書にヒットしたコード （現在開いているコーディング・ルールファイルの中で）\n";
	my (@words, %words);
	foreach my $i (@{$self->{codes}}){
		unless ($i->res_table){next;}
		my $sql .= 
			"SELECT ".$i->res_col." FROM ".$i->res_table." WHERE id = $doc_id";
		if (mysql_exec->select($sql,1)->hundle->rows){
			$text .= "    ".$i->name."\n";
			if ($i->hyosos){
				foreach my $h (@{$i->hyosos}){
					++$words{$h};
				}
			}
		}
	}
	@words = (keys %words);
	
	$text = Jcode->new($text)->sjis;
	return ($text,\@words);
}


#--------------------------#
#   文書の先頭部分を取得   #

sub get_doc_head{
	my $self = shift;
	my $id   = shift;
	my $tani = shift;
	
	my $sql;
	if ($tani eq 'bun'){
		$sql = "
			SELECT rowtxt
			FROM bun_r, bun
			WHERE
				    bun_r.id = bun.id
				AND bun.id = $id
		";
	} else {
		$sql = "
			SELECT rowtxt
			FROM bun_r, bun, $tani
			WHERE $sql_join{$tani}
				AND bun_r.id = bun.id
				AND $tani.id = $id
			LIMIT 5
		";
	}
	
	my $sth = mysql_exec->select($sql,1)->hundle;
	
	my $r;
	while (my $i = $sth->fetch){
		$r .= $i->[0];
		if (length($r) > $::config_obj->DocSrch_CutLength){
			last;
		}
	}
	
	# 切り落とし
	if (length($r) > $::config_obj->DocSrch_CutLength){
		my $len = $::config_obj->DocSrch_CutLength;
		if (
			substr($r,0,$len) =~ /\x8F$/
			or substr($r,0,$len) =~ tr/\x8E\xA1-\xFE// % 2 
		){
			--$len;
			if (
				substr($r,0,$len) =~ /\x8F$/
				or substr($r,0,$len) =~ tr/\x8E\xA1-\xFE// % 2 
			){
				--$len;
			}
		}
		$r = substr($r,0,$len);
		$r .= '…';
	}
	
	return $r;
	
}



1;