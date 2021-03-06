define apache::mod (
  $package = undef,
  $package_ensure = 'present',
  $lib = undef,
  $lib_path = $::apache::params::lib_path,
  $id = undef,
  $path = undef,
) {
  if ! defined(Class['apache']) {
    fail('You must include the apache base class before using any apache defined resources')
  }

  #if there is an ~ within the name split into array to find module name and load prefix (used for forcing module load order for Debian systems)
  if ( '~' in $name ) {
    $mod_details = split($name, '~')
    $mod = $mod_details[0]
    $load_prefix = $mod_details[1]

  }
  else {
    $mod = $name
    $load_prefix = ''
  }

  #include apache #This creates duplicate resources in rspec-puppet
  $mod_dir = $::apache::mod_dir

  # Determine if we have special lib
  $mod_libs = $::apache::params::mod_libs
  $mod_lib = $mod_libs[$mod] # 2.6 compatibility hack
  if $lib {
    $_lib = $lib
  } elsif $mod_lib {
    $_lib = $mod_lib
  } else {
    $_lib = "mod_${mod}.so"
  }

  # Determine if declaration specified a path to the module
  if $path {
    $_path = $path
  } else {
    $_path = "${lib_path}/${_lib}"
  }

  if $id {
    $_id = $id
  } else {
    $_id = "${mod}_module"
  }

  # Determine if we have a package
  $mod_packages = $::apache::params::mod_packages
  $mod_package = $mod_packages[$mod] # 2.6 compatibility hack
  if $package {
    $_package = $package
  } elsif $mod_package {
    $_package = $mod_package
  }
  if $_package and ! defined(Package[$_package]) {
    # note: FreeBSD/ports uses apxs tool to activate modules; apxs clutters
    # httpd.conf with 'LoadModule' directives; here, by proper resource
    # ordering, we ensure that our version of httpd.conf is reverted after
    # the module gets installed.
    $package_before = $::osfamily ? {
      'freebsd' => [
        File["${mod_dir}/${mod}.load"],
        File["${::apache::params::conf_dir}/${::apache::params::conf_file}"]
      ],
      default => File["${mod_dir}/${mod}.load"],
    }
    # $_package may be an array
    package { $_package:
      ensure  => $package_ensure,
      require => Package['httpd'],
      before  => $package_before,
    }
  }

  if $::osfamily == "RedHat"{
    $prefixed_path = "${mod_dir}/${load_prefix}${mod}.load"
  } else {
    $prefixed_path = "${mod_dir}/${mod}.load"
  }

  file { "${mod}.load":
    ensure  => file,
    path    => $prefixed_path,
    owner   => 'root',
    group   => $::apache::params::root_group,
    mode    => '0644',
    content => "LoadModule ${_id} ${_path}\n",
    require => [
      Package['httpd'],
      Exec["mkdir ${mod_dir}"],
    ],
    before  => File[$mod_dir],
    notify  => Service['httpd'],
  }

  if $::osfamily == 'Debian' {
    $enable_dir = $::apache::mod_enable_dir
    $link_path = "${enable_dir}/${load_prefix}${mod}.load"
    file{ "${mod}.load symlink":
      ensure  => link,
      path    => "${link_path}",
      target  => "${mod_dir}/${mod}.load",
      owner   => 'root',
      group   => $::apache::params::root_group,
      mode    => '0644',
      require => [
        File["${mod}.load"],
        Exec["mkdir ${enable_dir}"],
      ],
      before  => File[$enable_dir],
      notify  => Service['httpd'],
    }
    # Each module may have a .conf file as well, which should be
    # defined in the class apache::mod::module
    # Some modules do not require this file.
    if defined(File["${mod}.conf"]) {
      file{ "${mod}.conf symlink":
        ensure  => link,
        path    => "${enable_dir}/${mod}.conf",
        target  => "${mod_dir}/${mod}.conf",
        owner   => 'root',
        group   => $::apache::params::root_group,
        mode    => '0644',
        require => [
          File["${mod}.conf"],
          Exec["mkdir ${enable_dir}"],
        ],
        before  => File[$enable_dir],
        notify  => Service['httpd'],
      }
    }
  }
}
