class mod_auth_vas (
  $mod_auth_vas_package = 'mod-auth-vas-http22',
  $realm = 'EXAMPLE.COM',
  $ou = 'OU=Servers,DC=example,DC=com',
  $manage_host_keytab = true,
  $http_keytab_path = '/etc/opt/quest/vas/HTTP.keytab',
  $host_keytab_path = '/etc/opt/quest/vas/host.keytab',
  $host_keytab_owner = 'root',
  $host_keytab_group = 'root',
  $host_keytab_mode = '0640',
  $keytabrefresh_script_enable = true,
  $keytabrefresh_script_path = '/usr/local/bin/apache_keytab_refresh.sh',
  $keytabrefresh_script_owner = 'root',
  $keytabrefresh_script_group = 'root',
  $keytabrefresh_script_mode = '0744',
  $keytabrefresh_initscript_source = 'USE_DEFAULTS',
  $inotifywait_path = '/usr/bin/inotifywait',
  $keytabrefresh_mail_recipients = [],
) {

  if type($manage_host_keytab) == 'string' {
    $manage_host_keytab_real = str2bool($manage_host_keytab)
  } else {
    $manage_host_keytab_real = $manage_host_keytab
  }
  if type($keytabrefresh_script_enable) == 'string' {
    $keytabrefresh_script_enable_real = str2bool($keytabrefresh_script_enable)
  } else {
    $keytabrefresh_script_enable_real = $keytabrefresh_script_enable
  }
  validate_absolute_path($http_keytab_path)
  validate_absolute_path($host_keytab_path)

  if $keytabrefresh_script_enable_real == true {
    validate_absolute_path($keytabrefresh_script_path)
    validate_absolute_path($inotifywait_path)
    validate_array($keytabrefresh_mail_recipients)
  }

  $hostname_upper = upcase($::hostname)

  package { $mod_auth_vas_package:
    ensure => installed
  }

  exec { 'vastool_ktutil_create_alias':
    command => "/opt/quest/bin/vastool -u host/ ktutil alias host/${::fqdn}@${realm} HTTP/${::fqdn}@${realm}",
    unless  => "/opt/quest/bin/vastool -u host/ ktutil -k /etc/opt/quest/vas/host.keytab list --keys | grep HTTP/${::fqdn}",
  }

  exec { 'vastool_setattrs':
    command => "/opt/quest/bin/vastool -u host/ setattrs -m -d CN=${::hostname},${ou} servicePrincipalName host/$hostname_upper host/${::fqdn} HTTP/${::fqdn}",
    unless  => "/opt/quest/bin/vastool -u host/ attrs CN=${::hostname},${ou} | grep \"servicePrincipalName: HTTP/${::fqdn}\""
  }

  if $manage_host_keytab_real == true {
    file { 'host.keytab':
      ensure => file,
      path   => $host_keytab_path,
      owner  => $host_keytab_owner,
      group  => $host_keytab_group,
      mode   => $host_keytab_mode,
    }
  }

  file { 'HTTP.keytab':
    ensure => link,
    path   => $http_keytab_path,
    target => $host_keytab_path,
  }

  if $keytabrefresh_script_enable_real == true {
    file { 'keytabrefresh_script':
      ensure => file,
      path => $keytabrefresh_script_path,
      owner => $keytabrefresh_script_owner,
      group => $keytabrefresh_script_group,
      mode => $keytabrefresh_script_mode,
      content => template('mod_auth_vas/apache_keytab_refresh.sh.erb'),
    }

    if $keytabrefresh_initscript_source == 'USE_DEFAULTS' {
      case $::osfamily {
        'RedHat': {
          $keytabrefresh_initscript_source_real = template('mod_auth_vas/apache_keytab_refresh-redhat.erb')
        }
        'Suse': {
          $keytabrefresh_initscript_source_real = template('mod_auth_vas/apache_keytab_refresh-suse.erb')
        }
        default: {
          fail("Init script is only available for RedHat and Suse. Please supply your own file.")
        }
      }
    } else {
      $keytabrefresh_initscript_source_real = $keytabrefresh_initscript_source_real
    }

    file { 'keytabrefresh_initscript':
      ensure => file,
      path => '/etc/init.d/apache_keytab_refresh',
      owner => 'root',
      group => 'root',
      mode => '0755',
      content => $keytabrefresh_initscript_source_real,
    }

    service { 'keytabrefresh_initscript_service':
      name => 'apache_keytab_refresh',
      ensure => 'running',
      enable => 'true',
      require => File[keytabrefresh_initscript],
    }

  }

  Exec['vasinst'] -> Exec['vastool_ktutil_create_alias'] -> Exec['vastool_setattrs']
}
