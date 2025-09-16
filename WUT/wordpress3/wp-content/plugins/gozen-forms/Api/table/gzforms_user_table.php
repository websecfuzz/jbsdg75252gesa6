<?php

/**
 * Add gzforms tables in DB.
 */

global $wpdb;

$table_name = $wpdb->prefix.'gozen_forms_users';

$query = $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table_name ) );

//check the table is alreably ini DB.
if($wpdb->get_var( $query ) === $table_name){

    return true;

}
else{

    $charset_collate = $wpdb->get_charset_collate();
    $sql = "CREATE TABLE $table_name(
        Id INT(20) NOT NULL AUTO_INCREMENT,
        api_key CHAR(64) NOT NULL,
        login_user_id INT(20) NOT NULL,
        login_user_name CHAR(64) NOT NULL,
        Login_status INT(20) NOT NULL DEFAULT '0',
        PRIMARY KEY(Id) 
    )$charset_collate;";

    if(!function_exists('dbDelta')){
        require_once(ABSPATH.'wp-admin/includes/upgrade.php');
    }

    require_once(GOZENFORMS_PATH.'Api/gzapisecret.php');

    $wpdb->query( $sql );
    /**
     * default apikey.
     * @var string
     */

}

?>