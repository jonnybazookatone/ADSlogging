# Some const. variables
$path_var = "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
$build_packages = ['python', 'python-pip', 'python-dev', 'libpq-dev', 'libxml2-dev', 'libxslt1-dev', 'elasticsearch', 'logstash']
$pip_requirements = "/vagrant/requirements.txt"

define add_repo($repo_name, $repo_key, $repo_url){

  exec {"get_key_${repo_name}":
    command => "wget -q ${repo_key} -O /tmp/${repo_name}",
    path => $path_var,
    logoutput => true,
    creates => "/tmp/${repo_name}"
  }

  exec {"add_key_${repo_name}":
    command => "apt-key add /tmp/${repo_name}",
    path => $path_var,
    logoutput => true,
    require => Exec["get_key_${repo_name}"],
  }

  exec {"add_repo_${repo_name}":
    command => "add-apt-repository 'deb $repo_url stable main'",
    path => $path_var,
    logoutput => true,
    require => Exec["add_key_${repo_name}"],
  }

  Exec["get_key_${repo_name}"] -> Exec["add_key_${repo_name}"] -> Exec["add_repo_${repo_name}"]

}


#file { '/vagrant/kibana':
#ensure => 'directory',
#group => 'vagrant',
#owner => 'vagrant',
#}
#exec { 'download_kibana':
#command => '/usr/bin/curl -L https://download.elasticsearch.org/kibana/kibana/kibana-4.0.0-linux-x64.tar.gz | /bin/tar xvz -C /vagrant/kibana',
#require => [ Package['curl'], File['/vagrant/kibana'],Class['elasticsearch'] ],
#timeout => 1800
#}

add_repo{'logstash':
    repo_name => "logstash",
    repo_key => "http://packages.elasticsearch.org/GPG-KEY-elasticsearch",
    repo_url => "http://packages.elasticsearch.org/logstash/1.4/debian",
}

add_repo{'elastic':
    repo_name => "elasticsearch",
    repo_key => "http://packages.elasticsearch.org/GPG-KEY-elasticsearch",
    repo_url => "http://packages.elasticsearch.org/elasticsearch/1.4/debian",
}

# Update package list
exec {'apt_update_1':
	command => 'apt-get update && touch /etc/.apt-updated-by-puppet1',
	creates => '/etc/.apt-updated-by-puppet1',
	path => $path_var,
}

# Install packages
package {$build_packages:
	ensure => installed,
	require => Exec['apt_update_1'],
}

# Install all python dependencies for selenium and general software
exec {'pip_install_modules':
	command => "pip install -r ${pip_requirements}",
	logoutput => on_failure,
	path => $path_var,
	tries => 2,
	timeout => 1000, # This is only required for Scipy/Matplotlib - they take a while
	require => Package[$build_packages],
}

# Python path to work while on the VM
exec {'update_python_path':
    command => "echo 'export PYTHONPATH=$PYTHONPATH:/vagrant/' > /home/vagrant/.bashrc",
    path => $path_var,
}

Add_Repo['elastic'] -> Add_Repo['logstash'] -> Exec['apt_update_1'] -> Package[$build_packages] -> Exec['pip_install_modules'] -> Exec['update_python_path']