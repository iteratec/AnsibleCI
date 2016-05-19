describe service('docker') do
  it { should be_running }
end

describe port(4243) do
  it { should be_listening.with('tcp6') }
end

# check 'remote' access on localhost
describe command('docker --tlsverify --tlscacert=/vagrant/.ansible-data/thomass.docker/pki/ca.pem --tlscert=/vagrant/.ansible-data/thomass.docker/pki/client-cert.pem --tlskey=/vagrant/.ansible-data/thomass.docker/pki/client-key.pem -H=tcp://localhost:4243 version') do
  its(:stderr) { should eq '' }
end
