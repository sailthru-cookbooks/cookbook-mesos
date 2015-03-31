#
# Cookbook Name:: mesos
# Recipe:: mesosphere
#
# Copyright 2013, Shingo Omura
#
# All rights reserved - Do Not Redistribute
#
version = node[:mesos][:version]

# For now we need to use the latest 13.x based deb
# package for all mesos packages prior to 0.19.0
# downloaded from the mesosphere site.
if node['platform_version'] == '14.04' && version < "0.19.0"
  platform_version = '13.10'
else
  platform_version = node['platform_version']
end

# TODO(everpeace) platform_version validation
if !platform?("ubuntu") then
  Chef::Application.fatal!("#{platform} is not supported on #{cookbook_name} cookbook")
end

apt_package "default-jre-headless" do
  action :install
end

# workaround for "error while loading shared libraries: libjvm.so: cannot open shared object file: No such file or directory"
link "/usr/lib/libjvm.so" do
  to "/usr/lib/jvm/default-java/jre/lib/amd64/server/libjvm.so"
  not_if "test -L /usr/lib/libjvm.so"
end

if node['mesos']['mesosphere']['with_zookeeper'] then
  ['zookeeper', 'zookeeperd', 'zookeeper-bin'].each do |zk|
    package zk do
      action :install
    end
  end
  service "zookeeper" do
    provider Chef::Provider::Service::Upstart
    action :restart
  end
end

apt_repository 'mesosphere' do
  uri 'http://repos.mesosphere.io/ubuntu'
  components ['main']
  distribution 'trusty'
  key 'E56151BF'
  keyserver 'keyserver.ubuntu.com'
  action :add
end

package 'mesos' do
  action :install
  version "#{version}*"
end

# configuration files for upstart scripts by build_from_source installation
template "/etc/init/mesos-master.conf" do
  source "upstart.conf.for.mesosphere.erb"
  variables(:init_state => "stop", :role => "master")
  mode 0644
  owner "root"
  group "root"
end

template "/etc/init/mesos-slave.conf" do
  source "upstart.conf.for.mesosphere.erb"
  variables(:init_state => "stop", :role => "slave")
  mode 0644
  owner "root"
  group "root"
end

bash "reload upstart configuration" do
  user 'root'
  code 'initctl reload-configuration'
end
