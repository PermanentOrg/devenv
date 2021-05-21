#to UNIX EOL
# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "generic/debian10"
  config.vm.box_version = "3.1.10"
  config.vm.define "permanent"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  config.vm.box_check_update = true 

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.33.10"
  config.vm.network "forwarded_port", guest: 9000, host: 9000
  config.vm.network "forwarded_port", guest: 3000, host: 3000

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder "../back-end/api", "/data/www/api", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../back-end", "/data/www/back-end", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../docker", "/data/www/docker", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../back-end/daemon", "/data/www/daemon", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../back-end/library", "/data/www/library", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../back-end/task-runner", "/data/www/task-runner", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../website", "/data/www/website", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../log", "/var/log/permanent", owner: "vagrant", group: "www-data", mount_options: ["dmode=770", "fmode=660"]
  config.vm.synced_folder "../web-app/dist", "/data/www/mdot/dist", owner: "vagrant", group: "www-data"
  config.vm.synced_folder "../upload-service", "/data/www/upload-service", owner: "vagrant", group: "www-data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.memory = "2048"
    vb.cpus = 2
    vb.linked_clone = true
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "file", source: "../infrastructure/templates", destination: "/tmp/templates"
  config.vm.provision "shell", path: "../infrastructure/provisioners/configure.sh",
    env: {"AWS_ACCESS_KEY_ID": ENV["AWS_ACCESS_KEY_ID"],
          "AWS_ACCESS_SECRET": ENV["AWS_ACCESS_SECRET"],
          "AWS_REGION": ENV["AWS_REGION"],
          "UPLOAD_SERVICE_SENTRY_DSN": ENV["UPLOAD_SERVICE_SENTRY_DSN"],
          "PERM_ENV": "local",
          "PERM_SUBDOMAIN": "local",
          "APP_USER": "vagrant",
          "TEMPLATES_PATH": "/tmp/templates"}
  config.vm.provision "shell", path: "bin/deploy.sh",
    env: {"SQS_IDENT": ENV["SQS_IDENT"],
          "DELETE_DATA": ENV["DELETE_DATA"]}
  config.vm.provision "shell", inline: "sudo systemctl daemon-reload", run: "always"
  config.vm.provision "shell", inline: "sudo service apache2 restart", run: "always"
  config.vm.provision "shell", inline: "sudo service mysql restart", run: "always"
  config.vm.provision "shell", inline: "sudo service queue-daemon restart", run: "always"
  config.vm.provision "shell", inline: "sudo service process-daemon restart", run: "always"
  config.vm.provision "shell", inline: "sudo service sqs-daemon restart", run: "always"
  config.vm.provision "shell", inline: "sudo service video-daemon restart", run: "always"
  config.vm.provision "shell", inline: "sudo service upload restart", run: "always"
  config.vm.post_up_message = "Finished! App running at https://local.permanent.org/"
end
