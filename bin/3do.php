<?php

$file = $argv[1];
file_put_contents(basename($file, '.DAE').'.3do', gzcompress(file_get_contents($file), 9));

?>