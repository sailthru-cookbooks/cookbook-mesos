#
# Cookbook Name:: mesos
# Recipe:: master
#
# Copyright 2013, Shingo Omura
#
# All rights reserved - Do Not Redistribute

prefix = '/usr'
installed = File.exists?(File.join(prefix, "sbin", "mesos-master"))

if !installed then
  include_recipe "mesos::mesosphere"
end

# configuration files for upstart scripts by mesosphere package.
if node[:mesos][:type] == 'mesosphere' then
  template "/etc/init/mesos-master.conf" do
    source "upstart.conf.for.mesosphere.erb"
    variables(:init_state => "start", :role => "master")
    mode 0644
    owner "root"
    group "root"
    notifies :restart, 'service[mesos-master]', :delayed
  end

  template File.join("/etc", "mesos", "zk") do
    source "etc-mesos-zk.erb"
    mode 0644
    owner "root"
    group "root"
    variables lazy {
      {
        :zk => node[:mesos][:master][:zk]
      }
    }
    notifies :restart, 'service[mesos-master]', :delayed
  end

  template File.join("/etc", "default", "mesos") do
    source "etc-default-mesos.erb"
    mode 0644
    owner "root"
    group "root"
    variables({
      :log_dir => node[:mesos][:master][:log_dir]
    })
    notifies :restart, 'service[mesos-master]', :delayed
  end

  template File.join("/etc", "default", "mesos-master") do
    source "etc-default-mesos-master.erb"
    mode 0644
    owner "root"
    group "root"
    variables({
      :port => node[:mesos][:master][:port]
    })
    notifies :restart, 'service[mesos-master]', :delayed
  end

  directory File.join("/etc", "mesos-master") do
    action :create
    recursive true
    mode 0755
    owner "root"
    group "root"
  end

  bash "cleanup /etc/mesos-master/" do
    code "rm -rf /etc/mesos-master/*"
    user "root"
    group "root"
    action :run
  end

  if node[:mesos][:master] then
    node[:mesos][:master].each do |key, val|
      if ! ['zk', 'log_dir', 'port'].include?(key) then
        _code = "echo #{val} > /etc/mesos-master/#{key}"
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

service "mesos-master" do
  provider Chef::Provider::Service::Upstart
  action :start
end
