
module Mesos
  module Helpers
    def mesos_installed?
      mesos_version_cmd = "#{node['mesos']['bin_path']}/mesos-master --version |cut -f 2 -d ' '"
      Chef::Log.info("bin_path: #{node['mesos']['bin_path']}/mesos-master")
      File.exist?("#{node['mesos']['bin_path']}/mesos-master") && (`#{mesos_version_cmd}`.chop == node[:mesos][:version])
    end
  end
end
