packer_wrapper.pl
=================

### What is it

`packer_wrapper.pl` is a simple perl script to help with templating packer builds. This version has been developed with chef as the provisioner, but should work with other provisioners. It generates environment variables which are sourced and fed in to a json template which packer uses.

The template is parsed as an argument - so theoretically it should be able to do anything that packer is able to, although modification of the script might be necessary (the script currently supports and has been tested against the chef provisioner, using both roles and environments and chef policy files).

### What is does

`packer_wrapper.pl` takes a list of arguments - and combines the users environment - a file called `projects.vars` (containing variables about the current project such as the assume role etc..).

It creates a key pair on AWS if not available locally, combines environment variables and runs a packer build with a defined template, to build an AMI.




### Using it

Execute it on the command line with arguments, e.g.

`./packer_wrapper.pl  --session keypair-name -r base`

It takes quite a few arguments, some of these have defaults set, but would probably have to be overridden for your project.

The arguments are as follows:

```
-s, --session             aws-key-pair to create   (mandatory)
-r, --resource            chef role or policy name (mandatory)
-i, --image               aws-image (base image to build from)
-t, --type                aws instance type
-v, --volume              size of EBS volume (in gigabytes)
-E, --environment         chef environment or policy group
-a, --attribute-json      reserved for future use (maybe injecting additional json into template)
-vpcid, --vpcid           AWS vpc (id) in which packer builds AMI
-subnetid, --subnetid     AWS subnet (id) in which packer builds AMI
-j, --json-file           path to packer json file used to create the build
```

e.g.

```
/packer_wrapper.pl --session 'new-ssh-keypair' --vpcid vpc-66b9af02 --subnetid subnet-9f7b21c7 \
-E staging -r facade -j packer-chef-policy.json --image ami-495c612f
```

** Hint **
if you have a .chef directory in the root directory of the repo with a knife.rb file your life will become much simpler. And you *should* be able to use it all the way down the directory tree.

*cat .chef/knife.rb*
```
current_dir = File.dirname(__FILE__)

user = ENV['OPSCODE_USER'] || ENV['USER']
node_name                user
client_key               "#{ENV['HOME']}/.chef/#{user}.pem"
secret_file              "#{ENV['HOME']}/.chef/js_identity_encrypted_data_bag_secret"
syntax_check_cache_path  "#{ENV['HOME']}/.chef/syntax_check_cache"
chef_server_url          "https://api.chef.io/organizations/js-identity"
cookbook_path            ["#{current_dir}/../cookbooks", "#{current_dir}/../site-cookbooks"]
cookbook_copyright       "JSainsburyPLC"
cookbook_license         "apachev2"
cookbook_email           ENV['EMAIL_ADDRESS']

# Amazon AWS
knife[:aws_access_key_id]     = ENV['AWS_ACCESS_KEY_ID']
knife[:aws_secret_access_key] = ENV['AWS_SECRET_ACCESS_KEY']
knife[:aws_ssh_key_id]        = ENV['AWS_SSH_KEY_ID']

# Knife SSH settings
knife[:ssh_user]              = ENV['SSH_USER']
knife[:identity_file]         = "#{ENV['HOME']}/.ssh/#{ENV['SSH_KEY']}"

knife[:ssh_attribute]         = 'cloud.local_ipv4'
knife[:ssh_timeout]           = 10

Dir["#{ENV['HOME']}/.chef/knife.d/*.rb"].each {|file| require file }
```

As said earlier, the script also relies upon a file called `project.vars`, here is a example file:
*cat project.vars*
```
export AWS_SESSION_TOKEN=$AWS_SECURITY_TOKEN
export CHEFORG="js-identity"
export PROJECT_IAM_ROLE="arn:aws:iam::AWS_ACCOUNT_NUMBER:role/js_roles_js_identity_partial"
export CHEF_VALIDATION_CLIENT_NAME="js-identity-validator"
export CHEF_SECRET_KEY="~/.chef/encrypted_data_bag_secret"
export CHEF_VALIDATION_KEY="~/.chef/js-identity-validator.pem"
export CHEF_SERVER_URL="https://api.chef.io/organizations/js-identity"
export CHEF_ENCRYPTED_DATA_BAG_FILE_NAME="js_identity_encrypted_data_bag_secret"
export ORG=$CHEFORG
export ORGNAME=$CHEFORG
export ACCESS_KEY=$AWS_ACCESS_KEY_ID
export SECRET_KEY=$AWS_SECRET_ACCESS_KEY
```

**Please replace AWS_ACCOUNT_NUMBER with the account number for the project and likewise the IAM role**

Finally here is an example template for using chef policy files:
[packer-chef-policy.json](packer-chef-policy.json)

And an example template for using chef roles / environments:
[packer-chef-role.json](packer-chef-role.json)



### To Do

Maybe re-write it in a different language which is more popular, which retains exactly the same functionality (including, switches etc..), both scripts should be consistent with each other.
