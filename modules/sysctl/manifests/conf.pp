define sysctl::conf ( $value ) {

  include sysctl

  # $title contains the title of each instance of this defined type

  # guid of this entry
  $key = $title

  $context = "/files/etc/sysctl.conf"

   augeas { "sysctl_conf/$key":
     context => "$context",
     onlyif  => "get $key != '$value'",
     changes => "set $key '$value'",
     notify  => Exec["sysctl"],
   }

} 
