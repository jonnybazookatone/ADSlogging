# Some const. variables
$path_var = "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
$build_packages = ['elasticsearch', 'logstash', 'curl']

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

file { 'move_kibana_folder':
  ensure => 'directory',
  recurse => true,
  path => '/opt/kibana4',
  source => '/vagrant/kibana-4.0.0-linux-x64',
  mode => '0744',
  group => 'vagrant',
  owner => 'vagrant',
  require => Exec['download_kibana'],
}

exec { 'download_kibana':
  command => 'curl -L https://download.elasticsearch.org/kibana/kibana/kibana-4.0.0-linux-x64.tar.gz | tar xvz -C /vagrant/',
  require => [ Package[$build_packages] ],
  path => $path_var,
}

file { 'copy_kibana_conf':
  path => '/etc/init.d/kibana',
  source => 'puppet:///modules/kibana/kibana.conf',
  mode => '0744',
  group => 'vagrant',
  owner => 'vagrant',
}

exec { 'update_init':
  command => 'update-rc.d kibana defaults',
  path => $path_var,
  require => File['copy_kibana_conf'],
}

file { 'copy_logstash_conf':
  path => '/etc/logstash/conf.d/',
  source => 'puppet:///modules/logstash/logstash-apache.conf',
  mode => '0744',
  group => 'vagrant',
  owner => 'vagrant',
}

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

Add_Repo['elastic'] -> Add_Repo['logstash'] -> Exec['apt_update_1'] -> Package[$build_packages] -> Exec['download_kibana'] -> File['move_kibana_folder'] -> File['copy_kibana_conf'] -> Exec['update_init']
