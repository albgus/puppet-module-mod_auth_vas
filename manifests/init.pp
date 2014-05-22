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
) {

  if type($manage_host_keytab) == 'string' {
    $manage_host_keytab_real = str2bool($manage_host_keytab)
  } else {
    $manage_host_keytab_real = $manage_host_keytab
  }
  validate_absolute_path($http_keytab_path)
  validate_absolute_path($host_keytab_path)

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

  Exec['vasinst'] -> Exec['vastool_ktutil_create_alias'] -> Exec['vastool_setattrs']
}
