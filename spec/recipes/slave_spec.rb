# encoding: utf-8

require 'spec_helper'

describe 'mesos::slave' do
  include_context 'setup context'

  shared_examples_for 'a slave recipe' do
    describe 'deploy env file' do
      it 'creates it' do
        expect(chef_run).to create_template '/usr/local/var/mesos/deploy/mesos-deploy-env.sh'
      end

      it 'contains SSH_OPTS variable' do
        expect(chef_run).to render_file('/usr/local/var/mesos/deploy/mesos-deploy-env.sh')
          .with_content(/^export SSH_OPTS="#{Regexp.escape('-o StrictHostKeyChecking=no -o ConnectTimeout=2')}"$/)
      end

      it 'contains DEPLOY_WITH_SUDO variable' do
        expect(chef_run).to render_file('/usr/local/var/mesos/deploy/mesos-deploy-env.sh')
          .with_content(/^export DEPLOY_WITH_SUDO="1"$/)
      end
    end

    describe 'slave env file' do
      it 'creates it' do
        expect(chef_run).to create_template '/usr/local/var/mesos/deploy/mesos-slave-env.sh'
      end

      it 'contains each key-value pair from node[:mesos][:slave]' do
        expect(chef_run).to render_file('/usr/local/var/mesos/deploy/mesos-slave-env.sh')
          .with_content(/^export MESOS_slave_key=slave_value$/)
      end
    end

    it 'reload init configuration' do
      expect(chef_run).to run_bash('reload upstart configuration').with_code(/initctl reload-configuration/)
      expect(chef_run).to run_bash('reload upstart configuration').with_user('root')
    end

    it 'restarts mesos-slave service' do
      expect(chef_run).to restart_service 'mesos-slave'
    end
  end

  context 'when installed from mesosphere' do
    let :chef_run do
      ChefSpec::Runner.new do |node|
        node.set[:mesos][:type] = 'mesosphere'
        node.set[:mesos][:slave][:master] = 'test-master'
        node.set[:mesos][:mesosphere][:with_zookeeper] = true
        node.set[:mesos][:slave][:slave_key] = 'slave_value'
      end.converge(described_recipe)
    end

    it_behaves_like 'an installation from mesosphere',:init_master_state=>"stop", :init_slave_state=>"start"
    it_behaves_like 'a slave recipe'

    describe '/etc/mesos/zk' do
      it 'creates it' do
        expect(chef_run).to create_template '/etc/mesos/zk'
      end

      it 'contains configured zk string' do
        expect(chef_run).to render_file('/etc/mesos/zk').with_content(/^test-master$/)
      end
    end

    describe '/etc/default/mesos-slave' do
      it 'creates it' do
        expect(chef_run).to create_template '/etc/default/mesos-slave'
      end

      it 'contains MASTER variable' do
        expect(chef_run).to render_file('/etc/default/mesos-slave')
          .with_content(/^MASTER=`cat \/etc\/mesos\/zk`$/)
      end

      it 'contains ISOLATION variable' do
        expect(chef_run).to render_file('/etc/default/mesos-slave')
          .with_content(/^ISOLATION=cgroups\/cpu,cgroups\/mem$/)
      end
    end

    it 'creates /etc/mesos-slave' do
      expect(chef_run).to create_directory '/etc/mesos-slave'
    end

    it 'run a bash cleanup script' do
      expect(chef_run).to run_bash('cleanup /etc/mesos-slave/')
    end

    describe 'configuration options in /etc/mesos-slave' do
      it 'echos each key-value pair in node[:mesos][:slave]' do
        expect(chef_run).to run_bash('echo /tmp/mesos > /etc/mesos-slave/work_dir')
        expect(chef_run).to run_bash('echo slave_value > /etc/mesos-slave/slave_key')
      end
    end
  end

  context 'when installed from source' do
    let :chef_run do
      ChefSpec::Runner.new do |node|
        node.set[:mesos][:type] = 'source'
        node.set[:mesos][:slave][:master] = 'test-master'
        node.set[:mesos][:slave][:slave_key] = 'slave_value'
        node.set[:mesos][:build][:skip_test] = false
      end.converge(described_recipe)
    end

    it_behaves_like 'an installation from source', :init_master_state => "stop", :init_slave_state =>"start"
    it_behaves_like 'a slave recipe'
  end
end
