use ExtUtils::MakeMaker;

WriteMakefile
(

 NAME  => 'Cache::Cache',

 VERSION_FROM => 'lib/Cache/Cache.pm',

 dist =>  {COMPRESS => 'gzip', SUFFIX => '.gz'},

 PREREQ_PM => {
               Digest::MD5 => '2.09',
               File::Spec => '0.82',
               IPC::Shareable => '0.60',
               Storable => '1.0.10'
              }

);
