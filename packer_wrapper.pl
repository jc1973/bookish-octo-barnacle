#!/usr/bin/env perl

use strict;
use warnings;

my ( $AWS_ACCESS_KEY_ID, $SECRETACCESSKEY, $SESSIONTOKEN, $arn, $cmd, $line, @contents, @output, $resource, $session_name, $vpc_id, $subnet_id );
my $KEYMATERIAL = "";
my $type = "t2.small";
my $image = "ami-47a23a30";
my $volume_size = 8;
my $chef_environment = "_default";
my $packer_json =  "packer-chef-client.json";
my $exit_status = 0;
my $attr_json = "";


while ( my $input = shift (@ARGV) ) {
  chomp $input;
  if ( $input =~ /-s$|--session$/ ) {
    $session_name = shift (@ARGV);
  }
  if ( $input =~ /-r$|--resource$/ ) {
    $resource = shift (@ARGV);
  }
  if ( $input =~ /-i$|--image$/ ) {
    $image = shift (@ARGV);
  }
  if ( $input =~ /-t$|--type$/ ) {
    $type = shift (@ARGV);
  }
  if ( $input =~ /-v$|--volume$/ ) {
    $volume_size = shift (@ARGV);
  }
  if ( $input =~ /-E$|--environment$/ ) {
    $chef_environment = shift (@ARGV);
  }
  if ( $input =~ /-a$|--attribute-json$/ ) {
    $attr_json = shift (@ARGV);
  }
  if ( $input =~ /-vpcid$|--vpcid$/ ) {
    $vpc_id = shift (@ARGV);
  }
  if ( $input =~ /-subnetid$|--subnetid$/ ) {
    $subnet_id = shift (@ARGV);
  }
  if ( $input =~ /-j$|--json-file$/ ) {
    $packer_json = shift (@ARGV);
    $packer_json = "packer-chef-client.json" unless ( -f $packer_json ) ;
  }
  if ( $input =~ /-h$|--help$/ ) {
    usage();
  }
}

usage() unless ( $session_name && $resource );

my $keyname = $ENV{'USER'};
$keyname =~ s/\./-/g;
open (READFILE,"project.vars") or die "Cannot open file project.vars $!\n";
@contents = <READFILE>;
close READFILE;
foreach (@contents) {
  if ( /(arn:aws:iam::\S+)"/ ) {
    $arn = $1;
  }
}

$cmd = "/usr/local/bin/aws sts assume-role --role-arn $arn --role-session-name 'RoleSession$session_name'";

if ( $ENV{'AWS_ACCESS_KEY_ID'} || $ENV{'AWS_SECRET_ACCESS_KEY'} || $ENV{'AWS_SECURITY_TOKEN'} ) {
  $AWS_ACCESS_KEY_ID = $ENV{'AWS_ACCESS_KEY_ID'};
  $SECRETACCESSKEY = $ENV{'AWS_SECRET_ACCESS_KEY'};
  $SESSIONTOKEN = $ENV{'AWS_SECURITY_TOKEN'};
} else {
  @output = `$cmd`;
  foreach $line(@output) {
    chomp $line;
    if ( $line =~ /.+AccessKeyId": "(\S+)".*/ ) {
        $AWS_ACCESS_KEY_ID = $1;
      }
    if ( $line =~ /.+SecretAccessKey": "(\S+)".*/ ) {
        $SECRETACCESSKEY = $1;
      }
    if ( $line =~ /.+SessionToken": "(\S+)".*/ ) {
        $SESSIONTOKEN = $1;
      }
  }
}

open (WRITEFILE,">/tmp/$session_name-$keyname.source") or die "Cannot write to file /tmp/$session_name-$keyname.source $!\n";
print WRITEFILE "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID\n";
print WRITEFILE "export AWS_SECRET_ACCESS_KEY=$SECRETACCESSKEY\n";
print WRITEFILE "export AWS_SECURITY_TOKEN=$SESSIONTOKEN\n";
print WRITEFILE "export PACKER_PROJECT_SSH_KEY=$ENV{'HOME'}/packer-aws/$session_name-$keyname\n";
print WRITEFILE "export AMI_TYPE=$type\n";
print WRITEFILE "export AMI_IMAGE=$image\n";
print WRITEFILE "export ATTR_JSON=$attr_json\n";
print WRITEFILE "export AMI_DISK_SIZE=$volume_size\n";
#print WRITEFILE "export RESOURCE=$resource\n";
#print WRITEFILE "export CHEF_ENVIRONMENT=$chef_environment\n";
print WRITEFILE "export VPC_ID=$vpc_id\n";
print WRITEFILE "export SUBNET_ID=$subnet_id\n";
print WRITEFILE @contents;
close WRITEFILE;

print "Created environment variable files to source: /tmp/$session_name-$keyname.source\n";

print "Creating directory: $ENV{'HOME'}/packer-aws\n" unless ( -d "$ENV{'HOME'}/packer-aws" ) ;
mkdir "$ENV{'HOME'}/packer-aws" unless ( -d "$ENV{'HOME'}/packer-aws" );
print "Creating key-pair: $ENV{'HOME'}/packer-aws/$session_name-$keyname\n" unless ( -f "$ENV{'HOME'}/packer-aws/$session_name-$keyname" );
unless ( -f "$ENV{'HOME'}/packer-aws/$session_name-$keyname" ) {
  $cmd = ". /tmp/$session_name-$keyname.source && /usr/local/bin/aws ec2 create-key-pair --key-name $session_name-$keyname";
  @output = `$cmd`;
  foreach $line(@output) {
    chomp $line;
    if ( $line =~ /.*KeyMaterial": "(.+)".*/ ) {
      $KEYMATERIAL = $1;
    }
  }
  $KEYMATERIAL =~s/\\n/\n/g;
  open (WRITEFILE,">$ENV{'HOME'}/packer-aws/$session_name-$keyname");
  print WRITEFILE $KEYMATERIAL;
  close WRITEFILE;
  chmod 0600, "$ENV{'HOME'}/packer-aws/$session_name-$keyname";
  `touch $ENV{'HOME'}/packer-aws/$session_name-$keyname.pub`;
}

#$cmd = ". /tmp/$session_name-$keyname.source";



print "\nCreate environment variables to source: $cmd\n\n";

# Using policy files not roles and environments
# # Check that we have only 1 chef role
# 
# $cmd = "knife role list | grep '^$resource\$'";
# @output = `$cmd`;
# if ( scalar(@output) != 1 ) {
#   print "Role $resource, does not exist on chef server.\n";
#   exit 1;
# }
# if ( scalar(@output) > 1 ) {
#   print "\nMaybe you wanted one of these:\n @output\n";
#   exit 1;
# }
# 
$cmd = ". /tmp/$session_name-$keyname.source && packer build $packer_json";

print "\nNow running packer build command: packer build $packer_json\n\n";

print "\n\n$cmd\n\n";

@output = `$cmd`;
$exit_status = $? >> 8;
print @output;
#open (WRITEFILE, ">>/tmp/packer-debug.txt");
#print WRITEFILE @output;
#close WRITEFILE;
print "\n\n";
print "Exit status: $exit_status\n\n";

if ( $exit_status == 0 ) {
  my $packer_ami_id = $output[-1];
  $packer_ami_id =~s/\S+:\s+(\S+)/$1/;
  $cmd = "knife environment attribute set $chef_environment pre-built-amis.$resource $packer_ami_id";
  print $cmd;
  @output = `$cmd`;
  $exit_status = $? >> 8;
  print @output;
  print "\n\n";
}
exit $exit_status;


sub usage {
  print "$0 -s,--session 'AWS session name' -r,--resource 'resource/role' [ -t,--type 'AMI instance type'  -i,--image 'AMI image base' -v,--volume 'AMI volume size' -E,--environment 'chef environment' ] || -h (--help) \n";
  print "eg.\n $0 -s aws-`date +%F` -r bastion [ -i ami-47a23a30 --type t2.small --volume 20 -E integration ]\n";
  exit 0;
}
