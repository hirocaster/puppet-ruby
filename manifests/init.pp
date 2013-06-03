# Class: ruby
#
# This module installs a full rbenv-driven ruby stack
#
class ruby(
  $default_gems  = $ruby::params::default_gems,
  $rbenv_plugins = {},
  $rbenv_version = $ruby::params::rbenv_version,
  $rbenv_root    = $ruby::params::rbenv_root,
  $user          = $ruby::params::user
) inherits ruby::params {

  if $::osfamily == 'Darwin' {
    include boxen::config

    file { "${boxen::config::envdir}/rbenv.sh":
      source => 'puppet:///modules/ruby/rbenv.sh' ;
    }
  }

  repository { $rbenv_root:
    ensure => $rbenv_version,
    source => 'sstephenson/rbenv',
    user   => $user
  }

  file {
    [
      "${rbenv_root}/plugins",
      "${rbenv_root}/rbenv.d",
      "${rbenv_root}/rbenv.d/install",
      "${rbenv_root}/shims",
      "${rbenv_root}/versions",
    ]:
      ensure  => directory,
      require => Exec['rbenv-setup-root-repo'];
  }

  $_real_rbenv_plugins = merge($ruby::params::rbenv_plugins, $rbenv_plugins)
  create_resources('ruby::plugin', $_real_rbenv_plugins)


  repository { "${root}/plugins/rbenv-sudo":
    source  => 'dcarley/rbenv-sudo',
    require => File["${root}/plugins"]
  }

  exec { "ensure-rbenv-version-${rbenv_version}":
    command => "${git_fetch} && git reset --hard ${rbenv_version}",
    unless  => "git describe --tags --exact-match `git rev-parse HEAD` | grep ${rbenv_version}",
    cwd     => $root,
    require => Exec['rbenv-setup-root-repo']
  }

  exec { 'rbenv-rehash-post-install':
    command => "/bin/rm -rf ${root}/shims && RBENV_ROOT=${root} ${root}/bin/rbenv rehash",
    unless  => "grep /opt/boxen/rbenv/libexec ${root}/shims/gem",
    require => Exec["ensure-rbenv-version-${rbenv_version}"],
  }

  if has_key($_real_rbenv_plugins, 'rbenv-default-gems') {
    $gem_list = join($default_gems, "\n")

    file { "${rbenv_root}/default-gems":
      content => "${gem_list}\n",
      tag     => 'ruby_plugin_config'
    }
  }

  Repository[$rbenv_root] ->
    File <| tag == 'ruby_plugin_config' |> ->
    Ruby::Plugin <| |> ->
    Ruby::Definition <| |> ->
    Ruby::Version <| |>
}
