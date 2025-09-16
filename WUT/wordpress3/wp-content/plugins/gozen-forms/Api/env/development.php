<?php
    /**
     * if the env is development or local,define const GOZENFORM_SERVER_URL
     */
    if ( !defined('WP_DEBUG')) {
        define('WP_DEBUG', true);
    }
    define('GOZENFORM_SERVER_API_URL', "https://api.dev.forms.gozen.io");
    define('GOZENFORM_SERVER_URL', "https://dev.app.forms.gozen.io");
    define('GOZENFORM_EMDED_SCRIPT', "https://form-assets.forms.gozen.io/cdn/scripts/embed-v1.21.js");
?>
