def mesos_installed?
  cmd = "#{node['mesos']['bin_path']}/mesos-master --version |cut -f 2 -d ' '"
  File.exist?("#{node['mesos']['bin_path']}/mesos-master") && (`#{cmd}`.chop == mesos_version)
end
