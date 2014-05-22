class mod_auth_vas (
  $mod_auth_vas_package = 'mod-auth-vas-http22',
  $realm = 'EXAMPLE.COM',
  $ou = 'OU=Servers,DC=example,DC=com',
  $manage_host_keytab = 'true',
  $http_keytab_path = '/etc/opt/quest/vas/HTTP.keytab',
  $host_keytab_path = '/etc/opt/quest/vas/host.keytab',
  $host_keytab_owner = 'root',
  $host_keytab_group = 'root',
  $host_keytab_mode = '0640',
) {

  # TODO: Add input validations

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

  if $manage_host_keytab == true { # FIXME: This should be converted to a boolean.
    file { 'host.keytab':
      ensure => file,
      path   => $host_keytab_path,
      owner  => $host_keytab_owner,
      group  => $keytab_group,
      mode   => $keytab_mode,
    }
  }

  file { 'HTTP.keytab':
    ensure => link,
    path   => $http_keytab_path,
    target => '/etc/opt/quest/vas/host.keytab', 
  }

  Exec['vastool_ktutil_create_alias'] -> Exec['vastool_setattrs']

}
