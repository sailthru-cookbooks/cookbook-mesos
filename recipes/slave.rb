#
# Cookbook Name:: mesos
# Recipe:: slave
#
# Copyright 2013, Shingo Omura
#
# All rights reserved - Do Not Redistribute
#

prefix = '/usr'
installed = File.exists?(File.join(prefix, "sbin", "mesos-master"))

if !installed then
  include_recipe "mesos::mesosphere"
end

# for backword compatibility
if node[:mesos][:slave][:master_url] then
  if !node[:mesos][:slave][:master] then
    Chef::Log.info("node[:mesos][:slave][:master_url] is obsolute. use node[:mesos][:slave][:master] instead.")
    node.default[:mesos][:slave][:master] = node[:mesos][:slave][:master_url]
  else
    Chef::Log.info("node[:mesos][:slave][:master_url] is obsolute. node[:mesos][:slave][:master_url] will be ignored because you have node[:mesos][:slave][:master].")
  end
end

ruby_block "check zookeeper attribute" do
  block do
    if ! node[:mesos][:slave][:master] then
      Chef::Application.fatal!("node[:mesos][:slave][:master] is required to configure mesos-slave.")
    end
  end
end

# configuration files for upstart scripts by mesosphere package.
if node[:mesos][:type] == 'mesosphere' then
  template "/etc/init/mesos-slave.conf" do
    source "upstart.conf.for.mesosphere.erb"
    variables(:init_state => "start", :role => "slave")
    mode 0644
    owner "root"
    group "root"
    notifies :restart, 'service[mesos-slave]', :delayed
  end

  template File.join("/etc", "mesos", "zk") do
    source "etc-mesos-zk.erb"
    mode 0644
    owner "root"
    group "root"
    variables lazy {
      {
        :zk => node[:mesos][:slave][:master]
      }
    }
    notifies :restart, 'service[mesos-slave]', :delayed
  end

  template File.join("/etc", "default", "mesos") do
    source "etc-default-mesos.erb"
    mode 0644
    owner "root"
    group "root"
    variables({
      :log_dir => node[:mesos][:slave][:log_dir]
    })
    notifies :restart, 'service[mesos-slave]', :delayed
  end

  template File.join("/etc", "default", "mesos-slave") do
    source "etc-default-mesos-slave.erb"
    mode 0644
    owner "root"
    group "root"
    variables({
      :isolation => node[:mesos][:slave][:isolation]
    })
    notifies :restart, 'service[mesos-slave]', :delayed
  end

  directory File.join("/etc", "mesos-slave") do
    action :create
    recursive true
    mode 0755
    owner "root"
    group "root"
  end

  bash "cleanup /etc/mesos-slave/" do
    code "rm -rf /etc/mesos-slave/*"
    user "root"
    group "root"
    action :run
  end

  if node[:mesos][:slave] then
    node[:mesos][:slave].each do |key, val|
      if ! ['master_url', 'master', 'isolation', 'log_dir'].include?(key) then
        _code = "echo #{val} > /etc/mesos-slave/#{key}"
        bash _code do
          code _code
          user "root"
          group "root"
          action :run
        end
      end
    end
  end
end

bash "reload upstart configuration" do
  user 'root'
  code 'initctl reload-configuration'
end

service "mesos-slave" do
  provider Chef::Provider::Service::Upstart
  action :start
end
