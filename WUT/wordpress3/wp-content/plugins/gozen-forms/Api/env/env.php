<?php
/**
 * check the current in env with 'wp_get_environment_type'.
 */
switch(wp_get_environment_type()){
    case "development":
        require_once(GOZENFORMS_PATH.'Api/env/development.php');
        break;
    case "production":
        require_once(GOZENFORMS_PATH.'Api/env/production.php');
        break;
    case "local":
        require_once(GOZENFORMS_PATH.'Api/env/development.php');
        break;
}

?>