package HTML::Template;
$HTML::Template::VERSION='2.7';
use integer;
use strict;
use Carp;
use File::Spec;
use Digest::MD5 qw(md5_hex);
package HTML::Template::LOOP;
sub TEMPLATE_HASH () { 0; }sub PARAM_SET     () { 1 };
package HTML::Template::COND;
sub VARIABLE           () { 0 };
sub VARIABLE_TYPE      () { 1 };
sub VARIABLE_TYPE_VAR  () { 0 };
sub VARIABLE_TYPE_LOOP () { 1 };
sub JUMP_IF_TRUE       () { 2 };
sub JUMP_ADDRESS       () { 3 };
sub WHICH              () { 4 };
sub WHICH_IF           () { 0 };
sub WHICH_UNLESS       () { 1 };
package HTML::Template;
sub new {
my $pkg=shift;
my $self; { my %hash; $self=bless(\%hash,$pkg); }my $options={};
$self->{options}=$options;
%$options=(
debug => 0,stack_debug => 0,timing => 0,search_path_on_include => 0,cache => 0,blind_cache => 0,file_cache => 0,file_cache_dir => '',file_cache_dir_mode => 0700,cache_debug => 0,shared_cache_debug => 0,memory_debug => 0,die_on_bad_params => 1,vanguard_compatibility_mode => 0,associate => [],path => [],strict => 1,loop_context_vars => 0,max_includes => 10,shared_cache => 0,double_cache => 0,double_file_cache => 0,ipc_key => 'TMPL',ipc_mode => 0666,ipc_segment_size => 65536,ipc_max_size => 0,global_vars => 0,no_includes => 0,case_sensitive => 0,filter => [],);
for (my $x=0; $x <= $#_; $x += 2){defined($_[($x + 1)]) or croak("HTML::Template->new() called with odd number of option parameters - should be of the form option => value");
$options->{lc($_[$x])}=$_[($x + 1)]; 
}$options->{blind_cache} and $options->{cache}=1;
$options->{shared_cache} and $options->{cache}=1;
$options->{file_cache} and $options->{cache}=1;
$options->{double_cache} and $options->{cache}=1;
$options->{double_cache} and $options->{shared_cache}=1;
$options->{double_file_cache} and $options->{cache}=1;
$options->{double_file_cache} and $options->{file_cache}=1;
$options->{vanguard_compatibility_mode} and 
$options->{die_on_bad_params}=0;
if(exists($options->{type})){exists($options->{source}) or croak("HTML::Template->new() called with 'type' parameter set,but no 'source'!");
($options->{type} eq 'filename' or $options->{type} eq 'scalarref' or
$options->{type} eq 'arrayref' or $options->{type} eq 'filehandle') or
croak("HTML::Template->new() : type parameter must be set to 'filename','arrayref','scalarref' or 'filehandle'!");
$options->{$options->{type}}=$options->{source};
delete $options->{type};
delete $options->{source};
}if(ref($options->{associate}) ne 'ARRAY'){$options->{associate}=[ $options->{associate} ];
}if(ref($options->{path}) ne 'ARRAY'){$options->{path}=[ $options->{path} ];
}if(ref($options->{filter}) ne 'ARRAY'){$options->{filter}=[ $options->{filter} ];
}foreach my $object (@{$options->{associate}}){defined($object->can('param')) or
croak("HTML::Template->new called with associate option,containing object of type " . ref($object) . " which lacks a param() method!");
} 
my $source_count=0;
exists($options->{filename}) and $source_count++;
exists($options->{filehandle}) and $source_count++;
exists($options->{arrayref}) and $source_count++;
exists($options->{scalarref}) and $source_count++;
if($source_count != 1){croak("HTML::Template->new called with multiple (or no) template sources specified!  A valid call to new() has exactly one filename => 'file' OR exactly one scalarref => \\\$scalar OR exactly one arrayref => \\\@array OR exactly one filehandle => \*FH");
}if(exists($options->{filename})){croak("HTML::Template->new called with empty filename parameter!")
unless defined $options->{filename} and length $options->{filename};
}if($options->{memory_debug}){eval { require GTop; };
croak("Could not load GTop.  You must have GTop installed to use HTML::Template in memory_debug mode.  The error was: $@")
if($@);
$self->{gtop}=GTop->new();
$self->{proc_mem}=$self->{gtop}->proc_mem($$);
print STDERR "\n### HTML::Template Memory Debug ### START ",$self->{proc_mem}->size(),"\n";
}if($options->{file_cache}){croak("You must specify the file_cache_dir option if you want to use file_cache.") 
unless defined $options->{file_cache_dir} and 
length $options->{file_cache_dir};
eval { require Storable; };
croak("Could not load Storable.  You must have Storable installed to use HTML::Template in file_cache mode.  The error was: $@")
if($@);
}if($options->{shared_cache}){eval { require IPC::SharedCache; };
croak("Could not load IPC::SharedCache.  You must have IPC::SharedCache installed to use HTML::Template in shared_cache mode.  The error was: $@")
if($@);
my %cache;
tie %cache,'IPC::SharedCache',ipc_key => $options->{ipc_key},load_callback => [\&_load_shared_cache,$self],validate_callback => [\&_validate_shared_cache,$self],debug => $options->{shared_cache_debug},ipc_mode => $options->{ipc_mode},max_size => $options->{ipc_max_size},ipc_segment_size => $options->{ipc_segment_size};
$self->{cache}=\%cache;
}print STDERR "### HTML::Template Memory Debug ### POST CACHE INIT ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
$self->_init;
print STDERR "### HTML::Template Memory Debug ### POST _INIT CALL ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
delete $self->{cache} if $options->{shared_cache};
return $self;
}sub _new_from_loop {
my $pkg=shift;
my $self; { my %hash; $self=bless(\%hash,$pkg); }my $options={};
$self->{options}=$options;
%$options=(
debug => 0,stack_debug => 0,die_on_bad_params => 1,associate => [],loop_context_vars => 0,);
for (my $x=0; $x <= $#_; $x += 2) { 
defined($_[($x + 1)]) or croak("HTML::Template->new() called with odd number of option parameters - should be of the form option => value");
$options->{lc($_[$x])}=$_[($x + 1)]; 
}$self->{param_map}=$options->{param_map};
$self->{parse_stack}=$options->{parse_stack};
delete($options->{param_map});
delete($options->{parse_stack});
return $self;
}sub new_file {
my $pkg=shift; return $pkg->new('filename',@_);
}sub new_filehandle {
my $pkg=shift; return $pkg->new('filehandle',@_);
}sub new_array_ref {
my $pkg=shift; return $pkg->new('arrayref',@_);
}sub new_scalar_ref {
my $pkg=shift; return $pkg->new('scalarref',@_);
}sub _init {
my $self=shift;
my $options=$self->{options};
if($options->{double_cache}){$self->_fetch_from_cache();
return if(defined $self->{param_map} and defined $self->{parse_stack});
$self->_fetch_from_shared_cache();
$self->_commit_to_cache()
if(defined $self->{param_map} and defined $self->{parse_stack});
} elsif($options->{double_file_cache}){$self->_fetch_from_cache();
return if(defined $self->{param_map} and defined $self->{parse_stack});
$self->_fetch_from_file_cache();
$self->_commit_to_cache()
if(defined $self->{param_map} and defined $self->{parse_stack});
} elsif($options->{shared_cache}){$self->_fetch_from_shared_cache();
} elsif($options->{file_cache}){$self->_fetch_from_file_cache();
} elsif($options->{cache}){$self->_fetch_from_cache();
}return if(defined $self->{param_map} and defined $self->{parse_stack});
$self->_init_template();
$self->_parse();
if($options->{file_cache}){
$self->_commit_to_file_cache();
}$self->_commit_to_cache() if(($options->{cache}and not $options->{shared_cache}and not $options->{file_cache}) or
($options->{double_cache}) or
($options->{double_file_cache}));
}use vars qw( %CACHE );
sub _fetch_from_cache {
my $self=shift;
my $options=$self->{options};
return unless exists($options->{filename});
my $filepath=$self->_find_file($options->{filename});
return unless (defined($filepath));
$options->{filepath}=$filepath;
my $key=$self->_cache_key();
return unless exists($CACHE{$key});  
my $mtime=$self->_mtime($filepath);  
if(defined $mtime){if(defined($CACHE{$key}{mtime}) and 
($mtime != $CACHE{$key}{mtime})){$options->{cache_debug} and 
print STDERR "CACHE MISS : $filepath : $mtime\n";
return;
}if(exists($CACHE{$key}{included_mtimes})){foreach my $filename (keys %{$CACHE{$key}{included_mtimes}}){next unless 
defined($CACHE{$key}{included_mtimes}{$filename});
my $included_mtime=(stat($filename))[9];
if($included_mtime != $CACHE{$key}{included_mtimes}{$filename}){$options->{cache_debug} and 
print STDERR "### HTML::Template Cache Debug ### CACHE MISS : $filepath : INCLUDE $filename : $included_mtime\n";
return;
}}}}$options->{cache_debug} and print STDERR "### HTML::Template Cache Debug ### CACHE HIT : $filepath => $key\n";
$self->{param_map}=$CACHE{$key}{param_map};
$self->{parse_stack}=$CACHE{$key}{parse_stack};
exists($CACHE{$key}{included_mtimes}) and
$self->{included_mtimes}=$CACHE{$key}{included_mtimes};
$self->_normalize_options();
$self->clear_params();
}sub _commit_to_cache {
my $self=shift;
my $options=$self->{options};
my $key=$self->_cache_key();
my $filepath=$options->{filepath};
$options->{cache_debug} and print STDERR "### HTML::Template Cache Debug ### CACHE LOAD : $filepath => $key\n";
$options->{blind_cache} or
$CACHE{$key}{mtime}=$self->_mtime($filepath);
$CACHE{$key}{param_map}=$self->{param_map};
$CACHE{$key}{parse_stack}=$self->{parse_stack};
exists($self->{included_mtimes}) and
$CACHE{$key}{included_mtimes}=$self->{included_mtimes};
}sub _cache_key {
my $self=shift;
my $options=$self->{options};
my $filepath=$options->{filepath};
if(not defined $filepath){$filepath=$self->_find_file($options->{filename});
confess("HTML::Template->new() : Cannot find file '$options->{filename}'.")
unless defined($filepath);
$options->{filepath}=$filepath;   
}my @key=($filepath);
push(@key,@{$options->{path}}) if $options->{path};
push(@key,$options->{search_path_on_include} || 0);
push(@key,$options->{loop_context_vars} || 0);
push(@key,$options->{global_vars} || 0);
return md5_hex(@key);
}sub _get_cache_filename {
my ($self,$filepath)=@_;
$self->{options}{filepath}=$filepath;
my $hash=$self->_cache_key();
if(wantarray){return (substr($hash,0,2),substr($hash,2))
} else {
return File::Spec->join($self->{options}{file_cache_dir},substr($hash,0,2),substr($hash,2));
}}sub _fetch_from_file_cache {
my $self=shift;
my $options=$self->{options};
return unless exists($options->{filename});
my $filepath=$self->_find_file($options->{filename});
return unless defined $filepath;
my $cache_filename=$self->_get_cache_filename($filepath);
return unless -e $cache_filename;
eval {
$self->{record}=Storable::lock_retrieve($cache_filename);
};
croak("HTML::Template::new() - Problem reading cache file $cache_filename (file_cache => 1) : $@")
if $@;
croak("HTML::Template::new() - Problem reading cache file $cache_filename (file_cache => 1) : $!") 
unless defined $self->{record};
($self->{mtime},$self->{included_mtimes},$self->{param_map},$self->{parse_stack})=@{$self->{record}};
$options->{filepath}=$filepath;
my $mtime=$self->_mtime($filepath);
if(defined $mtime){if(defined($self->{mtime}) and 
($mtime != $self->{mtime})){$options->{cache_debug} and 
print STDERR "### HTML::Template Cache Debug ### FILE CACHE MISS : $filepath : $mtime\n";
($self->{mtime},$self->{included_mtimes},$self->{param_map},$self->{parse_stack})=(undef,undef,undef,undef);
return;
}if(exists($self->{included_mtimes})){foreach my $filename (keys %{$self->{included_mtimes}}){next unless 
defined($self->{included_mtimes}{$filename});
my $included_mtime=(stat($filename))[9];
if($included_mtime != $self->{included_mtimes}{$filename}){$options->{cache_debug} and 
print STDERR "### HTML::Template Cache Debug ### FILE CACHE MISS : $filepath : INCLUDE $filename : $included_mtime\n";
($self->{mtime},$self->{included_mtimes},$self->{param_map},$self->{parse_stack})=(undef,undef,undef,undef);
return;
}}}}$options->{cache_debug} and print STDERR "### HTML::Template Cache Debug ### FILE CACHE HIT : $filepath\n";
$self->_normalize_options();
$self->clear_params();
}sub _commit_to_file_cache {
my $self=shift;
my $options=$self->{options};
my $filepath=$options->{filepath};
if(not defined $filepath){$filepath=$self->_find_file($options->{filename});
confess("HTML::Template->new() : Cannot open included file $options->{filename} : file not found.")
unless defined($filepath);
$options->{filepath}=$filepath;   
}my ($cache_dir,$cache_file)=$self->_get_cache_filename($filepath);  
$cache_dir=File::Spec->join($options->{file_cache_dir},$cache_dir);
if(not -d $cache_dir){if(not -d $options->{file_cache_dir}){mkdir($options->{file_cache_dir},$options->{file_cache_dir_mode})
or croak("HTML::Template->new() : can't mkdir $options->{file_cache_dir} (file_cache => 1): $!");
}mkdir($cache_dir,$options->{file_cache_dir_mode})
or croak("HTML::Template->new() : can't mkdir $cache_dir (file_cache => 1): $!");
}$options->{cache_debug} and print STDERR "### HTML::Template Cache Debug ### FILE CACHE LOAD : $options->{filepath}\n";
my $result;
eval {
$result=Storable::lock_store([ $self->{mtime},$self->{included_mtimes},$self->{param_map},$self->{parse_stack} ],scalar File::Spec->join($cache_dir,$cache_file)
);
};
croak("HTML::Template::new() - Problem writing cache file $cache_dir/$cache_file (file_cache => 1) : $@")
if $@;
croak("HTML::Template::new() - Problem writing cache file $cache_dir/$cache_file (file_cache => 1) : $!")
unless defined $result;
}sub _fetch_from_shared_cache {
my $self=shift;
my $options=$self->{options};
my $filepath=$self->_find_file($options->{filename});
return unless defined $filepath;
$self->{record}=$self->{cache}{$filepath};
($self->{mtime},$self->{included_mtimes},$self->{param_map},$self->{parse_stack})=@{$self->{record}}if defined($self->{record});
$options->{cache_debug} and defined($self->{record}) and print STDERR "### HTML::Template Cache Debug ### CACHE HIT : $filepath\n";
$self->_normalize_options(),$self->clear_params()
if(defined($self->{record}));
delete($self->{record});
return $self;
}sub _validate_shared_cache {
my ($self,$filename,$record)=@_;
my $options=$self->{options};
$options->{shared_cache_debug} and print STDERR "### HTML::Template Cache Debug ### SHARED CACHE VALIDATE : $filename\n";
return 1 if $options->{blind_cache};
my ($c_mtime,$included_mtimes,$param_map,$parse_stack)=@$record;
my $mtime=$self->_mtime($filename);
if(defined $mtime and defined $c_mtime
and $mtime != $c_mtime){$options->{cache_debug} and 
print STDERR "### HTML::Template Cache Debug ### SHARED CACHE MISS : $filename : $mtime\n";
return 0;
}if(defined $mtime and defined $included_mtimes){foreach my $fname (keys %$included_mtimes){next unless defined($included_mtimes->{$fname});
if($included_mtimes->{$fname} != (stat($fname))[9]){$options->{cache_debug} and 
print STDERR "### HTML::Template Cache Debug ### SHARED CACHE MISS : $filename : INCLUDE $fname\n";
return 0;
}}}return 1;
}sub _load_shared_cache {
my ($self,$filename)=@_;
my $options=$self->{options};
my $cache=$self->{cache};
$self->_init_template();
$self->_parse();
$options->{cache_debug} and print STDERR "### HTML::Template Cache Debug ### SHARED CACHE LOAD : $options->{filepath}\n";
print STDERR "### HTML::Template Memory Debug ### END CACHE LOAD ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
return [ $self->{mtime},$self->{included_mtimes},$self->{param_map},$self->{parse_stack} ]; 
}sub _find_file {
my ($self,$filename,$extra_path)=@_;
my $options=$self->{options};
my $filepath;
return File::Spec->canonpath($filename)
if(File::Spec->file_name_is_absolute($filename) and (-e $filename));
if(defined($extra_path)){$extra_path->[$#{$extra_path}]=$filename;
$filepath=File::Spec->canonpath(File::Spec->catfile(@$extra_path));
return File::Spec->canonpath($filepath) if -e $filepath;
}if(exists($ENV{HTML_TEMPLATE_ROOT}) and defined($ENV{HTML_TEMPLATE_ROOT})){$filepath=File::Spec->catfile($ENV{HTML_TEMPLATE_ROOT},$filename);
return File::Spec->canonpath($filepath) if -e $filepath;
}foreach my $path (@{$options->{path}}){$filepath=File::Spec->catfile($path,$filename);
return File::Spec->canonpath($filepath) if -e $filepath;
}return File::Spec->canonpath($filename) if -e $filename;
if(exists($ENV{HTML_TEMPLATE_ROOT})){foreach my $path (@{$options->{path}}){$filepath=File::Spec->catfile($ENV{HTML_TEMPLATE_ROOT},$path,$filename);
return File::Spec->canonpath($filepath) if -e $filepath;
}}return undef;
}sub _mtime {
my ($self,$filepath)=@_;
my $options=$self->{options};
return(undef) if($options->{blind_cache});
(-r $filepath) or Carp::confess("HTML::Template : template file $filepath does not exist or is unreadable.");
return (stat(_))[9];
}sub _normalize_options {
my $self=shift;
my $options=$self->{options};
my @pstacks=($self->{parse_stack});
while(@pstacks){my $pstack=pop(@pstacks);
foreach my $item (@$pstack){next unless (ref($item) eq 'HTML::Template::LOOP');
foreach my $template (values %{$item->[HTML::Template::LOOP::TEMPLATE_HASH]}){$template->{options}{debug}=$options->{debug};
$template->{options}{stack_debug}=$options->{stack_debug};
$template->{options}{die_on_bad_params}=$options->{die_on_bad_params};
$template->{options}{case_sensitive}=$options->{case_sensitive};
push(@pstacks,$template->{parse_stack});
}}}}      
sub _init_template {
my $self=shift;
my $options=$self->{options};
print STDERR "### HTML::Template Memory Debug ### START INIT_TEMPLATE ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
if(exists($options->{filename})) {    
my $filepath=$options->{filepath};
if(not defined $filepath){$filepath=$self->_find_file($options->{filename});
confess("HTML::Template->new() : Cannot open included file $options->{filename} : file not found.")
unless defined($filepath);
$options->{filepath}=$filepath;   
}confess("HTML::Template->new() : Cannot open included file $options->{filename} : $!")
unless defined(open(TEMPLATE,$filepath));
$self->{mtime}=$self->_mtime($filepath);
$self->{template}="";
while (read(TEMPLATE,$self->{template},10240,length($self->{template}))) {}close(TEMPLATE);
} elsif(exists($options->{scalarref})){$self->{template}=${$options->{scalarref}};
delete($options->{scalarref});
} elsif(exists($options->{arrayref})){$self->{template}=join("",@{$options->{arrayref}});
delete($options->{arrayref});
} elsif(exists($options->{filehandle})){local $/=undef;
$self->{template}=readline($options->{filehandle});
delete($options->{filehandle});
} else {
confess("HTML::Template : Need to call new with filename,filehandle,scalarref or arrayref parameter specified.");
}print STDERR "### HTML::Template Memory Debug ### END INIT_TEMPLATE ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
$self->_call_filters(\$self->{template}) if @{$options->{filter}};
return $self;
}sub _call_filters {
my $self=shift;
my $template_ref=shift;
my $options=$self->{options};
my ($format,$sub);
foreach my $filter (@{$options->{filter}}){croak("HTML::Template->new() : bad value set for filter parameter - must be a code ref or a hash ref.")
unless ref $filter;
$filter={ 'format' => 'scalar','sub' => $filter }if(ref $filter eq 'CODE');
if(ref $filter eq 'HASH'){$format=$filter->{'format'};
$sub=$filter->{'sub'};
croak("HTML::Template->new() : bad value set for filter parameter - hash must contain \"format\" key and \"sub\" key.")
unless defined $format and defined $sub;
croak("HTML::Template->new() : bad value set for filter parameter - \"format\" must be either 'array' or 'scalar'")
unless $format eq 'array' or $format eq 'scalar';
croak("HTML::Template->new() : bad value set for filter parameter - \"sub\" must be a code ref")
unless ref $sub and ref $sub eq 'CODE';
eval {
if($format eq 'scalar'){$sub->($template_ref);
} else {
my @array=map { $_."\n" } split("\n",$$template_ref);
$sub->(\@array);
$$template_ref=join("",@array);
}};
croak("HTML::Template->new() : fatal error occured during filter call: $@") if $@;
} else {
croak("HTML::Template->new() : bad value set for filter parameter - must be code ref or hash ref");
}}return $template_ref;
}sub _parse {
my $self=shift;
my $options=$self->{options};
$options->{debug} and print STDERR "### HTML::Template Debug ### In _parse:\n";
use vars qw(@pstack %pmap @ifstack @ucstack %top_pmap);
local (*pstack,*ifstack,*pmap,*ucstack,*top_pmap);
my @pstacks=([]);
*pstack=$pstacks[0];
$self->{parse_stack}=$pstacks[0];
my @pmaps=({});
*pmap=$pmaps[0];
*top_pmap=$pmaps[0];
$self->{param_map}=$pmaps[0];
my @ifstacks=([]);
*ifstack=$ifstacks[0];
my @ucstacks=([]);
*ucstack=$ucstacks[0];
my @loopstack=();
use vars qw($fcounter $fname $fmax);
local (*fcounter,*fname,*fmax);
my @fstack=([$options->{filepath} || "/fake/path/for/non/file/template",1,scalar @{[$self->{template} =~ m/(\n)/g]} + 1
]);
(*fname,*fcounter,*fmax)=\ ( @{$fstack[0]} );
my $NOOP=HTML::Template::NOOP->new();
my $ESCAPE=HTML::Template::ESCAPE->new();
my $JSESCAPE=HTML::Template::JSESCAPE->new();
my $URLESCAPE=HTML::Template::URLESCAPE->new();
my %need_names=map { $_ => 1 } 
qw(TMPL_VAR TMPL_LOOP TMPL_IF TMPL_UNLESS TMPL_INCLUDE);
my ($name,$which,$escape,$default);
$options->{vanguard_compatibility_mode} and 
$self->{template} =~ s/%([-\w\/\.+]+)%/<TMPL_VAR NAME=$1>/g;
my @chunks=split(m/(?=<)/,$self->{template});
delete $self->{template};
my $last_chunk=$#chunks;
CHUNK: for (my $chunk_number=0;
$chunk_number <= $last_chunk;
$chunk_number++){next unless defined $chunks[$chunk_number]; 
my $chunk=$chunks[$chunk_number];
if($chunk =~ /^<
(?:!--\s*)?
(
\/?[Tt][Mm][Pp][Ll]_
(?:
(?:[Vv][Aa][Rr])
|
(?:[Ll][Oo][Oo][Pp])
|
(?:[Ii][Ff])
|
(?:[Ee][Ll][Ss][Ee])
|
(?:[Uu][Nn][Ll][Ee][Ss][Ss])
|
(?:[Ii][Nn][Cc][Ll][Uu][Dd][Ee])
)
) # $1 => $which - start of the tag
\s* 
(?:
[Dd][Ee][Ff][Aa][Uu][Ll][Tt]
\s*=\s*
(?:
"([^">]*)"  # $2 => double-quoted DEFAULT value "
|
'([^'>]*)'  # $3 => single-quoted DEFAULT value
|
([^\s=>]*)  # $4 => unquoted DEFAULT value
)
)?
\s*
(?:
[Ee][Ss][Cc][Aa][Pp][Ee]
\s*=\s*
(?:
(?: 0 | (?:"0") | (?:'0') )
|
( 1 | (?:"1") | (?:'1') | 
(?:[Hh][Tt][Mm][Ll]) | 
(?:"[Hh][Tt][Mm][Ll]") |
(?:'[Hh][Tt][Mm][Ll]') |
(?:[Uu][Rr][Ll]) | 
(?:"[Uu][Rr][Ll]") |
(?:'[Uu][Rr][Ll]') |
(?:[Jj][Ss]) |
(?:"[Jj][Ss]") |
(?:'[Jj][Ss]') |
)                         # $5 => ESCAPE on
)
)* # allow multiple ESCAPEs
\s*
(?:
[Dd][Ee][Ff][Aa][Uu][Ll][Tt]
\s*=\s*
(?:
"([^">]*)"  # $6 => double-quoted DEFAULT value "
|
'([^'>]*)'  # $7 => single-quoted DEFAULT value
|
([^\s=>]*)  # $8 => unquoted DEFAULT value
)
)?
\s*                    
(?:
(?:
[Nn][Aa][Mm][Ee]
\s*=\s*
)?
(?:
"([^">]*)"  # $9 => double-quoted NAME value "
|
'([^'>]*)'  # $10 => single-quoted NAME value
|
([^\s=>]*)  # $11 => unquoted NAME value
)
)? 
\s*
(?:
[Dd][Ee][Ff][Aa][Uu][Ll][Tt]
\s*=\s*
(?:
"([^">]*)"  # $12 => double-quoted DEFAULT value "
|
'([^'>]*)'  # $13 => single-quoted DEFAULT value
|
([^\s=>]*)  # $14 => unquoted DEFAULT value
)
)?
\s*
(?:
[Ee][Ss][Cc][Aa][Pp][Ee]
\s*=\s*
(?:
(?: 0 | (?:"0") | (?:'0') )
|
( 1 | (?:"1") | (?:'1') | 
(?:[Hh][Tt][Mm][Ll]) | 
(?:"[Hh][Tt][Mm][Ll]") |
(?:'[Hh][Tt][Mm][Ll]') |
(?:[Uu][Rr][Ll]) | 
(?:"[Uu][Rr][Ll]") |
(?:'[Uu][Rr][Ll]') |
(?:[Jj][Ss]) |
(?:"[Jj][Ss]") |
(?:'[Jj][Ss]') |
)                         # $15 => ESCAPE on
)
)* # allow multiple ESCAPEs
\s*
(?:
[Dd][Ee][Ff][Aa][Uu][Ll][Tt]
\s*=\s*
(?:
"([^">]*)"  # $16 => double-quoted DEFAULT value "
|
'([^'>]*)'  # $17 => single-quoted DEFAULT value
|
([^\s=>]*)  # $18 => unquoted DEFAULT value
)
)?
\s*
(?:--)?>                    
(.*) # $19 => $post - text that comes after the tag
$/sx){$which=uc($1); # which tag is it
$escape=defined $5 ? $5 : defined $15 ? $15 : 0; # escape set?
$name=defined $9 ? $9 : defined $10 ? $10 : defined $11 ? $11 : undef;
$default=defined $2  ? $2  : defined $3  ? $3  : defined $4  ? $4 : 
defined $6  ? $6  : defined $7  ? $7  : defined $8  ? $8 : 
defined $12 ? $12 : defined $13 ? $13 : defined $14 ? $14 : 
defined $16 ? $16 : defined $17 ? $17 : defined $18 ? $18 :
undef;
my $post=$19; # what comes after on the line
$name=lc($name) unless (not defined $name or $which eq 'TMPL_INCLUDE' or $options->{case_sensitive});
die "HTML::Template->new() : No NAME given to a $which tag at $fname : line $fcounter." 
if($need_names{$which} and (not defined $name or not length $name));
die "HTML::Template->new() : ESCAPE option invalid in a $which tag at $fname : line $fcounter." if( $escape and ($which ne 'TMPL_VAR'));
die "HTML::Template->new() : DEFAULT option invalid in a $which tag at $fname : line $fcounter." if( defined $default and ($which ne 'TMPL_VAR'));
if($which eq 'TMPL_VAR'){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : parsed VAR $name\n";
my $var;        
if(exists $pmap{$name}){$var=$pmap{$name};
(ref($var) eq 'HTML::Template::VAR') or
die "HTML::Template->new() : Already used param name $name as a TMPL_LOOP,found in a TMPL_VAR at $fname : line $fcounter.";
} else {
$var=HTML::Template::VAR->new();
$pmap{$name}=$var;
$top_pmap{$name}=HTML::Template::VAR->new()
if $options->{global_vars} and not exists $top_pmap{$name};
}if(defined $default){push(@pstack,HTML::Template::DEFAULT->new($default));
}if($escape){if($escape =~ /^["']?[Uu][Rr][Ll]["']?$/){push(@pstack,$URLESCAPE);
} elsif($escape =~ /^"?[Jj][Ss]"?$/){push(@pstack,$JSESCAPE);
} else {
push(@pstack,$ESCAPE);
}}push(@pstack,$var);
} elsif($which eq 'TMPL_LOOP'){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : LOOP $name start\n";
my $loop;
if(exists $pmap{$name}){$loop=$pmap{$name};
(ref($loop) eq 'HTML::Template::LOOP') or
die "HTML::Template->new() : Already used param name $name as a TMPL_VAR,TMPL_IF or TMPL_UNLESS,found in a TMP_LOOP at $fname : line $fcounter!";
} else {
$loop=HTML::Template::LOOP->new();
$pmap{$name}=$loop;
}push(@pstack,$loop);
push(@loopstack,[$loop,$#pstack]);
push(@pstacks,[]);
*pstack=$pstacks[$#pstacks];
push(@pmaps,{});
*pmap=$pmaps[$#pmaps];
push(@ifstacks,[]);
*ifstack=$ifstacks[$#ifstacks];
push(@ucstacks,[]);
*ucstack=$ucstacks[$#ucstacks];
if($options->{loop_context_vars}){$pmap{__first__}=HTML::Template::VAR->new();
$pmap{__inner__}=HTML::Template::VAR->new();
$pmap{__last__}=HTML::Template::VAR->new();
$pmap{__odd__}=HTML::Template::VAR->new();
$pmap{__counter__}=HTML::Template::VAR->new();
}} elsif($which eq '/TMPL_LOOP'){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : LOOP end\n";
my $loopdata=pop(@loopstack);
die "HTML::Template->new() : found </TMPL_LOOP> with no matching <TMPL_LOOP> at $fname : line $fcounter!" unless defined $loopdata;
my ($loop,$starts_at)=@$loopdata;
foreach my $uc (@ucstack){my $var=$uc->[HTML::Template::COND::VARIABLE]; 
if(exists($pmap{$var})){$uc->[HTML::Template::COND::VARIABLE]=$pmap{$var};
} else {
$pmap{$var}=HTML::Template::VAR->new();
$top_pmap{$var}=HTML::Template::VAR->new()
if $options->{global_vars} and not exists $top_pmap{$var};
$uc->[HTML::Template::COND::VARIABLE]=$pmap{$var};
}if(ref($pmap{$var}) eq 'HTML::Template::VAR'){$uc->[HTML::Template::COND::VARIABLE_TYPE]=HTML::Template::COND::VARIABLE_TYPE_VAR;
} else {
$uc->[HTML::Template::COND::VARIABLE_TYPE]=HTML::Template::COND::VARIABLE_TYPE_LOOP;
}}my $param_map=pop(@pmaps);
*pmap=$pmaps[$#pmaps];
my $parse_stack=pop(@pstacks);
*pstack=$pstacks[$#pstacks];
scalar(@ifstack) and die "HTML::Template->new() : Dangling <TMPL_IF> or <TMPL_UNLESS> in loop ending at $fname : line $fcounter.";
pop(@ifstacks);
*ifstack=$ifstacks[$#ifstacks];
pop(@ucstacks);
*ucstack=$ucstacks[$#ucstacks];
$loop->[HTML::Template::LOOP::TEMPLATE_HASH]{$starts_at}             
= HTML::Template->_new_from_loop(
parse_stack => $parse_stack,param_map => $param_map,debug => $options->{debug},die_on_bad_params => $options->{die_on_bad_params},loop_context_vars => $options->{loop_context_vars},case_sensitive => $options->{case_sensitive},);
} elsif($which eq 'TMPL_IF' or $which eq 'TMPL_UNLESS' ){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : $which $name start\n";
my $var;        
if(exists $pmap{$name}){$var=$pmap{$name};
} else {
$var=$name;
}my $cond=HTML::Template::COND->new($var);
if($which eq 'TMPL_IF'){$cond->[HTML::Template::COND::WHICH]=HTML::Template::COND::WHICH_IF;
$cond->[HTML::Template::COND::JUMP_IF_TRUE]=0;
} else {
$cond->[HTML::Template::COND::WHICH]=HTML::Template::COND::WHICH_UNLESS;
$cond->[HTML::Template::COND::JUMP_IF_TRUE]=1;
}if($var eq $name){push(@ucstack,$cond);
} else {
if(ref($var) eq 'HTML::Template::VAR'){$cond->[HTML::Template::COND::VARIABLE_TYPE]=HTML::Template::COND::VARIABLE_TYPE_VAR;
} else {
$cond->[HTML::Template::COND::VARIABLE_TYPE]=HTML::Template::COND::VARIABLE_TYPE_LOOP;
}}push(@pstack,$cond);
push(@ifstack,$cond);
} elsif($which eq '/TMPL_IF' or $which eq '/TMPL_UNLESS'){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : $which end\n";
my $cond=pop(@ifstack);
die "HTML::Template->new() : found </${which}> with no matching <TMPL_IF> at $fname : line $fcounter." unless defined $cond;
if($which eq '/TMPL_IF'){die "HTML::Template->new() : found </TMPL_IF> incorrectly terminating a <TMPL_UNLESS> (use </TMPL_UNLESS>) at $fname : line $fcounter.\n" 
if($cond->[HTML::Template::COND::WHICH] == HTML::Template::COND::WHICH_UNLESS);
} else {
die "HTML::Template->new() : found </TMPL_UNLESS> incorrectly terminating a <TMPL_IF> (use </TMPL_IF>) at $fname : line $fcounter.\n" 
if($cond->[HTML::Template::COND::WHICH] == HTML::Template::COND::WHICH_IF);
}push(@pstack,$NOOP);
$cond->[HTML::Template::COND::JUMP_ADDRESS]=$#pstack;
} elsif($which eq 'TMPL_ELSE'){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : ELSE\n";
my $cond=pop(@ifstack);
die "HTML::Template->new() : found <TMPL_ELSE> with no matching <TMPL_IF> or <TMPL_UNLESS> at $fname : line $fcounter." unless defined $cond;
my $else=HTML::Template::COND->new($cond->[HTML::Template::COND::VARIABLE]);
$else->[HTML::Template::COND::WHICH]=$cond->[HTML::Template::COND::WHICH];
$else->[HTML::Template::COND::JUMP_IF_TRUE]=not $cond->[HTML::Template::COND::JUMP_IF_TRUE];
if(defined($cond->[HTML::Template::COND::VARIABLE_TYPE])){$else->[HTML::Template::COND::VARIABLE_TYPE]=$cond->[HTML::Template::COND::VARIABLE_TYPE];
} else {
push(@ucstack,$else);
}push(@pstack,$else);
push(@ifstack,$else);
$cond->[HTML::Template::COND::JUMP_ADDRESS]=$#pstack;
} elsif($which eq 'TMPL_INCLUDE'){$options->{debug} and print STDERR "### HTML::Template Debug ### $fname : line $fcounter : INCLUDE $name \n";
$options->{no_includes} and croak("HTML::Template : Illegal attempt to use TMPL_INCLUDE in template file : (no_includes => 1)");
my $filename=$name;
my $filepath;
if($options->{search_path_on_include}){$filepath=$self->_find_file($filename);
} else {
$filepath=$self->_find_file($filename,[File::Spec->splitdir($fstack[-1][0])]
);
}die "HTML::Template->new() : Cannot open included file $filename : file not found."
unless defined($filepath);
die "HTML::Template->new() : Cannot open included file $filename : $!"
unless defined(open(TEMPLATE,$filepath));              
my $included_template="";
while(read(TEMPLATE,$included_template,10240,length($included_template))) {}close(TEMPLATE);
$self->_call_filters(\$included_template) if @{$options->{filter}};
if($included_template) { # not empty
$options->{vanguard_compatibility_mode} and 
$included_template =~ s/%([-\w\/\.+]+)%/<TMPL_VAR NAME=$1>/g;
if($options->{cache} and !$options->{blind_cache}){$self->{included_mtimes}{$filepath}=(stat($filepath))[9];
}push(@fstack,[$filepath,1,scalar @{[$included_template =~ m/(\n)/g]} + 1]);
(*fname,*fcounter,*fmax)=\ ( @{$fstack[$#fstack]} );
die "HTML::Template->new() : likely recursive includes - parsed $options->{max_includes} files deep and giving up (set max_includes higher to allow deeper recursion)." if($options->{max_includes} and (scalar(@fstack) > $options->{max_includes}));
$included_template .= $post;
$post=undef;
splice(@chunks,$chunk_number,1,split(m/(?=<)/,$included_template));
$last_chunk=$#chunks;
$chunk=$chunks[$chunk_number];
redo CHUNK;
}} else {
die "HTML::Template->new() : Unknown or unmatched TMPL construct at $fname : line $fcounter.";
}if(defined($post)){if(ref($pstack[$#pstack]) eq 'SCALAR'){${$pstack[$#pstack]} .= $post;
} else {
push(@pstack,\$post);
}}} else { # just your ordinary markup
if($options->{strict}){die "HTML::Template->new() : Syntax error in <TMPL_*> tag at $fname : $fcounter." if($chunk =~ /<(?:!--\s*)?\/?[Tt][Mm][Pp][Ll]_/);
}if(defined($chunk)){if(ref($pstack[$#pstack]) eq 'SCALAR'){${$pstack[$#pstack]} .= $chunk;
} else {
push(@pstack,\$chunk);
}}}$fcounter += scalar(@{[$chunk =~ m/(\n)/g]});
pop(@fstack),(*fname,*fcounter,*fmax)=\ ( @{$fstack[$#fstack]} )
if($fcounter > $fmax);
} # next CHUNK
scalar(@ifstack) and die "HTML::Template->new() : At least one <TMPL_IF> or <TMPL_UNLESS> not terminated at end of file!";
scalar(@loopstack) and die "HTML::Template->new() : At least one <TMPL_LOOP> not terminated at end of file!";
foreach my $uc (@ucstack){my $var=$uc->[HTML::Template::COND::VARIABLE]; 
if(exists($pmap{$var})){$uc->[HTML::Template::COND::VARIABLE]=$pmap{$var};
} else {
$pmap{$var}=HTML::Template::VAR->new();
$top_pmap{$var}=HTML::Template::VAR->new()
if $options->{global_vars} and not exists $top_pmap{$var};
$uc->[HTML::Template::COND::VARIABLE]=$pmap{$var};
}if(ref($pmap{$var}) eq 'HTML::Template::VAR'){$uc->[HTML::Template::COND::VARIABLE_TYPE]=HTML::Template::COND::VARIABLE_TYPE_VAR;
} else {
$uc->[HTML::Template::COND::VARIABLE_TYPE]=HTML::Template::COND::VARIABLE_TYPE_LOOP;
}}if($options->{stack_debug}){require 'Data/Dumper.pm';
print STDERR "### HTML::Template _param Stack Dump ###\n\n",Data::Dumper::Dumper($self->{parse_stack}),"\n";
}delete $options->{filter};
}sub _globalize_vars {
my $self=shift;
push(@{$self->{options}{associate}},@_);
push(@_,$self);
map { $_->_globalize_vars(@_) } 
map {values %{$_->[HTML::Template::LOOP::TEMPLATE_HASH]}}grep { ref($_) eq 'HTML::Template::LOOP'} @{$self->{parse_stack}};
}sub _unglobalize_vars {
my $self=shift;
$self->{options}{associate}=undef;
map { $_->_unglobalize_vars() } 
map {values %{$_->[HTML::Template::LOOP::TEMPLATE_HASH]}}grep { ref($_) eq 'HTML::Template::LOOP'} @{$self->{parse_stack}};
}sub param {
my $self=shift;
my $options=$self->{options};
my $param_map=$self->{param_map};
return keys(%$param_map) unless scalar(@_);
my $first=shift;
my $type=ref $first;
if(!scalar(@_) and !length($type)){my $param=$options->{case_sensitive} ? $first : lc $first;
$options->{die_on_bad_params} and !exists($param_map->{$param}) and
croak("HTML::Template : Attempt to get nonexistent parameter '$param' - this parameter name doesn't match any declarations in the template file : (die_on_bad_params set => 1)");
return undef unless (exists($param_map->{$param}) and
defined($param_map->{$param}));
return ${$param_map->{$param}} if 
(ref($param_map->{$param}) eq 'HTML::Template::VAR');
return $param_map->{$param}[HTML::Template::LOOP::PARAM_SET];
} 
if(!scalar(@_)){croak("HTML::Template->param() : Single reference arg to param() must be a hash-ref!  You gave me a $type.")
unless $type eq 'HASH' or 
(ref($first) and UNIVERSAL::isa($first,'HASH'));  
push(@_,%$first);
} else {
unshift(@_,$first);
}croak("HTML::Template->param() : You gave me an odd number of parameters to param()!")
unless ((@_ % 2) == 0);
for (my $x=0; $x <= $#_; $x += 2){my $param=$options->{case_sensitive} ? $_[$x] : lc $_[$x];
my $value=$_[($x + 1)];
$options->{die_on_bad_params} and !exists($param_map->{$param}) and
croak("HTML::Template : Attempt to set nonexistent parameter '$param' - this parameter name doesn't match any declarations in the template file : (die_on_bad_params => 1)");
next unless (exists($param_map->{$param}));
my $value_type=ref($value);
if(defined($value_type) and length($value_type) and ($value_type eq 'ARRAY' or ((ref($value) !~ /^(CODE)|(HASH)|(SCALAR)$/) and $value->isa('ARRAY')))){(ref($param_map->{$param}) eq 'HTML::Template::LOOP') or
croak("HTML::Template::param() : attempt to set parameter '$param' with an array ref - parameter is not a TMPL_LOOP!");
$param_map->{$param}[HTML::Template::LOOP::PARAM_SET]=[@{$value}];
} else {
(ref($param_map->{$param}) eq 'HTML::Template::VAR') or
croak("HTML::Template::param() : attempt to set parameter '$param' with a scalar - parameter is not a TMPL_VAR!");
${$param_map->{$param}}=$value;
}}}sub clear_params {
my $self=shift;
my $type;
foreach my $name (keys %{$self->{param_map}}){$type=ref($self->{param_map}{$name});
undef(${$self->{param_map}{$name}})
if($type eq 'HTML::Template::VAR');
undef($self->{param_map}{$name}[HTML::Template::LOOP::PARAM_SET])
if($type eq 'HTML::Template::LOOP');    
}}sub associateCGI { 
my $self=shift;
my $cgi=shift;
(ref($cgi) eq 'CGI') or
croak("Warning! non-CGI object was passed to HTML::Template::associateCGI()!\n");
push(@{$self->{options}{associate}},$cgi);
return 1;
}use vars qw(%URLESCAPE_MAP);
sub output {
my $self=shift;
my $options=$self->{options};
local $_;
croak("HTML::Template->output() : You gave me an odd number of parameters to output()!")
unless ((@_ % 2) == 0);
my %args=@_;
print STDERR "### HTML::Template Memory Debug ### START OUTPUT ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
$options->{debug} and print STDERR "### HTML::Template Debug ### In output\n";
if($options->{stack_debug}){require 'Data/Dumper.pm';
print STDERR "### HTML::Template output Stack Dump ###\n\n",Data::Dumper::Dumper($self->{parse_stack}),"\n";
}$self->_globalize_vars() if($options->{global_vars});
if(scalar(@{$options->{associate}})){my (%case_map,$lparam);
foreach my $associated_object (@{$options->{associate}}){if($options->{case_sensitive}){map {
$case_map{$associated_object}{$_}=$_
} $associated_object->param();
} else {
map {
$case_map{$associated_object}{lc($_)}=$_
} $associated_object->param();
}}foreach my $param (keys %{$self->{param_map}}){unless (defined($self->param($param))){OBJ: foreach my $associated_object (reverse @{$options->{associate}}){$self->param($param,scalar $associated_object->param($case_map{$associated_object}{$param})),last OBJ
if(exists($case_map{$associated_object}{$param}));
}}}}use vars qw($line @parse_stack); local(*line,*parse_stack);
*parse_stack=$self->{parse_stack};
my $result='';
tie $result,'HTML::Template::PRINTSCALAR',$args{print_to}if defined $args{print_to} and not tied $args{print_to};
my $type;
my $parse_stack_length=$#parse_stack;
for (my $x=0; $x <= $parse_stack_length; $x++){*line=\$parse_stack[$x];
$type=ref($line);
if($type eq 'SCALAR'){$result .= $$line;
} elsif($type eq 'HTML::Template::VAR' and ref($$line) eq 'CODE'){defined($$line) and $result .= $$line->($self);
} elsif($type eq 'HTML::Template::VAR'){defined($$line) and $result .= $$line;
} elsif($type eq 'HTML::Template::LOOP'){if(defined($line->[HTML::Template::LOOP::PARAM_SET])){eval { $result .= $line->output($x,$options->{loop_context_vars}); };
croak("HTML::Template->output() : fatal error in loop output : $@") 
if $@;
}} elsif($type eq 'HTML::Template::COND'){if($line->[HTML::Template::COND::JUMP_IF_TRUE]){if($line->[HTML::Template::COND::VARIABLE_TYPE] == HTML::Template::COND::VARIABLE_TYPE_VAR){if(defined ${$line->[HTML::Template::COND::VARIABLE]}){if (ref(${$line->[HTML::Template::COND::VARIABLE]}) eq 'CODE'){$x=$line->[HTML::Template::COND::JUMP_ADDRESS] if ${$line->[HTML::Template::COND::VARIABLE]}->($self);
} else {
$x=$line->[HTML::Template::COND::JUMP_ADDRESS] if ${$line->[HTML::Template::COND::VARIABLE]};
}}} else {
$x=$line->[HTML::Template::COND::JUMP_ADDRESS] if
(defined $line->[HTML::Template::COND::VARIABLE][HTML::Template::LOOP::PARAM_SET] and
scalar @{$line->[HTML::Template::COND::VARIABLE][HTML::Template::LOOP::PARAM_SET]});
}} else {
if($line->[HTML::Template::COND::VARIABLE_TYPE] == HTML::Template::COND::VARIABLE_TYPE_VAR){if(defined ${$line->[HTML::Template::COND::VARIABLE]}){if(ref(${$line->[HTML::Template::COND::VARIABLE]}) eq 'CODE'){$x=$line->[HTML::Template::COND::JUMP_ADDRESS] unless ${$line->[HTML::Template::COND::VARIABLE]}->($self);
} else {
$x=$line->[HTML::Template::COND::JUMP_ADDRESS] unless ${$line->[HTML::Template::COND::VARIABLE]};
}} else {
$x=$line->[HTML::Template::COND::JUMP_ADDRESS];
}} else {
$x=$line->[HTML::Template::COND::JUMP_ADDRESS] if
(not defined $line->[HTML::Template::COND::VARIABLE][HTML::Template::LOOP::PARAM_SET] or
not scalar @{$line->[HTML::Template::COND::VARIABLE][HTML::Template::LOOP::PARAM_SET]});
}}} elsif($type eq 'HTML::Template::NOOP'){next;
} elsif($type eq 'HTML::Template::DEFAULT'){$_=$x;  # remember default place in stack
*line=\$parse_stack[++$x];
*line=\$parse_stack[++$x] if ref $line eq 'HTML::Template::ESCAPE';
if(defined $$line){$x=$_;
} else {
$result .= ${$parse_stack[$_]};
}next;      
} elsif($type eq 'HTML::Template::ESCAPE'){*line=\$parse_stack[++$x];
if(defined($$line)){$_=$$line;
s/&/&amp;/g;
s/\"/&quot;/g; #"
s/>/&gt;/g;
s/</&lt;/g;
s/'/&#39;/g; #'
$result .= $_;
}next;
} elsif($type eq 'HTML::Template::JSESCAPE'){$x++;
*line=\$parse_stack[$x];
if(defined($$line)){$_=$$line;
s/\\/\\\\/g;
s/'/\\'/g;
s/"/\\"/g;
s/\n/\\n/g;
s/\r/\\r/g;
$result .= $_;
}} elsif($type eq 'HTML::Template::URLESCAPE'){$x++;
*line=\$parse_stack[$x];
if(defined($$line)){$_=$$line;
unless (exists($URLESCAPE_MAP{chr(1)})){for (0..255) { $URLESCAPE_MAP{chr($_)}=sprintf('%%%02X',$_); }}s!([^a-zA-Z0-9_.\-])!$URLESCAPE_MAP{$1}!g;
$result .= $_;
}} else {
confess("HTML::Template::output() : Unknown item in parse_stack : " . $type);
}}$self->_unglobalize_vars() if($options->{global_vars});
print STDERR "### HTML::Template Memory Debug ### END OUTPUT ",$self->{proc_mem}->size(),"\n"
if $options->{memory_debug};
return undef if defined $args{print_to};
return $result;
}sub query {
my $self=shift;
$self->{options}{debug} and print STDERR "### HTML::Template Debug ### query(",join(',',@_),")\n";
return $self->param() unless scalar(@_);
croak("HTML::Template::query() : Odd number of parameters passed to query!")
if(scalar(@_) % 2);
croak("HTML::Template::query() : Wrong number of parameters passed to query - should be 2.")
if(scalar(@_) != 2);
my ($opt,$path)=(lc shift,shift);
croak("HTML::Template::query() : invalid parameter ($opt)")
unless ($opt eq 'name' or $opt eq 'loop');
$path=[$path] unless (ref $path);
my @objs=$self->_find_param(@$path);
return undef unless scalar(@objs);
my ($obj,$type);
if($opt eq 'name'){($obj,$type)=(shift(@objs),shift(@objs));
return undef unless defined $obj;
return 'VAR' if $type eq 'HTML::Template::VAR';
return 'LOOP' if $type eq 'HTML::Template::LOOP';
croak("HTML::Template::query() : unknown object ($type) in param_map!");
} elsif($opt eq 'loop'){my %results;
while(@objs){($obj,$type)=(shift(@objs),shift(@objs));
croak("HTML::Template::query() : Search path [",join(',',@$path),"] doesn't end in a TMPL_LOOP - it is an error to use the 'loop' option on a non-loop parameter.  To avoid this problem you can use the 'name' option to query() to check the type first.") 
unless ((defined $obj) and ($type eq 'HTML::Template::LOOP'));
map {$results{$_}=1} map { keys(%{$_->{'param_map'}}) }values(%{$obj->[HTML::Template::LOOP::TEMPLATE_HASH]});
}return keys(%results);   
}}sub _find_param {
my $self=shift;
my $spot=$self->{options}{case_sensitive} ? shift : lc shift;
my $obj=$self->{'param_map'}{$spot};
return unless defined $obj;
my $type=ref $obj;
return ($obj,$type) unless @_;
return unless ($type eq 'HTML::Template::LOOP');
return map { $_->_find_param(@_) }values(%{$obj->[HTML::Template::LOOP::TEMPLATE_HASH]});
}package HTML::Template::VAR;
sub new {
my $value;
return bless(\$value,$_[0]);
}package HTML::Template::DEFAULT;
sub new {
my $value=$_[1];
return bless(\$value,$_[0]);
}package HTML::Template::LOOP;
sub new {
return bless([],$_[0]);
}sub output {
my $self=shift;
my $index=shift;
my $loop_context_vars=shift;
my $template=$self->[TEMPLATE_HASH]{$index};
my $value_sets_array=$self->[PARAM_SET];
return unless defined($value_sets_array);  
my $result='';
my $count=0;
my $odd=0;
foreach my $value_set (@$value_sets_array){if($loop_context_vars){if($count == 0){@{$value_set}{qw(__first__ __inner__ __last__)}=(1,0,$#{$value_sets_array} == 0);
} elsif($count == $#{$value_sets_array}){@{$value_set}{qw(__first__ __inner__ __last__)}=(0,0,1);
} else {
@{$value_set}{qw(__first__ __inner__ __last__)}=(0,1,0);
}$odd=$value_set->{__odd__}=not $odd;
$value_set->{__counter__}=$count + 1;
}$template->param($value_set);    
$result .= $template->output;
$template->clear_params;
@{$value_set}{qw(__first__ __last__ __inner__ __odd__ __counter__)}=(0,0,0,0)
if($loop_context_vars);
$count++;
}return $result;
}package HTML::Template::COND;
sub new {
my $pkg=shift;
my $var=shift;
my $self=[];
$self->[VARIABLE]=$var;
bless($self,$pkg);  
return $self;
}package HTML::Template::NOOP;
sub new {
my $unused;
my $self=\$unused;
bless($self,$_[0]);
return $self;
}package HTML::Template::ESCAPE;
sub new {
my $unused;
my $self=\$unused;
bless($self,$_[0]);
return $self;
}package HTML::Template::JSESCAPE;
sub new {
my $unused;
my $self=\$unused;
bless($self,$_[0]);
return $self;
}package HTML::Template::URLESCAPE;
sub new {
my $unused;
my $self=\$unused;
bless($self,$_[0]);
return $self;
}package HTML::Template::PRINTSCALAR;
use strict;
sub TIESCALAR { bless \$_[1],$_[0]; }sub FETCH { }sub STORE {
my $self=shift;
local *FH=$$self;
print FH @_;
}1;
