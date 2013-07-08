# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # https://github.com/terrywang/vagrantboxes/blob/master/oracle64.md
  config.vm.box = "oracle64"
  config.vm.box_url = "https://dl.dropbox.com/s/zmitpteca72sjpx/oracle64.box"

  config.cache.auto_detect = true

  config.vm.network :forwarded_port, guest:   80, host: 8080
  config.vm.network :forwarded_port, guest: 1158, host: 1158
  config.vm.network :forwarded_port, guest: 1521, host: 1521

  # config.vm.synced_folder "../data", "/vagrant_data"

  config.vm.provider "virtualbox" do |vb|
    #vb.gui = true
    vb.customize ["modifyvm", :id, "--memory", 2048]
  end

  config.vm.provision :shell, :path => "provision.sh"

  config.vm.provision :puppet do |puppet|
    puppet.options = "--verbose --debug"
    puppet.module_path = "modules"
    puppet.manifests_path = "manifests"
    puppet.manifest_file  = "default.pp"
    puppet.facter = {
      "vagrant" => "1"
    }
  end

end
