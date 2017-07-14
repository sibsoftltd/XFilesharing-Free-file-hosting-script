package DataBase;

use strict;
use DBI;
use XFileConfig;

sub new{
  my $class=shift;
  my $self={ dbh=>undef };
  bless $self,$class;
  $self->InitDB;
  return $self;
}

sub inherit{
  my $class = shift;
  my $dbh   = shift;
  my $self={ dbh=>undef };
  bless $self,$class;
  $self->{dbh} = $dbh;
  return $self;
}


sub dbh{shift->{dbh}}

sub InitDB{
  my $self=shift;
  $self->{dbh}=DBI->connect("DBI:mysql:database=$c->{'db_name'};host=$c->{'db_host'}",$c->{'db_login'},$c->{'db_passwd'}) || die ("Can't connect to Mysql server.".$! );
}

sub DESTROY{
  shift->UnInitDB();
}

sub UnInitDB{
  my $self=shift;
  if($self->dbh)
  {
    if($self->{locks})
    {
          $self->Unlock();
    }
    $self->dbh->disconnect;
  }
  $self->{dbh}=undef;
}

sub Lock{
  my ($self,$db)=@_;
  $self->Exec('LOCK TABLES '.$db.' WRITE');
  $self->{locks}={} unless $self->{locks};
  $self->{locks}->{$db}++;
}

sub Unlock{
  my $self=shift;
  $self->Exec('UNLOCK TABLES');
  $self->{locks}={};
}

sub Exec{
  my $self=shift;
  my $expr=shift;
  my $rc=$self->{dbh}->do($expr,undef,@_)||die "Can't exec:\s $expr \n".$self->dbh->errstr;
  die "Can't exec:\s $expr \n".$self->dbh->errstr unless $rc;
}


sub ExecBunch{
  my $self=shift;
  my $expr=shift;
  my $bunch_data=shift;

  my $sth = $self->{dbh}->prepare($expr) || die "Can't prepare bunch exec:\s $expr \n".$self->dbh->errstr;
  foreach my $param_arr (@{$bunch_data}){
    #&dlog("$expr ".join(", ", @{$param_arr}));
    $sth->execute(@{$param_arr}) || die "Can't execute bunch row:\s $expr \n".$self->dbh->errstr;
  }
  $sth->finish();
  return 1;

}

### Can't use Select becase row_cid etc...
sub SelectOne{
  my $self=shift;
  my $ex=shift;
  my $sth=$self->{dbh}->prepare($ex);
  die $self->{dbh}->errstr unless $sth;
  #&dlog("Select: $ex");     
  my $rc=$sth->execute(@_) || die "Can't exec select:\n $ex \n".$self->dbh->errstr;
  return undef unless $rc;
  my @arr=$sth->fetchrow_array;
     $sth->finish();
  return @arr ? $arr[0]:undef;

};

sub SelectRow{
  my $dta=shift->Select(@_);
  if($dta)
  {
    return $dta->[0];
  }
  return undef;
}

sub SelectARef
{
   my $self = shift;
   sub ARef
   {
     my $data=shift;
     $data=[] unless $data;
     $data=[$data] unless ref($data) eq 'ARRAY';
     return $data;
   }
   return &ARef($self->Select(@_));
}
sub Select
{
  my $self=shift;
  my $ex=shift;
  my $sth=$self->{dbh}->prepare($ex);
  die $self->{dbh}->errstr unless $sth;
  #&dlog("Select: $ex");     
  my $rc=$sth->execute(@_) || die "Can't exec select:\n $ex \n".$self->dbh->errstr;
  return undef unless $rc;
  return undef unless $sth->rows;
  my @res;
  my $cidxor=0;
  while(my $hr=$sth->fetchrow_hashref)
  {
    #last unless $hr;
    $hr->{row_cid} = $cidxor ^ 1;
    $cidxor = $hr->{row_cid}; 
    push @res,$hr;
  }
  $sth->finish();
  return @res?\@res:undef;
}

sub getLastInsertId
{
  my $self = shift;
  return $self->{ dbh }->{'mysql_insertid'};
#    #Get Last Insert ID
#    my $sth = $self->{ dbh }->prepare("SELECT LAST_INSERT_ID() as last_id" );
#       $sth->execute() || die "Can't get last insert id select:\n".$self->dbh->errstr;
#    my $row = $sth->fetchrow_hashref;
#       $sth->finish();
#
#    return $$row{ last_id };
}


1;                                                           
