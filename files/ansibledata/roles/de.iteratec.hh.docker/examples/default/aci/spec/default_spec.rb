describe package('docker-engine') do
  it { should be_installed }
end

describe package('docker-py') do
  it { should be_installed.by('pip') }
end

describe service('docker') do
  it { should be_running }
  it { should be_enabled }
end

describe user('vagrant') do
  it { should belong_to_group 'docker' }
end

# check installation of docker and the alias as well
describe command('docker version') do
  its(:stderr) { should eq '' }
end
